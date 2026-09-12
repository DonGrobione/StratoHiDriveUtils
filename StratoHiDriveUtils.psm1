<#
.SYNOPSIS
PowerShell module to control STRATO HiDrive and read the configured sync root.

.DESCRIPTION
Provides functions to start and stop the HiDrive desktop app and to determine the current sync root folder from HiDrive log files.

.EXAMPLE
Import-Module .\StratoHiDriveUtils.psd1 -Force
Start-HiDrive
Loads the module from the current directory and starts HiDrive.

.EXAMPLE
Import-Module .\StratoHiDriveUtils.psd1 -Force
Stop-HiDrive
Loads the module and stops all running HiDrive processes.

.EXAMPLE
Import-Module .\StratoHiDriveUtils.psd1 -Force
Get-HiDriveSyncRoot
Returns the sync root path directly, for example:
Returns the sync root path directly, for example: C:\Users\<User>\HiDrive. If no entry is available in logs, the function returns $null.

.EXAMPLE
Import-Module .\StratoHiDriveUtils.psd1 -Force
$syncRoot = Get-HiDriveSyncRoot
if ($null -ne $syncRoot) {
	"Sync root: $syncRoot"
} else {
	"No sync root entry found in HiDrive logs."
}
Loads the module and reads the current HiDrive sync root from logs.
#>

Set-StrictMode -Version Latest

# Starts the STRATO HiDrive desktop application from a known installation path.
# Throws an error when the executable cannot be found.
function Start-HiDrive {
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
	[OutputType([void])]
	param()

	$installationRoots = @(
		$env:ProgramFiles
		${env:ProgramFiles(x86)}
		$env:LocalAppData
	) | Where-Object { $_ }

	$hiDrivePotentialPaths = foreach ($root in $installationRoots) {
		Join-Path $root 'STRATO\HiDrive\HiDrive.App.exe'
	}

	$hiDrivePath = $hiDrivePotentialPaths |
		Where-Object { Test-Path -LiteralPath $_ } |
		Select-Object -First 1

	if (-not $hiDrivePath) {
		throw 'HiDrive.App.exe was not found in known installation paths.'
	}

	if ($PSCmdlet.ShouldProcess($hiDrivePath, 'Start HiDrive application')) {
		Start-Process -FilePath $hiDrivePath -ErrorAction Stop | Out-Null
	}
}

# Stops all running STRATO HiDrive processes gracefully when possible and forcefully as a fallback.
function Stop-HiDrive {
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
	[OutputType([void])]
	param()

	$processes = Get-Process -Name '*HiDrive*' -ErrorAction SilentlyContinue
	if (-not $processes) {
		return
	}

	$gracefulProcesses = $processes | Where-Object { $_.MainWindowHandle -ne 0 }
	foreach ($process in $gracefulProcesses) {
		if ($PSCmdlet.ShouldProcess("$($process.ProcessName) (PID $($process.Id))", 'Request graceful shutdown')) {
			$null = $process.CloseMainWindow()
		}
	}

	if ($gracefulProcesses) {
		Start-Sleep -Milliseconds 1500
	}

	$remainingProcesses = Get-Process -Name '*HiDrive*' -ErrorAction SilentlyContinue
	if (-not $remainingProcesses) {
		return
	}

	foreach ($process in $remainingProcesses) {
		if ($PSCmdlet.ShouldProcess("$($process.ProcessName) (PID $($process.Id))", 'Force stop remaining process')) {
			Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
		}
	}
}

# Reads the latest HiDrive sync root path from the current or legacy log files.
# Returns null when no matching log entry is available.
function Get-HiDriveSyncRoot {
	[CmdletBinding()]
	[OutputType([string])]
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

# Checks origin/main and updates the module with a fast-forward-only Git pull.
# The update is allowed only for a clean working tree on the local main branch.
function Update-StratoHiDriveUtilsGit {
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
	[OutputType([pscustomobject])]
	param()

	$gitCommand = Get-Command git -CommandType Application -ErrorAction SilentlyContinue |
		Select-Object -First 1
	if (-not $gitCommand) {
		throw 'Git was not found. Install Git and ensure git.exe is available in PATH.'
	}

	$modulePath = $PSScriptRoot
	$gitOutput = & $gitCommand.Source -C $modulePath rev-parse --is-inside-work-tree 2>&1
	if ($LASTEXITCODE -ne 0 -or ($gitOutput -join '').Trim() -ne 'true') {
		throw 'The module is not installed from a Git working tree. ZIP installations cannot be updated with this command.'
	}

	$branch = (& $gitCommand.Source -C $modulePath rev-parse --abbrev-ref HEAD 2>&1 | Out-String).Trim()
	if ($LASTEXITCODE -ne 0) {
		throw 'Unable to determine the current Git branch.'
	}
	if ($branch -ne 'main') {
		if ($WhatIfPreference) {
			return [pscustomobject]@{
				Status = 'Skipped'
				Branch = $branch
				Reason = "The Git update is restricted to branch 'main'."
			}
		}

		throw "The Git update is restricted to branch 'main'. The current branch is '$branch'."
	}

	$status = @(& $gitCommand.Source -C $modulePath status --porcelain 2>&1)
	if ($LASTEXITCODE -ne 0) {
		throw 'Unable to inspect the Git working tree.'
	}
	if ($status.Count -gt 0) {
		throw 'The Git working tree contains local changes. Commit or stash them before updating.'
	}

	$fetchOutput = & $gitCommand.Source -C $modulePath fetch origin main 2>&1
	if ($LASTEXITCODE -ne 0) {
		throw "Git could not fetch origin/main: $($fetchOutput -join ' ')"
	}

	$localCommit = (& $gitCommand.Source -C $modulePath rev-parse HEAD 2>&1 | Out-String).Trim()
	$remoteCommit = (& $gitCommand.Source -C $modulePath rev-parse origin/main 2>&1 | Out-String).Trim()
	if ($LASTEXITCODE -ne 0) {
		throw 'Unable to compare the local branch with origin/main.'
	}

	if ($localCommit -eq $remoteCommit) {
		return [pscustomobject]@{
			Status = 'UpToDate'
			Branch = $branch
			LocalCommit = $localCommit
			RemoteCommit = $remoteCommit
		}
	}

	$ancestorCheck = & $gitCommand.Source -C $modulePath merge-base --is-ancestor HEAD origin/main 2>&1
	if ($LASTEXITCODE -ne 0) {
		throw 'The local main branch cannot be fast-forwarded to origin/main. Resolve the branch history manually.'
	}

	if ($PSCmdlet.ShouldProcess($modulePath, 'Update from origin/main with git pull --ff-only')) {
		$pullOutput = & $gitCommand.Source -C $modulePath pull --ff-only origin main 2>&1
		if ($LASTEXITCODE -ne 0) {
			throw "Git could not update the module: $($pullOutput -join ' ')"
		}

		$newCommit = (& $gitCommand.Source -C $modulePath rev-parse HEAD 2>&1 | Out-String).Trim()
		return [pscustomobject]@{
			Status = 'Updated'
			Branch = $branch
			LocalCommit = $newCommit
			RemoteCommit = $remoteCommit
			ReloadRequired = $true
		}
	}

	return [pscustomobject]@{
		Status = 'UpdateAvailable'
		Branch = $branch
		LocalCommit = $localCommit
		RemoteCommit = $remoteCommit
	}
}

Export-ModuleMember -Function Start-HiDrive, Stop-HiDrive, Get-HiDriveSyncRoot, Update-StratoHiDriveUtilsGit
