# DAIMON signing status

- Upload key: generated 2026-08-22 for package candidate `app.daimon`.
- Storage: outside every Git worktree under the current Windows profile; passwords are DPAPI protected.
- Secondary encrypted-keystore backup: created outside the Git workspace.
- Alias: `daimon-upload`.
- Certificate SHA-256: `1E:9E:96:A5:82:F2:9A:FA:FE:D0:E9:49:20:FE:16:40:2D:90:28:33:E9:86:01:B0:B3:36:76:DE:76:EF:1B:8D`.
- Secret values and key bytes: never recorded in Git or this document.
- Gradle behavior: zero signing values builds an unsigned candidate; a partial set fails configuration; all four values enable upload signing.
- Play App Signing enrollment and upload-certificate registration: `OWNER ACTION REQUIRED`.
- Recovery: restore the three protected files to the documented profile signing directory under the same Windows account, then run `android/build-signed-release.ps1`.
- Signed AAB build/test/verification: `PASS` on 2026-08-22.
- Signed AAB SHA-256 after authoritative-verification client integration: `F9C054F3FD6121CAE5B0C58C5806DD788D3264B3C0A3D2F60AF0B8E455B7A880`.
- Prior signed pre-server-client AAB SHA-256: `49CFF8567C2BDB80C4246A2065564FA3191BBB99D93C711044565068AFA75BD6`.
- Previous unsigned Billing AAB SHA-256: `8F3EE89E60327E75AF3A154482C31C732305C43839E086A2B27BE414943513F6`; the difference is expected from signing/configuration changes.
- Partial signing environment rejection: `PASS`.
