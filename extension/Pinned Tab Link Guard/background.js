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
const restoring = new Map();      // tabId -> 差し戻し猶予期限(ms)
const lastBounce = new Map();     // tabId -> 最後にバウンスした時刻(ms)
const typedAllow = new Map();     // tabId -> typed遷移を許可した時刻(ms)

// 差し戻し中フラグは「時間窓」方式。
// SPA ルーター（Confluence 等）は goBack への反応で pushState を連発するため、
// 「1回のイベントで消費」だと2発目以降を誤ってバウンスし、
// 相互応酬の無限ループ（タブ増殖）になる。窓の間はすべて無視する。
const RESTORE_WINDOW_MS = 2000;

function markRestoring(tabId) {
  restoring.set(tabId, Date.now() + RESTORE_WINDOW_MS);
}

function isRestoring(tabId) {
  const until = restoring.get(tabId);
  if (!until) return false;
  if (Date.now() > until) {
    restoring.delete(tabId);
    return false;
  }
  return true;
}

function isHttp(u) {
  return typeof u === "string" && /^https?:/i.test(u);
}

// ---- 基準URLの永続化 ----
// MV3 の service worker はアイドルで停止しメモリ状態が消えるため、
// lockedUrl を chrome.storage.session に保存する（ブラウザ終了でクリア）。
// これがないと、SW 再起動直後のクリックが「固定対象でない」と誤判定され
// 固定タブ内で遷移が素通りするレースが起きる。
function persistLocked() {
  const obj = {};
  for (const [id, url] of lockedUrl) obj[id] = url;
  chrome.storage.session.set({ lockedUrl: obj });
}

function setLocked(tabId, url) {
  lockedUrl.set(tabId, url);
  persistLocked();
}

function deleteLocked(tabId) {
  if (lockedUrl.delete(tabId)) persistLocked();
}

function setBaseFromTab(tab) {
  if (tab && tab.pinned && isHttp(tab.url)) {
    setLocked(tab.id, tab.url);
  }
}

// SW 起動時の復元: storage.session から読み込み、
// 保存がないピン留めタブは現在の URL から補完する。
// 各イベントハンドラはこの ready を待ってから判定する。
const ready = (async () => {
  try {
    const st = await chrome.storage.session.get("lockedUrl");
    const saved = (st && st.lockedUrl) || {};
    for (const [k, v] of Object.entries(saved)) {
      if (isHttp(v)) lockedUrl.set(Number(k), v);
    }
  } catch (_) {
    // storage が使えない環境でもメモリのみで動作継続
  }
  await new Promise((resolve) => {
    chrome.tabs.query({}, (tabs) => {
      for (const t of tabs) {
        // 保存済みの基準を現在URLで上書きしない（保存の方が正確）
        if (!lockedUrl.has(t.id)) setBaseFromTab(t);
      }
      resolve();
    });
  });
})();

// ピン留め切替を追従し、content.js にも通知する
chrome.tabs.onUpdated.addListener((tabId, info, tab) => {
  if (info.pinned === true) {
    setBaseFromTab(tab);
  } else if (info.pinned === false) {
    deleteLocked(tabId);
  }
  if (typeof info.pinned === "boolean") {
    chrome.tabs.sendMessage(tabId, { type: "pinnedChanged", pinned: info.pinned }, () => {
      // content script が居ないページ（chrome:// 等）はエラーになるが無視
      void chrome.runtime.lastError;
    });
  }
});

chrome.tabs.onRemoved.addListener((tabId) => {
  deleteLocked(tabId);
  ownCreatedTabs.delete(tabId);
  restoring.delete(tabId);
  lastBounce.delete(tabId);
  typedAllow.delete(tabId);
});

