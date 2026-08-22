# DAIMON local tester operations

Real tester PII is kept outside Git in a Windows DPAPI (`CurrentUser`) encrypted ledger. Default store: `%LOCALAPPDATA%\DAIMON\tester-ops\ledger.dpapi`.

```powershell
.\Invoke-TesterOps.ps1 -Action Enroll
.\Invoke-TesterOps.ps1 -Action Daily
.\Invoke-TesterOps.ps1 -Action ExportTemplate -ExportPath "$env:TEMP\daimon-tester-template.csv"
.\Test-TesterOps.ps1
```

The ledger is bound to the current Windows user; it is not itself a backup strategy. Owner must approve an encrypted backup and retention/deletion policy before live recruitment. Never commit the ledger, real participant exports, screenshots, purchase tokens, OTPs or credentials.

