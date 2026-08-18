/* 公開状態と販売URLの唯一の設定箇所。公開確定までは prelaunch を維持する。 */
window.DAIMON_RELEASE = Object.freeze({
  state: "prelaunch",
  playStoreUrl: "",
  prelaunchLabel: "発売日はこのページで案内",
  liveLabel: "Google Playで購入"
});
