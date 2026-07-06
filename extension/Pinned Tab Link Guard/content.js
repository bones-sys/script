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

document.addEventListener(
  "click",
  (e) => {
    // 固定タブでなければブラウザ標準の挙動に任せる（SPA も壊さない）
    if (!isPinned) return;

    const a = e.target.closest("a[href]");
    if (!a) return;

    // 左クリックのみ対象。修飾キー押下時はブラウザ標準の挙動を尊重
    if (e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;

    // すでに別タブで開く指定があるものは触らない
    if (a.target === "_blank") return;

    const href = a.href;
    if (!href) return;
    if (href.startsWith("javascript:")) return;

    // 同一ページ内アンカー（#section）はそのまま
    const hashOnly =
      a.hash &&
      a.origin === location.origin &&
      a.pathname === location.pathname &&
      a.search === location.search;
    if (hashOnly) return;

    // 遷移を止めて background に依頼（固定タブ側は一切遷移しない）
    e.preventDefault();
    e.stopPropagation();

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
  true
);
