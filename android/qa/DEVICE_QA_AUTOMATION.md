# Device QA automation

`run-connected-qa.ps1` fails unless exactly one authorized Android device is attached. It captures device identity, launch evidence, screenshot, memory state and error log without changing account or billing configuration.

Pixel owner action is limited to USB connection, unlock and the ADB authorization dialog. Then run the script once. Four-mode navigation, perceived audio/binaural quality and Play-track purchase lifecycle remain manual evidence items and are never auto-PASSed.

Emulator status on 2026-08-22: `BLOCKED_ENVIRONMENT` — the installed SDK has platform/build tools but no emulator binary, AVD or system image. No emulator result is fabricated.
