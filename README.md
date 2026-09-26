# DonGrobione.StratoHiDriveUtils

PowerShell module for controlling the STRATO HiDrive desktop application and reading the configured sync root directory from HiDrive logs.
This module was primarily created for personal use.

## Project Structure

```text
DonGrobione.StratoHiDriveUtils/
|-- License.md                            # CC BY-NC-SA 4.0 license for this project
|-- Install-StratoHiDriveUtils.ps1        # One-command installer for the latest release
|-- DonGrobione.StratoHiDriveUtils.psd1   # Module manifest
|-- DonGrobione.StratoHiDriveUtils.psm1   # Main module with exported functions
`-- README.md                             # This documentation
```

## Module Overview

The module is defined by `DonGrobione.StratoHiDriveUtils.psd1` and loads `DonGrobione.StratoHiDriveUtils.psm1`.
It exports four functions:

- `Start-HiDrive`
- `Stop-HiDrive`
- `Get-HiDriveSyncRoot`
- `Update-StratoHiDriveUtils`

## Requirements

- Windows PowerShell 5.1
- Installed STRATO [HiDrive desktop client](https://static.hidrive.com/windows/0000)
- Read access to `%LOCALAPPDATA%\HiDrive\Logs` and `%LOCALAPPDATA%\HiDrive\Data`

## Installation

### Option 1: One-Command Installer (recommended)

Copy the following single line into Windows PowerShell 5.1.
It downloads and runs the installer directly:

```powershell
irm https://raw.githubusercontent.com/DonGrobione/StratoHiDriveUtils/v2.0.0/Install-StratoHiDriveUtils.ps1 | iex
```

The installer downloads the latest GitHub ZIP release and checks the manifest version before installation.
If the current ZIP release is already installed, it reports this and makes no changes.
Older installations, Git installations, and installations under the legacy module name `StratoHiDriveUtils` are removed and replaced at the Windows PowerShell 5.1 user module path.

### Upgrading from Version 1.x

Version 2.0.0 renamed the module from `StratoHiDriveUtils` to `DonGrobione.StratoHiDriveUtils`.
`Update-StratoHiDriveUtils` from version 1.x cannot install the renamed release.
Run the one-command installer once instead; it removes the old `StratoHiDriveUtils` installation and installs the renamed module.
Scripts that import the module by name must be changed to `Import-Module DonGrobione.StratoHiDriveUtils`.

### Option 2: ZIP Download (manual installation)

The latest version is available as a ZIP file on the [Releases page](https://github.com/DonGrobione/StratoHiDriveUtils/releases).

After downloading, extract the ZIP into the appropriate module directory:

| PowerShell Version | Target Directory |
|--------------------|------------------|
| Windows PowerShell 5.1 | `%USERPROFILE%\Documents\WindowsPowerShell\Modules\DonGrobione.StratoHiDriveUtils` |

> **Note:** The target directory must be named `DonGrobione.StratoHiDriveUtils` for PowerShell to auto-discover the module.
> Keep only one installation in the active PowerShell version's `PSModulePath`.

Then load the module:

```powershell
Import-Module DonGrobione.StratoHiDriveUtils -Force
Get-Command -Module DonGrobione.StratoHiDriveUtils
```

---

## Usage

### 1) Start HiDrive

```powershell
Import-Module DonGrobione.StratoHiDriveUtils -Force
Start-HiDrive
```

`Start-HiDrive` checks common install paths and starts `HiDrive.App.exe`.
If no executable is found, the function throws an error.

### 2) Stop HiDrive

```powershell
Import-Module DonGrobione.StratoHiDriveUtils -Force
Stop-HiDrive
```

`Stop-HiDrive` stops all processes whose name matches `*HiDrive*`.
The function first sends a graceful close request and then force-stops remaining matching processes.
If no process is running, it exits without error.
If a remaining process cannot be force-stopped, the function writes a non-terminating error with the ID `HiDriveProcessStopFailed` for that process and continues with the others.
In practice, `HiDrive.App` and `HiDrive.Sync` are both terminated reliably.

### 3) Read Sync Root Directory

```powershell
Import-Module DonGrobione.StratoHiDriveUtils -Force
Get-HiDriveSyncRoot
```

This returns the sync root path directly (string), for example:

```text
C:\Users\<User>\HiDrive
```

If no matching log entry is found, the function writes a non-terminating error with the ID `HiDriveSyncRootNotFound` and returns no output.
The error message names the searched log folders and any log locations that could not be read.
The module never logs by itself, so the calling script decides how to handle and log the error.
Use `-ErrorAction Stop` with `try`/`catch` to detect a failed lookup, because an `-ErrorVariable` can also collect read errors of individual log files that the function already handled internally:

```powershell
Import-Module DonGrobione.StratoHiDriveUtils -Force
try {
    $syncRoot = Get-HiDriveSyncRoot -ErrorAction Stop
    "Sync root: $syncRoot"
} catch {
    "Sync root lookup failed: $($_.Exception.Message)"
}
```

### 4) Update from the ZIP Release

`Update-StratoHiDriveUtils` checks the latest GitHub release and updates the currently loaded module installation in place.
It does not create a second module directory.
The active module path must be present in the current PowerShell version's `PSModulePath`, and duplicate installations are rejected.
Existing Git installations must be replaced with the ZIP release first; the update command does not overwrite a Git working tree.

```powershell
Import-Module DonGrobione.StratoHiDriveUtils -Force
Update-StratoHiDriveUtils
```

To check the available version without changing anything, use `-WhatIf`:

```powershell
Update-StratoHiDriveUtils -WhatIf
```

After a successful update, reload the module:

```powershell
Remove-Module DonGrobione.StratoHiDriveUtils -Force -ErrorAction SilentlyContinue
Import-Module DonGrobione.StratoHiDriveUtils -Force
```

## Log Search Behavior in `Get-HiDriveSyncRoot`

The sync root is actually stored by HiDrive in the SQLite database `%LOCALAPPDATA%\HiDrive\Data\user.db`.
In practice, reading that value requires additional SQLite software or editor extensions.
To keep this module dependency-free, `Get-HiDriveSyncRoot` reads the sync root from HiDrive log entries instead.

The function searches these log files, including their rotated copies such as `log.0.txt` or `syncLog.0.txt`:

- Application logs: `%LOCALAPPDATA%\HiDrive\Logs\log.txt` (HiDrive 6.5.x)
- Sync logs: `%LOCALAPPDATA%\HiDrive\Data\<numeric folder>\syncLog.txt` (older versions and HiDrive 7.x)

Files are searched from the most recently written to the oldest, and the last matching entry of the first file with a match is returned.
It extracts entries matching:

- `FileSystemSnapshot: Get file system snapshot started. Root <path> |`
- `FSW: started for root <path> |`

## Troubleshooting

- `Start-HiDrive` fails:
  - Verify STRATO HiDrive is installed.
  - Verify one of these files exists:
    - `%ProgramFiles%\STRATO\HiDrive\HiDrive.App.exe`
    - `%ProgramFiles(x86)%\STRATO\HiDrive\HiDrive.App.exe`
    - `%LOCALAPPDATA%\STRATO\HiDrive\HiDrive.App.exe`
- `Get-HiDriveSyncRoot` reports `HiDriveSyncRootNotFound`:
  - HiDrive may not have completed an initial scan yet.
  - Check whether log files exist under `%LOCALAPPDATA%\HiDrive\Logs` or `%LOCALAPPDATA%\HiDrive\Data\<numeric folder>`.
  - Start HiDrive once and allow it to run briefly before trying again.

## Versioning

- Module version source of truth: `DonGrobione.StratoHiDriveUtils.psd1` (`ModuleVersion`).
- Current manifest version: `2.1.0`.
- The module file `DonGrobione.StratoHiDriveUtils.psm1` does not duplicate module version metadata.

### Create a New Release

1. Update `ModuleVersion` in `DonGrobione.StratoHiDriveUtils.psd1`, for example from `2.0.0` to `2.0.1`.
2. Commit the changes and merge them into `main`.
3. Push `main` to GitHub.

The GitHub Actions workflow runs automatically when `main` is updated.
It reads the manifest version, creates `DonGrobione.StratoHiDriveUtils-<version>.zip`, creates the GitHub tag `v<version>`, and publishes the GitHub Release with the ZIP attached.
The tag must not already exist.
For version `2.0.0`, the workflow creates tag `v2.0.0` and release file `DonGrobione.StratoHiDriveUtils-2.0.0.zip`.

## License

This project is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License (CC BY-NC-SA 4.0).
See `License.md` for the full license text.

## Disclaimer

I am in no way affiliated with STRATO or HiDrive.
This project is an independent, unofficial utility module and is not endorsed by, sponsored by, or connected to STRATO/HiDrive.

## AI Usage

This project was created with support from AI/KI tooling.