// 「同一ページ」判定。ハッシュルーティング SPA（EMA 等）では
// ハッシュ部分がページに相当するため、単純な pathname 比較では
// /#/endpoints と /# が同一扱いになってしまう。routeOf で正規化して比較する。
// クエリ差や #section のような通常のアンカー差は同一ページのまま。
function isSamePage(a, b) {
  try {
    const ua = new URL(a), ub = new URL(b);
    return ua.origin === ub.origin && routeOf(a) === routeOf(b);
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
    // ハッシュルーティングではクエリもハッシュ内に入る（#/route?query）ため、
    // "?" 以降を切り落としてルート部分だけを比較対象にする
    const hashRoute = x.hash.slice(1).split("?")[0];
    p += hashRoute.replace(/\/+$/, "");
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
    (async () => {
      await ready; // SW 再起動直後は基準URLの復元完了を待つ

      const tabId = sender.tab.id;
      let base = lockedUrl.get(tabId);
      const target = msg.href;

      // SW 再起動等で基準が未登録でも、送信元タブがピン留めなら
      // 現時点のタブURL（クリック時点＝遷移前なので基準そのもの）を採用する
      if (!base && sender.tab.pinned && isHttp(sender.tab.url)) {
        base = sender.tab.url;
        setLocked(tabId, base);
      }

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
    })();
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

  // クールダウン: 直近にバウンスしたばかりのタブは再バウンスしない。
  // SPA ルーターとの相互応酬による無限タブ増殖を構造的に断ち切る安全弁。
  const now = Date.now();
  if (now - (lastBounce.get(tabId) || 0) < 1500) return;
  lastBounce.set(tabId, now);

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

chrome.webNavigation.onCommitted.addListener(async (details) => {
  if (details.frameId !== 0) return; // メインフレームのみ
  await ready;
  const tabId = details.tabId;

  // 差し戻し猶予中の遷移はすべて無視（時間窓方式）
  if (isRestoring(tabId)) return;

  // 自作の新規タブの初回遷移は無視
  if (ownCreatedTabs.has(tabId)) {
    ownCreatedTabs.delete(tabId);
    return;
  }

  if (!lockedUrl.has(tabId)) return;

  const quals = Array.isArray(details.transitionQualifiers)
    ? details.transitionQualifiers
    : [];

  // アドレスバー直接入力は基準URLの更新として許可（差し戻さない = リロードなし）。
  // 注意: ブックマークバーのクリックも transitionType が "typed" になる場合があるため、
  // 実際にアドレスバーを経由した証拠である "from_address_bar" 修飾子を必須にする。
  if (details.transitionType === "typed" && quals.includes("from_address_bar") && isHttp(details.url)) {
    setLocked(tabId, details.url);
    typedAllow.set(tabId, Date.now());
    return;
  }

  // typed 直後のリダイレクト（例: Confluence の /SYS → /SYS/overview）は
  // 入力遷移の続きなので、リダイレクト先を基準URLとして引き継ぐ
  if (
    (quals.includes("server_redirect") || quals.includes("client_redirect")) &&
    Date.now() - (typedAllow.get(tabId) || 0) < 3000 &&
    isHttp(details.url)
  ) {
    setLocked(tabId, details.url);
    return;
  }

  bounceNavigation(tabId, details.url);
});

// SPA のクライアントサイド遷移（history.pushState 等）
// ShotGrid のような SPA のページ切替はこちらで発火する
chrome.webNavigation.onHistoryStateUpdated.addListener(async (details) => {
  if (details.frameId !== 0) return;
  await ready;
  // 差し戻し猶予中の SPA イベント（goBack への反応の連発）はすべて無視
  if (isRestoring(details.tabId)) return;
  bounceNavigation(details.tabId, details.url);
});

// ハッシュのみの遷移（/#/endpoints → /# など）は onCommitted にも
// onHistoryStateUpdated にも来ず、このイベントで発火する。
// ハッシュルーティング SPA（EMA 等）のルート変更を取りこぼさないために必要。
chrome.webNavigation.onReferenceFragmentUpdated.addListener(async (details) => {
  if (details.frameId !== 0) return;
  await ready;
  if (isRestoring(details.tabId)) return;
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
