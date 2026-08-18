# Play Console answer map — draft from audited AAB

Do not submit until the signed API 36 AAB has completed physical-device QA and Console analysis.

- Ads: No
- App access: All functionality is available without login or membership
- Data collection/share: no developer collection or sharing is implemented; no third-party SDKs. The app declares no INTERNET permission and has no app network path
- On-device values: optional name and audio preference. User can delete both in the app
- TTS boundary: text is passed to Android TextToSpeech; processing behavior depends on the engine selected on the device. Do not claim control over every installed engine
- Permissions: none
- Network: none
- Target audience proposal: general audience; owner must select final age groups in Console
- Content rating/IARC facts: fixed affirmation text; no violence, sex, drugs, gambling, user-generated content, purchases inside the app, location sharing, or social features
- Medical: not a medical, diagnostic, or treatment app
- Countries: owner decision
- Price: owner sets 490 JPY as a paid app; no in-app billing SDK
- Privacy policy URL / support email: owner values required
- Testing: inspect the account-specific Console requirement; prepare internal/closed track, tester instructions, and feedback route before production access
