# Sales E2E staging evidence

| Step | Evidence | Status |
|---|---|---|
| SNS-equivalent link → LP | UTM generator covers profile, pinned, p01-p30, cm-a-c | PASS (staging) |
| LP understanding | Hero states Morning, breathing, fixed 12 screens, about 90 seconds, Android, 490 JPY, one-time, no ads | PASS |
| LP CTA before launch | Disabled prelaunch CTA; empty Play URL cannot misdirect | PASS |
| LP → Play after launch | One `release-config.js` value switches all CTAs | READY, URL pending |
| Play listing | Copy, icon, 1024x500 PNG, five 1080x1920 screenshots, AAB audit map | READY, Console pending |
| Purchase | Paid-app purchase handled by Google Play; 490 JPY owner setting pending | APPROVAL GATE |
| Install | Debug APK builds; no connected device during audit | DEVICE QA PENDING |
| First launch | Onboarding and optional name in Morning-only build | IMPLEMENTED |
| Morning | Breathing → 12 fixed screens (~88.3 sec) → finish → home | IMPLEMENTED |
| Support | In-app Settings explains storage/delete; final legal/support contacts pending | APPROVAL GATE |
