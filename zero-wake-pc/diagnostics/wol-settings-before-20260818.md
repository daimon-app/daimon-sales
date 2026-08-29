# ZERO REMOTE POWER - WOL settings before change

Recorded: 2026-08-18 JST

## Adapter

- Name: Realtek PCIe GbE Family Controller
- Interface: イーサネット
- MAC: 68-84-7E-5E-34-D1
- PnP ID: PCI\VEN_10EC&DEV_8168&SUBSYS_00171E26&REV_15\01000000684CE00000
- Driver: 1168.10.720.2022
- Driver date: 2022-07-21
- INF: oem73.inf

## Original values

- Energy-Efficient Ethernet (`*EEE`): Enabled (`1`)
- Green Ethernet (`EnableGreenEthernet`): Enabled (`1`)
- Power Saving Mode (`PowerSavingMode`): Enabled (`1`)
- Wake on Magic Packet (`*WakeOnMagicPacket`): Enabled (`1`)
- Wake on pattern match (`*WakeOnPattern`): Enabled (`1`)
- Shutdown Wake-On-Lan (`S5WakeOnLan`): Enabled (`1`)
- WOL & Shutdown Link Speed (`WolShutdownLinkSpeed`): 10 Mbps First (`0`)
- Fast startup (`HiberbootEnabled`): Enabled (`1`)
- `wake_armed`: Realtek PCIe GbE Family Controller present

## Rollback values

Restore the original values above if rollback is required. No BIOS value was changed.
