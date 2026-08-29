# ZERO WAKE PC MASTER

Status: `ZERO_WAKE_PC_COMPLETE`

Verified: 2026-08-29 JST

## Target

- PC: FUJITSU `FMVAXD3BZ`
- Computer: `LAPTOP-32D9HNI7`
- BIOS: `Version 1.19`
- NIC: Realtek PCIe GbE Family Controller
- MAC: `68:84:7E:5E:34:D1`
- IPv4 at completion: `192.168.0.16/24`
- Broadcast: `192.168.0.255`
- UDP port: `9`

## Required state

- BIOS `LANによるウェイクアップ`: `使用する`
- Wake on Magic Packet: enabled
- Shutdown Wake-On-Lan: enabled
- NIC wake permission: enabled
- Fast Startup: disabled
- Wired Ethernet: connected
- Android sender: ZERO WAKE PC on the same LAN

## Verified behavior

- Magic Packet construction: `FF x 6 + target MAC x 16`, 102 bytes
- Android sends three UDP broadcasts with broadcast enabled
- Sleep wake baseline: PASS
- Full shutdown S5 wake: `3/3 PASS`
- Post-wake Windows boot: PASS
- Post-wake wired network: PASS
- Post-wake Chrome Remote Desktop automatic service recovery: PASS

## Root cause and fix

- Root cause: BIOS/UEFI `LANによるウェイクアップ` was not enabled for power-off wake.
- Fix: Owner changed only that BIOS item to `使用する` and saved with F10.
- Windows and Android settings were already correct and were not unnecessarily rewritten.

## Rollback

- BIOS rollback: restore `LANによるウェイクアップ` to its prior disabled state only if remote S5 wake must be disabled.
- Windows rollback values are preserved in `diagnostics/wol-settings-before-20260818.md`.
- No BIOS firmware, Secure Boot, BitLocker, router, driver, or unrelated Windows setting was changed.

## Evidence

- `diagnostics/read-only-diagnostic-20260829.md`
- `diagnostics/s5-final-test-report-20260829.md`
- `diagnostics/wol-settings-before-20260818.md`
- `diagnostics/wol-settings-after-20260818.txt`
