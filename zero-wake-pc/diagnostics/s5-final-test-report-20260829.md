# ZERO WAKE PC — S5 final test report

Status: `ZERO_WAKE_PC_COMPLETE`

| Test | Result | Evidence |
|---|---|---|
| TEST-01 sender packet reaches LAN | PASS | Three end-to-end S5 wakes prove valid packet delivery to the target NIC |
| TEST-02 Sleep -> wake | PREVIOUS PASS | 2026-08 baseline |
| TEST-03 Restart -> Sleep -> wake | PASS (baseline preserved) | BIOS restart retained Windows wake settings |
| TEST-04 Normal shutdown -> 30 sec -> wake | PASS | Smartphone ZERO WAKE PC powered on the PC |
| TEST-05 S5 repeat 3/3 | 3/3 PASS | Runs booted at 23:32:21, 23:41:19, and 23:48:09 JST |
| TEST-06 app restart -> S5 wake | PENDING | Optional after 3/3 |
| TEST-07 Android restart -> S5 wake | PENDING | Optional after 3/3 |

## Completion guard

Do not report `ZERO_WAKE_PC_COMPLETE` until TEST-01 and S5 3/3 are measured PASS and Windows/network recovery is confirmed.

## Rollback

- 2026-08-29 diagnostic changed no Windows or BIOS setting.
- Original and 2026-08-18 applied values remain documented in `wol-settings-before-20260818.md` and `wol-settings-after-20260818.txt`.
- If the single BIOS Wake-on-LAN item is changed, record its prior value here before modification.

## Run 1 evidence

- BIOS Owner Gate: `LANによるウェイクアップ = 使用する`, saved with F10.
- Owner confirmed the PC powered on from the smartphone while the Ethernet cable remained connected.
- Evidence collected: `2026-08-29T23:37:28.4011133+09:00`.
- Computer: `LAPTOP-32D9HNI7`.
- Windows boot: `2026-08-29T23:32:21.5000000+09:00`.
- NIC: `Up`, `1 Gbps`, MAC `68-84-7E-5E-34-D1`, IPv4 `192.168.0.16/24`.
- Chrome Remote Desktop: `Running`, start type `Automatic`.
- Result: `S5_WAKE_RUN_1 = PASS`.

## Run 2 evidence

- Owner confirmed smartphone ZERO WAKE PC powered on the S5 PC.
- Evidence collected: `2026-08-29T23:44:17.6236292+09:00`.
- Windows boot: `2026-08-29T23:41:19.5000000+09:00`.
- NIC: `Up`, `1 Gbps`, MAC `68-84-7E-5E-34-D1`, IPv4 `192.168.0.16/24`.
- Chrome Remote Desktop: `Running`, start type `Automatic`.
- Result: `S5_WAKE_RUN_2 = PASS`.

## Run 3 evidence

- Owner confirmed smartphone ZERO WAKE PC powered on the S5 PC.
- Evidence collected: `2026-08-29T23:51:02.7897583+09:00`.
- Windows boot: `2026-08-29T23:48:09.5000000+09:00`.
- NIC: `Up`, `1 Gbps`, MAC `68-84-7E-5E-34-D1`, IPv4 `192.168.0.16/24`.
- Chrome Remote Desktop: `Running`, start type `Automatic`.
- Result: `S5_WAKE_RUN_3 = PASS`.

## Final verdict

- S5 wake repeat: `3/3 PASS`.
- Android packet path: PASS by end-to-end S5 wake evidence.
- Windows boot: PASS.
- Network recovery: PASS.
- Chrome Remote Desktop recovery: PASS.
- Root cause: BIOS `LANによるウェイクアップ` was not enabled for power-off wake.
- Fix: set it to `使用する` and save with F10.
- Final: `ZERO_WAKE_PC_COMPLETE`.
