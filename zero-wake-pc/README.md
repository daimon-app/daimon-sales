# Zero Wake PC

同一LAN内へWake-on-LAN Magic Packetを送信するAndroidアプリです。

- MAC: `68:84:7E:5E:34:D1`
- Broadcast: `192.168.0.255`
- UDP port: `9`

「PC 電源ON」で設定を端末内へ保存し、Magic Packetを3回送信します。

## Verified completion

On 2026-08-29, the target FUJITSU `FMVAXD3BZ` (`LAPTOP-32D9HNI7`) completed three consecutive full-shutdown (S5) wake tests from the installed Android app.

- Target NIC: Realtek PCIe GbE Family Controller
- MAC: `68:84:7E:5E:34:D1`
- Broadcast: `192.168.0.255`
- UDP port: `9`
- BIOS: `LANによるウェイクアップ = 使用する`
- Fast Startup: disabled
- S5 wake: `3/3 PASS`
- Windows/network/Chrome Remote Desktop recovery: PASS

See `ZERO_WAKE_PC_MASTER.md` and `diagnostics/s5-final-test-report-20260829.md` for the canonical state and evidence.
