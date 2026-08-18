(() => {
  const config = window.DAIMON_RELEASE || {};
  const live = config.state === "live" && /^https:\/\/play\.google\.com\/store\/apps\/details\?id=/.test(config.playStoreUrl || "");
  document.querySelectorAll("[data-release-link]").forEach((link) => {
    link.textContent = live ? config.liveLabel : config.prelaunchLabel;
    link.href = live ? config.playStoreUrl : "#release";
    link.classList.toggle("disabled", !live);
    link.setAttribute("aria-disabled", String(!live));
  });
  const copy = document.querySelector("[data-release-copy]");
  if (live && copy) copy.textContent = "490円・買い切り・広告なし。Google Playで販売中です。";
  const eyebrow = document.querySelector("[data-release-eyebrow]");
  if (live && eyebrow) eyebrow.textContent = "AVAILABLE ON GOOGLE PLAY";
})();
