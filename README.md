# StratoHiDriveUtils

PowerShell module for controlling the STRATO HiDrive desktop application and reading the configured sync root directory from HiDrive logs.
This module was primarily created for personal use.

## Project Structure

```text
StratoHiDriveUtils/
|-- License.md                # CC BY-NC-SA 4.0 license for this project
|-- Install-StratoHiDriveUtils.ps1 # One-command installer for the latest release
|-- StratoHiDriveUtils.psd1   # Module manifest
|-- StratoHiDriveUtils.psm1   # Main module with exported functions
`-- README.md                 # This documentation
```

## Module Overview

The module is defined by `StratoHiDriveUtils.psd1` and loads `StratoHiDriveUtils.psm1`.
It exports three functions:

- `Start-HiDrive`
- `Stop-HiDrive`
- `Get-HiDriveSyncRoot`
- `Update-StratoHiDriveUtils`

## Requirements

- Windows
- Windows PowerShell 5.1
- Installed STRATO [HiDrive desktop client](https://static.hidrive.com/windows/0000)
- Read access to `%LOCALAPPDATA%\HiDrive\Logs` and `%LOCALAPPDATA%\HiDrive\Data`

## Installation

### Option 1: One-Command Installer (recommended)

Copy the following single line into Windows PowerShell 5.1. It downloads and
runs the installer directly:

```powershell
irm https://raw.githubusercontent.com/DonGrobione/StratoHiDriveUtils/main/Install-StratoHiDriveUtils.ps1 | iex
```

The installer downloads the latest GitHub ZIP release and checks the manifest
version before installation. If the current ZIP release is already installed,
it reports this and makes no changes. Older installations and Git installations
are removed and replaced at the Windows PowerShell 5.1 user module path.

### Option 2: ZIP Download (manual installation)

The latest version is available as a ZIP file on the [Releases page](https://github.com/DonGrobione/StratoHiDriveUtils/releases).

After downloading, extract the ZIP into the appropriate module directory:

| PowerShell Version | Target Directory |
|--------------------|------------------|
| Windows PowerShell 5.1 | `%USERPROFILE%\Documents\WindowsPowerShell\Modules\StratoHiDriveUtils` |

> **Note:** The target directory must be named `StratoHiDriveUtils` for PowerShell to auto-discover the module. Keep only one installation in the active PowerShell version's `PSModulePath`.

Then load the module:

```powershell
Import-Module StratoHiDriveUtils -Force
Get-Command -Module StratoHiDriveUtils
```

---

## Usage

### 1) Start HiDrive

```powershell
Import-Module StratoHiDriveUtils -Force
Start-HiDrive
```

`Start-HiDrive` checks common install paths and starts `HiDrive.App.exe`.
If no executable is found, the function throws an error.

### 2) Stop HiDrive

```powershell
Import-Module StratoHiDriveUtils -Force
Stop-HiDrive
```

`Stop-HiDrive` stops all processes whose name matches `*HiDrive*`.
The function first sends a graceful close request and then force-stops remaining matching processes.
If no process is running, it exits without error.
In practice, `HiDrive.App` and `HiDrive.Sync` are both terminated reliably.

### 3) Read Sync Root Directory

```powershell
Import-Module StratoHiDriveUtils -Force
Get-HiDriveSyncRoot
```

This returns the sync root path directly (string), for example:

```text
C:\Users\<User>\HiDrive
```

If no matching log entry is found, the function returns `$null`.

### 4) Update from the ZIP Release

`Update-StratoHiDriveUtils` checks the latest GitHub release and updates the
currently loaded module installation in place. It does not create a second
module directory. The active module path must be present in the current
PowerShell version's `PSModulePath`, and duplicate installations are rejected.
Existing Git installations must be replaced with the ZIP release first; the
update command does not overwrite a Git working tree.

```powershell
Import-Module StratoHiDriveUtils -Force
Update-StratoHiDriveUtils
```

To check the available version without changing anything, use `-WhatIf`:

```powershell
Update-StratoHiDriveUtils -WhatIf
```

After a successful update, reload the module:

```powershell
Remove-Module StratoHiDriveUtils -Force -ErrorAction SilentlyContinue
Import-Module StratoHiDriveUtils -Force
```

Optional guarded usage:

```powershell
Import-Module StratoHiDriveUtils -Force
$syncRoot = Get-HiDriveSyncRoot
if ($null -ne $syncRoot) {
    "Sync root: $syncRoot"
} else {
    "No sync root entry found in HiDrive logs."
}
```

## Log Search Behavior in `Get-HiDriveSyncRoot`

The sync root is actually stored by HiDrive in the SQLite database `%LOCALAPPDATA%\HiDrive\Data\user.db`.
In practice, reading that value requires additional SQLite software or editor extensions. To keep this module dependency-free, `Get-HiDriveSyncRoot` reads the sync root from HiDrive log entries instead.

The function searches in this order:

1. Current log path: `%LOCALAPPDATA%\HiDrive\Logs\log.txt`
2. Legacy fallback: `%LOCALAPPDATA%\HiDrive\Data\<numeric folder>\syncLog.txt`

It extracts entries matching:

- `FileSystemSnapshot: Get file system snapshot started. Root <path> |`

## Troubleshooting

- `Start-HiDrive` fails:
  - Verify STRATO HiDrive is installed.
  - Verify one of these files exists:
    - `%ProgramFiles%\STRATO\HiDrive\HiDrive.App.exe`
    - `%ProgramFiles(x86)%\STRATO\HiDrive\HiDrive.App.exe`
    - `%LOCALAPPDATA%\STRATO\HiDrive\HiDrive.App.exe`
- `Get-HiDriveSyncRoot` returns `$null`:
  - HiDrive may not have completed an initial scan yet.
  - Check whether log files exist under `%LOCALAPPDATA%\HiDrive\Logs`.
  - Start HiDrive once and allow it to run briefly before trying again.

## Versioning

- Module version source of truth: `StratoHiDriveUtils.psd1` (`ModuleVersion`).
- Current manifest version: `1.1.3`.
- The module file `StratoHiDriveUtils.psm1` does not duplicate module version metadata.

### Create a New Release

1. Update `ModuleVersion` in `StratoHiDriveUtils.psd1`, for example from `1.1.3` to `1.1.4`.
2. Commit the changes and merge them into `main`.
3. Push `main` to GitHub.

The GitHub Actions workflow runs automatically when `main` is updated. It reads
the manifest version, creates `StratoHiDriveUtils-<version>.zip`, creates the
GitHub tag `v<version>`, and publishes the GitHub Release with the ZIP attached.
The tag must not already exist. For version `1.1.4`, the workflow creates tag
`v1.1.4` and release file `StratoHiDriveUtils-1.1.4.zip`.

## License

This project is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License (CC BY-NC-SA 4.0). See `License.md` for the full license text.

## Disclaimer

I am in no way affiliated with STRATO or HiDrive. This project is an independent, unofficial utility module and is not endorsed by, sponsored by, or connected to STRATO/HiDrive.

## AI Usage

This module was created with support from AI/KI tooling.
