<#
.SYNOPSIS
PowerShell module to control STRATO HiDrive and read the configured sync root.

.DESCRIPTION
Provides functions to start and stop the HiDrive desktop app and to determine the
current sync root folder from HiDrive log files.

.EXAMPLE
Import-Module .\StratoHiDriveUtils.psm1 -Force
Start-HiDrive

Loads the module from the current directory and starts HiDrive.

.EXAMPLE
Import-Module .\StratoHiDriveUtils.psm1 -Force
Stop-HiDrive

Loads the module and stops all running HiDrive processes.

.EXAMPLE
Import-Module .\StratoHiDriveUtils.psm1 -Force
Get-HiDriveSyncRoot

Returns the sync root path directly, for example:
C:\Users\<User>\HiDrive

If no entry is available in logs, the function returns $null.

.EXAMPLE
Import-Module .\StratoHiDriveUtils.psm1 -Force
$syncRoot = Get-HiDriveSyncRoot
if ($null -ne $syncRoot) {
	"Sync root: $syncRoot"
} else {
	"No sync root entry found in HiDrive logs."
}

Loads the module and reads the current HiDrive sync root from logs.

.NOTE
    Mail: dongrobione@proton.me
.VERSION
1.0
#>

Set-StrictMode -Version Latest

function Start-HiDrive {
	<#
	.SYNOPSIS
	Starts the STRATO HiDrive desktop application.

	.DESCRIPTION
	Checks common installation paths and starts HiDrive if the executable exists.
	Throws if no executable is found.
	#>
	[CmdletBinding()]
	param()

	$hiDrivePotentialPaths = @(
		(Join-Path $env:ProgramFiles 'STRATO\HiDrive\HiDrive.App.exe'),
		(Join-Path ${env:ProgramFiles(x86)} 'STRATO\HiDrive\HiDrive.App.exe'),
		(Join-Path $env:LocalAppData 'STRATO\HiDrive\HiDrive.App.exe')
	)

	$hiDrivePath = $hiDrivePotentialPaths |
		Where-Object { Test-Path -LiteralPath $_ } |
		Select-Object -First 1

	if (-not $hiDrivePath) {
		throw 'HiDrive.App.exe was not found in known installation paths.'
	}

	Start-Process -FilePath $hiDrivePath -ErrorAction Stop | Out-Null
}

function Stop-HiDrive {
	<#
	.SYNOPSIS
	Stops the STRATO HiDrive desktop application.

	.DESCRIPTION
	Requests shutdown for all running processes with HiDrive in the process name.
	In practice, HiDrive.App and HiDrive.Sync usually stop almost immediately.
	HiDrive UI processes may take longer to close after the close request.
	The function sends a graceful close request to all matching processes and returns immediately.
	#>
	[CmdletBinding()]
	param()

	$processes = Get-Process -Name '*HiDrive*' -ErrorAction SilentlyContinue
	if (-not $processes) {
		return
	}

	foreach ($process in $processes) {
		$null = $process.CloseMainWindow()
	}
}

function Get-HiDriveSyncRoot {
	<#
	.SYNOPSIS
	Returns the HiDrive sync root folder path.

	.DESCRIPTION
	Reads HiDrive logs and extracts the latest root folder path from
	"FileSystemSnapshot: Get file system snapshot started. Root ... |" entries.
	Returns $null if no matching log entry exists.

	.OUTPUTS
	System.String or $null
	#>
	[CmdletBinding()]
	param()

	$pattern = 'FileSystemSnapshot: Get file system snapshot started\. Root (?<Root>.+?)\s*\|'

	$logRoot = Join-Path $env:LOCALAPPDATA 'HiDrive\Logs'
	$currentLogPath = Join-Path $logRoot 'log.txt'
	if (Test-Path -LiteralPath $currentLogPath) {
		try {
			$match = Get-Content -LiteralPath $currentLogPath -ErrorAction Stop |
				Select-String -Pattern $pattern |
				Select-Object -Last 1

			if ($match) {
				return $match.Matches[0].Groups['Root'].Value.Trim()
			}
		}
		catch {
			# Continue with legacy fallback if the current log cannot be read.
		}
	}

	$dataRoot = Join-Path $env:LOCALAPPDATA 'HiDrive\Data'
	if (Test-Path -LiteralPath $dataRoot) {
		$candidateDirectories = Get-ChildItem -LiteralPath $dataRoot -Directory -Recurse -Force -ErrorAction SilentlyContinue |
			Where-Object { $_.Name -match '^\d+\.\d+$' } |
			Sort-Object LastWriteTime -Descending

		foreach ($directory in $candidateDirectories) {
			$syncLogPath = Join-Path $directory.FullName 'syncLog.txt'
			if (-not (Test-Path -LiteralPath $syncLogPath)) {
				continue
			}

			try {
				$match = Get-Content -LiteralPath $syncLogPath -ErrorAction Stop |
					Select-String -Pattern $pattern |
					Select-Object -Last 1

				if ($match) {
					return $match.Matches[0].Groups['Root'].Value.Trim()
				}
			}
			catch {
				continue
			}
		}
	}

	return $null
}

Export-ModuleMember -Function Start-HiDrive, Stop-HiDrive, Get-HiDriveSyncRoot
