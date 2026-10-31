# Codex Windows 10 Capture Fix

[中文](README.md)

An experimental, reversible adapter for one exact Sky 0.7.13 helper that times
out while capturing windows on Windows 10. This is not an official OpenAI fix.

Supported original SHA-256:
`49C7F43DA0C2A9DBCADFB0C993058147018BF7C1D0FDE4360DE11ACE2C98F45D`.
Expected patched SHA-256:
`25A8CD31B5BC44C387CBF53EC3FE4CD314B5FCAC0D8D84201F444F1B2DB10FAB`.
Locally tested on Windows 10 build 19045, Desktop 26.1027.3384.0.

## Usage

Use Windows PowerShell 5.1 (`powershell.exe`) from this directory:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Fix-Capture.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Fix-Capture.ps1 -Action Install
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Fix-Capture.ps1 -Action Rollback
```

The default check is read-only and offline. Multiple installed runtimes require
an explicit `-HelperPath`. Unknown hashes are refused. WindowsApps packages must
not be modified. Installation stops helper processes at the selected path;
finish other Computer Use tasks first and reconnect through the normal tool.
No UI input, private helper protocol, credentials, proxy or Codex configuration
changes are performed. Administrative rights are not required for user runtimes.

The exact original is backed up under
`%USERPROFILE%\.codex\backups\computer-use-helper`. Rollback verifies its hash.
Patching invalidates the vendor signature, and application updates may overwrite
the change. Do not force this profile onto a different file, even if the version
string matches.

The adapter downloads the upstream patcher at the commit in `profile.json`,
verifies its SHA-256 and caches it under `%LOCALAPPDATA%\CodexWin10CaptureFix`.
It then binds the exact inspected 0.7.13 profile locally. It does not redistribute
the upstream patcher, worker machine code or any vendor executable.

## Attribution and limitations

The callback/MTA worker patch engine is from
[codex-windows-fast-patch-skill](https://github.com/chen0416ccc-cpu/codex-windows-fast-patch-skill).
It is not our original invention. No upstream license was declared at review;
our MIT license covers only the original adapter/test/documentation here.
See [NOTICE](NOTICE.md).

Foreground Notepad capture recovered from a 5278ms timeout to 108ms. Ten dynamic
test captures succeeded in 83–116ms, and a genuinely new helper captured in
202ms. Occluded windows can return occluding content. Input actions, full OS
restart, suspend/resume, prolonged stability and exceptional lifetime handling
remain unverified. Read [the bounded validation record](docs/VALIDATION.md).

## Tests

Supply your own exact original; this repository contains no proprietary fixture:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Test-Fix.ps1 -OriginalPath "path-to-original-backup"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Fix-Capture.ps1 -Action Build -OriginalPath "path-to-original-backup" -OutputPath "new-candidate.exe"
```

Tests use temporary copies, validate candidate hashes, install/idempotence,
backup, rollback and unknown-input rejection. A passing file test is not runtime
screenshot acceptance. Do not post executables, credentials or private images
in issues; report versions, hashes and redacted errors only.
