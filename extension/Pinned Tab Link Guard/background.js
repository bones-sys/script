// ===== Pinned Tab Link Guard (background) =====
// ピン留めタブを基準URLに固定する。
//
// 遷移のブロック方法は 2 段構え:
//   1) content.js がリンククリックを遷移前に横取り → 新規タブで開く
//      （固定タブでは遷移が始まらないため、リロードが発生しない）
//   2) content.js で拾えない経路（ブックマーク・JSリダイレクト・SPA遷移等）は
//      webNavigation.onCommitted で検知し、新規タブへ逃がして基準URLに差し戻す
//      （この経路のみリロードが残るが、通常操作ではほぼ発生しない）
//
// アドレスバー直接入力（transitionType: "typed"）は基準URLの更新として
// そのまま通す。差し戻しも新規タブも発生しない = リロードなし。

const lockedUrl = new Map();      // tabId -> 基準URL
const ownCreatedTabs = new Set(); // 自分で開いた新規タブ（初回遷移を無視）
const restoring = new Set();      // 差し戻し中のタブ（再発火を無視）

// restoring フラグを立てる。BFCache 復元では webNavigation イベントが
// 発火しないことがあり、フラグが残留すると以降の判定が狂うため、
// 一定時間で自動クリアする保険を付ける。
function markRestoring(tabId) {
  restoring.add(tabId);
  setTimeout(() => restoring.delete(tabId), 2000);
}

function isHttp(u) {
  return typeof u === "string" && /^https?:/i.test(u);
}

function setBaseFromTab(tab) {
  if (tab && tab.pinned && isHttp(tab.url)) {
    lockedUrl.set(tab.id, tab.url);
  }
}

function initAll() {
  chrome.tabs.query({}, (tabs) => {
    for (const t of tabs) setBaseFromTab(t);
  });
}
chrome.runtime.onInstalled.addListener(initAll);
chrome.runtime.onStartup.addListener(initAll);
initAll(); // SW 再生成（拡張の再読み込み含む）のたびに必ず実行

// ピン留め切替を追従し、content.js にも通知する
chrome.tabs.onUpdated.addListener((tabId, info, tab) => {
  if (info.pinned === true) {
    setBaseFromTab(tab);
  } else if (info.pinned === false) {
    lockedUrl.delete(tabId);
  }
  if (typeof info.pinned === "boolean") {
    chrome.tabs.sendMessage(tabId, { type: "pinnedChanged", pinned: info.pinned }, () => {
      // content script が居ないページ（chrome:// 等）はエラーになるが無視
      void chrome.runtime.lastError;
    });
  }
});

chrome.tabs.onRemoved.addListener((tabId) => {
  lockedUrl.delete(tabId);
  ownCreatedTabs.delete(tabId);
  restoring.delete(tabId);
});

function isSamePage(a, b) {
  try {
    const ua = new URL(a), ub = new URL(b);
    return ua.origin === ub.origin && ua.pathname === ub.pathname;
  } catch (_) {
    return false;
  }
}

// URL を「ルート文字列」に正規化する。
// ハッシュルーティング SPA（Intel EMA 等）の "/#/endpoints/ID" と
// 実パスの "/endpoints/ID" を同じ土俵で比較できるようにする。
// 例: https://host/#/endpoints    -> /endpoints
//     https://host/#/endpoints/ID -> /endpoints/ID
//     https://host/app/page       -> /app/page
function routeOf(u) {
  const x = new URL(u);
  let p = x.pathname.replace(/\/+$/, "");
  if (x.hash.startsWith("#/")) {
    p += x.hash.slice(1).replace(/\/+$/, "");
  }
  return p || "/";
}

// target が base の「子」（基準ルート配下への深掘り）かどうか。
// 例: base /#/endpoints に対する /#/endpoints/042FE... は子 → 固定タブ内で許可。
//     base /page/7344 に対する /page/39587 は子ではない → 新規タブ。
function isChildUrl(base, target) {
  try {
    const ub = new URL(base), ut = new URL(target);
    if (ub.origin !== ut.origin) return false;
    const rb = routeOf(base), rt = routeOf(target);
    // 基準がルート("/")そのものの場合、同一オリジン全体が子になってしまい
    // ガードが機能しなくなるため、完全一致のみ許可する
    return rt === rb || (rb !== "/" && rt.startsWith(rb + "/"));
  } catch (_) {
    return false;
  }
}

// content.js からの問い合わせ
chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (!msg || !sender.tab) return;

  if (msg.type === "getPinned") {
    sendResponse({ pinned: !!sender.tab.pinned });
    return;
  }

  if (msg.type === "linkClick") {
    const tabId = sender.tab.id;
    const base = lockedUrl.get(tabId);
    const target = msg.href;

    // 固定対象でない / 同一ページ（クエリ・ハッシュ差）/ 基準配下への深掘り
    // → 固定タブ内で通常遷移させる
    if (!base || !isHttp(target) || isSamePage(base, target) || isChildUrl(base, target)) {
      sendResponse({ handled: false });
      return;
    }

    // 別ページ → 新規タブで開く。固定タブ側は遷移していないので差し戻し不要
    chrome.tabs.create({ url: target, active: true, openerTabId: tabId }, (newTab) => {
      if (newTab) ownCreatedTabs.add(newTab.id);
      sendResponse({ handled: true });
    });
    return true; // 非同期で sendResponse するため
  }
});

