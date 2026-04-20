# StratoHiDriveUtils

PowerShell module for controlling the STRATO HiDrive desktop application and reading the configured sync root directory from HiDrive logs.
This module was primarily created for personal use.

## Project Structure

```text
StratoHiDriveUtils/
|-- .gitignore                # Git ignore rules
|-- License.md                # MIT license for this project
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

## Requirements

- Windows
- PowerShell 5.1+ (PowerShell 7 also works)
- Installed STRATO [HiDrive desktop client](https://static.hidrive.com/windows/0000)
- Read access to `%LOCALAPPDATA%\HiDrive\Logs` and `%LOCALAPPDATA%\HiDrive\Data`

## Installation

### Option 1: ZIP Download (recommended for quick installation)

The latest version is available as a ZIP file on the [Releases page](https://github.com/DonGrobione/StratoHiDriveUtils/releases).

After downloading, extract the ZIP into the appropriate module directory:

| PowerShell Version | Target Directory |
|--------------------|------------------|
| Windows PowerShell 5.1 | `%USERPROFILE%\Documents\WindowsPowerShell\Modules\StratoHiDriveUtils` |
| PowerShell 7+ | `%USERPROFILE%\Documents\PowerShell\Modules\StratoHiDriveUtils` |

> **Note:** The target directory must be named `StratoHiDriveUtils` for PowerShell to auto-discover the module.

Then load the module:

```powershell
Import-Module StratoHiDriveUtils -Force
Get-Command -Module StratoHiDriveUtils
```

---

### Option 2: Git Sync (recommended for easy updates)

Copy the matching block and paste it into your shell.

### Windows PowerShell 5.1 (Install)

```powershell
New-Item -ItemType Directory -Path "$(($env:PSModulePath -split ';')[0])\StratoHiDriveUtils" -Force | Out-Null
git clone https://github.com/DonGrobione/StratoHiDriveUtils.git "$(($env:PSModulePath -split ';')[0])\StratoHiDriveUtils"
Import-Module StratoHiDriveUtils -Force
Get-Command -Module StratoHiDriveUtils
```

### Windows PowerShell 5.1 (Update)

```powershell
git -C "$(($env:PSModulePath -split ';')[0])\StratoHiDriveUtils" pull
Remove-Module StratoHiDriveUtils -Force -ErrorAction SilentlyContinue
Import-Module StratoHiDriveUtils -Force
```

### PowerShell 7+ (Install)

```powershell
New-Item -ItemType Directory -Path "$(($env:PSModulePath -split ';')[0])\StratoHiDriveUtils" -Force | Out-Null
git clone https://github.com/DonGrobione/StratoHiDriveUtils.git "$(($env:PSModulePath -split ';')[0])\StratoHiDriveUtils"
Import-Module StratoHiDriveUtils -Force
Get-Command -Module StratoHiDriveUtils
```

### PowerShell 7+ (Update)

```powershell
git -C "$(($env:PSModulePath -split ';')[0])\StratoHiDriveUtils" pull
Remove-Module StratoHiDriveUtils -Force -ErrorAction SilentlyContinue
Import-Module StratoHiDriveUtils -Force
```

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

## License

This project is licensed under the MIT License. See `License.md` for the full license text.

## Disclaimer

I am in no way affiliated with STRATO or HiDrive. This project is an independent, unofficial utility module and is not endorsed by, sponsored by, or connected to STRATO/HiDrive.

## AI Usage

This module was created with support from AI/KI tooling.
