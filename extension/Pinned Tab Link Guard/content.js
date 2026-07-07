// ===== Pinned Tab Link Guard (content) =====
// 固定（ピン留め）タブのときだけリンククリックを横取りし、
// 遷移が始まる前に background へ依頼して新規タブで開く。
// → 固定タブ側では遷移自体が発生しないため、リロードが起きない。
//
// 非固定タブでは一切干渉しない（SPA の pushState 遷移を壊さないため）。

let isPinned = false;

// 起動時に自タブのピン状態を問い合わせる
chrome.runtime.sendMessage({ type: "getPinned" }, (res) => {
  if (chrome.runtime.lastError) return; // SW 未起動などは無視（後続の通知で追従）
  isPinned = !!(res && res.pinned);
});

// ピン留めの付け外しを background から通知してもらう
chrome.runtime.onMessage.addListener((msg) => {
  if (msg && msg.type === "pinnedChanged") {
    isPinned = !!msg.pinned;
  }
});

// キャプチャフェーズ（ページのどのハンドラよりも先）でクリックを奪う。
// ShotGrid のような SPA のルーターに遷移処理を始めさせないことが目的。
// 一度ルーターに遷移させてから goBack で差し戻すと、URL とルーターの
// 内部状態がズレて「同じリンクを押しても無反応」になることがある。
// パネル・メニュー開閉用の <a>（Google アプリランチャー等）は
// 下の属性チェックで除外するので、キャプチャでも壊れない。
window.addEventListener(
  "click",
  (e) => {
    // 固定タブでなければブラウザ標準の挙動に任せる（SPA も壊さない）
    if (!isPinned) return;

    if (e.defaultPrevented) return;

    const a = e.target.closest("a[href]");
    if (!a) return;

    // 生の href 属性が "#" 始まり（または空）のアンカーは、
    // JS がクリックを処理する前提のボタンか同一ドキュメント内の遷移。
    // 例: EMA の一覧行は <a href="#"> で、実遷移は EMA の JS が行う。
    // ここで横取りするとページの機能自体を壊すので一切触らない。
    // 遷移した結果どこへ行くかは background 側
    // （onReferenceFragmentUpdated + 同一/子/別ページ判定）が監視する。
    const rawHref = a.getAttribute("href") || "";
    if (rawHref === "" || rawHref.startsWith("#")) return;

    // パネルやメニューの開閉トグルとして使われる <a> は対象外。
    // （万一本当に遷移した場合は webNavigation 側のフォールバックが拾う）
    if (
      a.getAttribute("role") === "button" ||
      a.hasAttribute("aria-haspopup") ||
      a.hasAttribute("aria-expanded")
    ) return;

    // 左クリックのみ対象。修飾キー押下時はブラウザ標準の挙動を尊重
    if (e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;

    // すでに別タブで開く指定があるものは触らない
    if (a.target === "_blank") return;

    const href = a.href;
    if (!href) return;
    if (href.startsWith("javascript:")) return;

    // 同一ページ内アンカー（#section）はそのまま。
    // ただし "#/..." はハッシュルーティング SPA のページ切替なので
    // アンカー扱いせず、background に同一/子/別ページの判断を委ねる。
    const hashOnly =
      a.hash &&
      !a.hash.startsWith("#/") &&
      a.origin === location.origin &&
      a.pathname === location.pathname &&
      a.search === location.search;
    if (hashOnly) return;

    // 遷移を止め、SPA ルーターにも渡さず、background に依頼する
    e.preventDefault();
    e.stopImmediatePropagation();

    chrome.runtime.sendMessage({ type: "linkClick", href }, (res) => {
      if (chrome.runtime.lastError) {
        // 拡張が応答できない場合は通常遷移にフォールバック
        window.location.href = href;
        return;
      }
      if (res && res.handled) return; // 新規タブで開いた
      window.location.href = href;    // 同一ページ扱いなど → 自前で遷移
    });
  },
  true // キャプチャフェーズ: SPA ルーターより先に処理する
);
