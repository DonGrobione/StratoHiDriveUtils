# StratoHiDriveUtils

PowerShell module for controlling the STRATO HiDrive desktop application and reading the configured sync root directory from HiDrive logs.

## Disclaimer

I am in no way affiliated with STRATO or HiDrive.
This project is an independent, unofficial utility module and is not endorsed by, sponsored by, or connected to STRATO/HiDrive.

## AI Usage

This module was created with support from AI/KI tooling.

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
- Installed STRATO HiDrive desktop client
- Read access to `%LOCALAPPDATA%\HiDrive\Logs` and `%LOCALAPPDATA%\HiDrive\Data`

## Installation and Import

Run from the project root directory:

```powershell
Import-Module .\StratoHiDriveUtils.psd1 -Force
Get-Command -Module StratoHiDriveUtils
```

If the module name is not automatically resolved from file name in your session:

```powershell
Import-Module "$PSScriptRoot\StratoHiDriveUtils.psd1" -Force
```

## Usage

### 1) Start HiDrive

```powershell
Import-Module .\StratoHiDriveUtils.psm1 -Force
Start-HiDrive
```

`Start-HiDrive` checks common install paths and starts `HiDrive.App.exe`.
If no executable is found, the function throws an error.

### 2) Stop HiDrive

```powershell
Import-Module .\StratoHiDriveUtils.psm1 -Force
Stop-HiDrive
```

`Stop-HiDrive` stops all processes whose name matches `*HiDrive*`.
The function sends a graceful close request to all matching processes and returns immediately.
If no process is running, it exits without error.
In practice, `HiDrive.App` and `HiDrive.Sync` usually stop almost immediately, while `HiDrive UI` can take longer to close.

### 3) Read Sync Root Directory

```powershell
Import-Module .\StratoHiDriveUtils.psm1 -Force
Get-HiDriveSyncRoot
```

This returns the sync root path directly (string), for example:

```text
C:\Users\<User>\HiDrive
```

If no matching log entry is found, the function returns `$null`.

Optional guarded usage:

```powershell
Import-Module .\StratoHiDriveUtils.psm1 -Force
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

- Module help version in `StratoHiDriveUtils.psm1`: `1.0`
- Keep this README and module help examples in sync when behavior changes.

## License

This project is licensed under the MIT License.
See `License.md` for the full license text.
