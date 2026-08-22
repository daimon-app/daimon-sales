# Emulator QA results

- Emulator executable: installed (`37.1.11.0`)
- System image: installed (`android-35;google_apis;x86_64`)
- AVD: created (`daimon_api35`, Pixel 6 profile)
- Boot attempt: `BLOCKED / OWNER_PHYSICAL_ACTION_REQUIRED`
- Exact blocker: Android Emulator Hypervisor Driver is not installed; the emulator reported that x86_64 requires hardware acceleration.
- No app/device test is marked PASS from this attempt.
- Existing static readiness: 76 PASS / 0 WARN / 0 FAIL
- Android unit tests: PASS
- Signed bundle build: PASS

Installing/enabling the Windows hypervisor driver requires an elevated Windows/UAC lane and can require a reboot. Pixel USB approval remains the shorter physical-device route. Actual sensory audio validation still requires a physical device/person.
