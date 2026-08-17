const AGENTS = [
  { id: "codex", name: "Codex", mark: "C", role: "PC・コード・Git" },
  { id: "gemini", name: "Gemini", mark: "G", role: "調査・Google・別解" },
  { id: "claude", name: "Claude", mark: "Cl", role: "レビュー・設計監査" },
  { id: "manus", name: "Manus", mark: "M", role: "Web実務・長時間作業" }
];
const initial = [{
  role: "zero",
  text: "AI5 HUBへようこそ。私、ゼロにだけ指示してください。目的を整理し、Codexを施工司令塔として必要な兄弟だけに振り分けます。",
  at: new Date().toISOString(), routed: []
}];
const state = { messages: JSON.parse(localStorage.getItem("ai5.messages") || "null") || initial };
const agentsEl = document.querySelector("#agents");
const messagesEl = document.querySelector("#messages");
const composer = document.querySelector("#composer");
const promptEl = document.querySelector("#prompt");
const jobStatus = document.querySelector("#jobStatus");

agentsEl.innerHTML = AGENTS.map(a => `<div class="agent"><span class="avatar">${a.mark}</span><span><b>${a.name}</b><small>${a.role}</small></span><i class="status"></i></div>`).join("");

function escapeHtml(value) {
  return value.replace(/[&<>'"]/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;","'":"&#39;",'"':"&quot;"})[c]);
}
function render() {
  messagesEl.innerHTML = state.messages.map(message => {
    const user = message.role === "user";
    const chips = (message.routed || []).map(id => `<span class="chip">${AGENTS.find(a => a.id === id)?.name || id}</span>`).join("");
    const time = new Date(message.at).toLocaleTimeString("ja-JP", {hour:"2-digit", minute:"2-digit"});
    return `<article class="message ${user ? "user" : ""}"><span class="avatar">${user ? "本人" : "0"}</span><div><div class="bubble">${escapeHtml(message.text).replace(/\n/g,"<br>")}${chips ? `<div class="routing">${chips}</div>` : ""}</div><div class="meta">${time}</div></div></article>`;
  }).join("");
  messagesEl.scrollTop = messagesEl.scrollHeight;
}
function route(text) {
  const rules = [
    ["claude", /レビュー|監査|設計|原因|難しい|バグ/],
    ["gemini", /調査|最新|Google|画像|動画|資料|別解/],
    ["manus", /ブラウザ|Web|販売|競合|LP|掲載|収集/],
    ["codex", /コード|実装|修正|PC|Windows|Git|Excel|ファイル|テスト|作って/]
  ];
  const hits = rules.filter(([, pattern]) => pattern.test(text)).map(([id]) => id);
  return hits.length ? [...new Set(["codex", ...hits])] : ["codex"];
}
function persist() { localStorage.setItem("ai5.messages", JSON.stringify(state.messages.slice(-100))); }

composer.addEventListener("submit", event => {
  event.preventDefault();
  const text = promptEl.value.trim();
  if (!text) return;
  const routed = route(text);
  state.messages.push({role:"user", text, at:new Date().toISOString(), routed:[]});
  state.messages.push({role:"zero", text:`了解しました。目的を整理し、${routed.map(id => AGENTS.find(a => a.id === id).name).join("・")}へ施工を割り振ります。現在のMVPでは外部送信せず、振り分け案だけを表示しています。`, at:new Date().toISOString(), routed});
  promptEl.value = "";
  jobStatus.innerHTML = `<span>ROUTED</span><b>${routed.length}名で施工予定</b><small>${escapeHtml(text.slice(0, 46))}</small>`;
  persist(); render();
});
promptEl.addEventListener("input", () => { promptEl.style.height = "auto"; promptEl.style.height = `${Math.min(promptEl.scrollHeight, 140)}px`; });
document.querySelector("#flowButton").addEventListener("click", () => document.querySelector("#activity").classList.add("open"));
document.querySelector("#closeFlow").addEventListener("click", () => document.querySelector("#activity").classList.remove("open"));
render();
