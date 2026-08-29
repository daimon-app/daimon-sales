# ZERO WAKE PC — S5 read-only diagnostic

Recorded: 2026-08-29 JST

## Canonical recovery

- Local candidate: `zero-wake-pc/`
- Parent repository: `daimon-app/daimon-sales`
- Branch: `feat/ai5-sales-factory-v6`
- HEAD: `4bcc56282137473b4ec88bca14c5610741e15f6c`
- Branch vs remote: `0 ahead / 0 behind`
- Tracking: `zero-wake-pc/` is not tracked by any locally available remote branch.
- Existing local source, APK, scripts, and 2026-08-18 diagnostics were preserved. No repository, NIC, registry, BIOS, or power setting was changed during this diagnostic.

## Target identity

- Manufacturer: `FUJITSU CLIENT COMPUTING LIMITED`
- Model: `FMVAXD3BZ`
- Computer name: `LAPTOP-32D9HNI7`
- BIOS: `Version 1.19`, release date `2020-04-10`
- Baseboard: `FJNBB64`
- Windows: `Windows 11 Home 10.0.26200`, build `26200`

## Active target NIC

- Interface: `イーサネット`
- Device: `Realtek PCIe GbE Family Controller`
- PnP ID: `PCI\VEN_10EC&DEV_8168&SUBSYS_00171E26&REV_15\01000000684CE00000`
- MAC: `68:84:7E:5E:34:D1`
- Driver: Realtek `1168.10.720.2022`, dated `2022-07-21`, `oem73.inf`
- State: `Up`, `1 Gbps`, auto negotiation
- Wake permission: `powercfg wake_armed = present`; `MSPower_DeviceWakeEnable.Enable = true`

## Power and driver state

- ACPI S3: available
- Fast Startup: disabled by policy; `HiberbootEnabled = 0`
- Wake on Magic Packet: enabled (`*WakeOnMagicPacket = 1`)
- Wake on pattern: disabled (`*WakeOnPattern = 0`)
- Shutdown Wake-On-Lan: enabled (`S5WakeOnLan = 1`)
- WOL & Shutdown Link Speed: `10 Mbps First` (`WolShutdownLinkSpeed = 0`)
- EEE / Advanced EEE / Green Ethernet / Power Saving: disabled
- Gigabit Lite: enabled; no change is justified without evidence that it blocks S5 wake.
- Previous sleep wake: PASS
- Previous S5 wake: FAIL / unresolved

## Network

- IPv4: `192.168.0.16/24`, DHCP
- Gateway: `192.168.0.1`
- Directed LAN broadcast: `192.168.0.255`
- App broadcast value: matches current subnet
- UDP port: `9`

## Android sender

- MAC normalization requires exactly 12 hexadecimal digits.
- Packet layout: 6 bytes `FF`, followed by target MAC repeated 16 times; total 102 bytes.
- UDP broadcast is explicitly enabled.
- The packet is sent three times with 150 ms spacing.
- Offline `clean test assembleDebug`: PASS using bundled Gradle 8.9, JDK 17, and Android SDK.
- Rebuilt APK SHA-256: `6D78F917A34DF0FAB26B10DA6D77427EB2BE0800BB80BBB575932E9211D154F9`
- Existing release APK SHA-256: same.
- Source/build verification does not substitute for a live LAN packet capture.

## Root-cause classification

Windows and sender configuration already satisfy the documented prerequisites that can be verified locally. No additional Windows setting change is currently evidence-backed.

Leading unresolved dependency:

- `B4 — BIOS/UEFI Wake-on-LAN disabled or unverified`
- `B5 — S5 NIC standby power unavailable`, to be distinguished by BIOS state and Ethernet link LEDs after shutdown

Secondary live-test dependencies:

- `B6/B7 — packet delivery or LAN broadcast filtering`, requiring live packet capture from the installed Android sender

The model is documented by Fujitsu as supporting Wakeup on LAN. Fujitsu's official power-off Wake-on-LAN instructions separately require BIOS `LANによるウェイクアップ` to be set to `使用する`. The current BIOS value is not exposed through an available Windows management interface, so its state is not inferred.

Official references:

- https://www.fmworld.net/fmv/etc/1910/axd3bz.html
- https://azby.fmworld.net/itsumo/fukumaro/support_wol.html

## Safe next gate

1. Inspect BIOS `LANによるウェイクアップ`; change only that item to `使用する` if currently disabled, then save once.
2. Boot Windows and run a live Android packet capture before S5 testing.
3. Perform S5 wake 3/3, then verify Windows/network/Chrome Remote Desktop recovery.

No registry rollback is needed for this diagnostic because no setting was changed.