// content.js をすり抜けた遷移（ブックマーク・JSリダイレクト等）の処理。
// onCommitted で扱うのは transitionType（typed 判定）がここでしか取れないため。
function bounceNavigation(tabId, target) {
  const base = lockedUrl.get(tabId);
  if (!base) return;                    // 固定対象でない
  if (!isHttp(target)) return;
  if (isSamePage(base, target)) return; // 同一ページ内（クエリ/ハッシュ差）は許可
  if (isChildUrl(base, target)) return; // 基準配下への深掘り（EMA の詳細画面等）は許可

  // 別ページ遷移 → 新規タブで開き、元タブは基準URLへ差し戻す
  chrome.tabs.create({ url: target, active: true, openerTabId: tabId }, (newTab) => {
    if (newTab) ownCreatedTabs.add(newTab.id);
  });

  // 元タブは履歴を1つ戻して基準ページへ復帰する。
  // tabs.update(base) だと完全リロードになるが、goBack なら直前ページが
  // BFCache に残っているため瞬時復元され、リロードもスクロール位置の消失も起きない。
  // SPA の pushState 遷移を弾く場合も、履歴を戻すだけなので再読み込みされない。
  markRestoring(tabId);
  chrome.tabs.goBack(tabId, () => {
    if (chrome.runtime.lastError) {
      // 戻る履歴がない等 → 従来通り基準URLへ直接差し戻す（この場合のみリロード）
      chrome.tabs.update(tabId, { url: base }, () => {
        if (chrome.runtime.lastError) restoring.delete(tabId);
      });
    }
  });
}

chrome.webNavigation.onCommitted.addListener((details) => {
  if (details.frameId !== 0) return; // メインフレームのみ
  const tabId = details.tabId;

  // 差し戻しによる遷移は最優先で無視
  // （tabs.update が "typed" 扱いになる環境があるため typed 判定より前に置く）
  if (restoring.has(tabId)) {
    restoring.delete(tabId);
    // goBack で戻った先が基準ページとずれていた場合のみ、直接差し戻す
    const base = lockedUrl.get(tabId);
    if (base && isHttp(details.url) && !isSamePage(base, details.url)) {
      markRestoring(tabId);
      chrome.tabs.update(tabId, { url: base }, () => {
        if (chrome.runtime.lastError) restoring.delete(tabId);
      });
    }
    return;
  }

  // 自作の新規タブの初回遷移は無視
  if (ownCreatedTabs.has(tabId)) {
    ownCreatedTabs.delete(tabId);
    return;
  }

  if (!lockedUrl.has(tabId)) return;

  // アドレスバー直接入力は基準URLの更新として許可（差し戻さない = リロードなし）。
  // 注意: ブックマークバーのクリックも transitionType が "typed" になる場合があるため、
  // 実際にアドレスバーを経由した証拠である "from_address_bar" 修飾子を必須にする。
  const fromAddressBar =
    Array.isArray(details.transitionQualifiers) &&
    details.transitionQualifiers.includes("from_address_bar");
  if (details.transitionType === "typed" && fromAddressBar && isHttp(details.url)) {
    lockedUrl.set(tabId, details.url);
    return;
  }

  bounceNavigation(tabId, details.url);
});

// SPA のクライアントサイド遷移（history.pushState 等）
// ShotGrid のような SPA のページ切替はこちらで発火する
chrome.webNavigation.onHistoryStateUpdated.addListener((details) => {
  if (details.frameId !== 0) return;
  // goBack による SPA 内の履歴戻りはここにしか来ないため、フラグをここでも消費する
  if (restoring.has(details.tabId)) {
    restoring.delete(details.tabId);
    return;
  }
  bounceNavigation(details.tabId, details.url);
});

// _blank 等で開かれる子タブには干渉しない
chrome.webNavigation.onCreatedNavigationTarget.addListener((details) => {
  ownCreatedTabs.add(details.tabId);
});

// ユーザーが「＋」ボタンや Ctrl+T で新規タブを開いたとき、
// ブラウザ標準の新しいタブページの代わりに Google トップを開く。
// URL 付きで作成されるタブ（拡張自身が開くタブ・_blank の子タブ等）は
// pendingUrl が newtab にならないため対象外。
const NEWTAB_URL = "https://www.google.com/";

function isNewTabPage(u) {
  if (typeof u !== "string" || !u) return false;
  return (
    u.startsWith("chrome://newtab") ||  // Chrome
    u.startsWith("edge://newtab") ||    // Edge
    u.startsWith("about:newtab") ||     // 別名
    u.startsWith("https://ntp.msn.com/") // Edge の NTP 実体 URL
  );
}

const maybeNewTabs = new Set(); // onCreated 時点で URL 未確定だったタブ

chrome.tabs.onCreated.addListener((tab) => {
  if (isNewTabPage(tab.pendingUrl) || isNewTabPage(tab.url)) {
    chrome.tabs.update(tab.id, { url: NEWTAB_URL }, () => {
      void chrome.runtime.lastError; // タブが即閉じられた場合等は無視
    });
    return;
  }
  // Edge では onCreated 時点で URL が空のことがある → 確定を待って判定
  if (!tab.pendingUrl && !tab.url) {
    maybeNewTabs.add(tab.id);
    setTimeout(() => maybeNewTabs.delete(tab.id), 3000);
  }
});

chrome.tabs.onUpdated.addListener((tabId, info) => {
  if (!maybeNewTabs.has(tabId)) return;
  const u = info.url;
  if (!u) return;
  maybeNewTabs.delete(tabId); // 最初に確定した URL だけを判定対象にする
  if (isNewTabPage(u)) {
    chrome.tabs.update(tabId, { url: NEWTAB_URL }, () => {
      void chrome.runtime.lastError;
    });
  }
});
