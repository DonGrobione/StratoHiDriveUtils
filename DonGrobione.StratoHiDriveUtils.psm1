<#
.SYNOPSIS
PowerShell module to control STRATO HiDrive and read the configured sync root.

.DESCRIPTION
Provides functions to start and stop the HiDrive desktop app and to determine the current sync root folder from HiDrive log files.

.EXAMPLE
Import-Module .\DonGrobione.StratoHiDriveUtils.psd1 -Force
Start-HiDrive
Loads the module from the current directory and starts HiDrive.

.EXAMPLE
Import-Module .\DonGrobione.StratoHiDriveUtils.psd1 -Force
Stop-HiDrive
Loads the module and stops all running HiDrive processes.

.EXAMPLE
Import-Module .\DonGrobione.StratoHiDriveUtils.psd1 -Force
Get-HiDriveSyncRoot
Returns the sync root path directly, for example: C:\Users\<User>\HiDrive.
If no entry is available in logs, the function returns $null.

.EXAMPLE
Import-Module .\DonGrobione.StratoHiDriveUtils.psd1 -Force
$syncRoot = Get-HiDriveSyncRoot
if ($null -ne $syncRoot) {
	"Sync root: $syncRoot"
} else {
	"No sync root entry found in HiDrive logs."
}
Loads the module and reads the current HiDrive sync root from logs.
#>

Set-StrictMode -Version Latest

# Starts the STRATO HiDrive desktop application from a known installation path and throws an error if not found.
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
			try {
				Stop-Process -Id $process.Id -Force -ErrorAction Stop
			}
			catch {
				Write-Verbose "Unable to force-stop process '$($process.ProcessName)' (PID $($process.Id))."
			}
		}
	}
}

# Reads the latest HiDrive sync root path from the application and sync log files, including rotated ones, newest file first.
# Returns null when no matching log entry is available.
function Get-HiDriveSyncRoot {
	[CmdletBinding()]
	[OutputType([string])]
	param()

	$pattern = '(?:FileSystemSnapshot: Get file system snapshot started\. Root|FSW: started for root) (?<Root>.+?)\s*\|'
	$logFiles = @()

	$logRoot = Join-Path $env:LOCALAPPDATA 'HiDrive\Logs'
	if (Test-Path -LiteralPath $logRoot -PathType Container) {
		$logFiles += @(Get-ChildItem -LiteralPath $logRoot -File -Force -ErrorAction SilentlyContinue |
			Where-Object { $_.Name -match '^log(\.\d+)?\.txt$' })
	}

	$dataRoot = Join-Path $env:LOCALAPPDATA 'HiDrive\Data'
	if (Test-Path -LiteralPath $dataRoot -PathType Container) {
		$syncLogDirectories = Get-ChildItem -LiteralPath $dataRoot -Directory -Recurse -Force -ErrorAction SilentlyContinue |
			Where-Object { $_.Name -match '^\d+\.\d+$' }

		foreach ($directory in $syncLogDirectories) {
			$logFiles += @(Get-ChildItem -LiteralPath $directory.FullName -File -Force -ErrorAction SilentlyContinue |
				Where-Object { $_.Name -match '^syncLog(\.\d+)?\.txt$' })
		}
	}

	foreach ($logFile in ($logFiles | Sort-Object LastWriteTime -Descending)) {
		try {
			$match = Select-String -LiteralPath $logFile.FullName -Pattern $pattern -ErrorAction Stop |
				Select-Object -Last 1

			if ($match) {
				return $match.Matches[0].Groups['Root'].Value.Trim()
			}
		}
		catch {
			Write-Verbose "Unable to read the HiDrive log at '$($logFile.FullName)'. Continuing with the next log."
		}
	}

	return $null
}

# Downloads and installs the latest GitHub ZIP release into the active module path.
# The update is blocked when multiple installations exist in the current PSModulePath.
function Update-StratoHiDriveUtils {
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
	[OutputType([pscustomobject])]
	param()

	$moduleName = $ExecutionContext.SessionState.Module.Name
	$modulePath = [System.IO.Path]::GetFullPath($PSScriptRoot)
	$manifestPath = Join-Path $modulePath "$moduleName.psd1"
	if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
		throw "The active module manifest was not found at '$manifestPath'."
	}
	$gitMetadataPath = Join-Path $modulePath '.git'
	if (Test-Path -LiteralPath $gitMetadataPath) {
		throw "The active module path '$modulePath' is a Git installation. Replace it with the ZIP release before using Update-StratoHiDriveUtils."
	}

	$modulePathEntries = @($env:PSModulePath -split [System.IO.Path]::PathSeparator | Where-Object { $_ })
	$moduleCandidates = foreach ($modulePathEntry in $modulePathEntries) {
		$candidatePath = Join-Path $modulePathEntry $moduleName
		$candidateManifest = Join-Path $candidatePath "$moduleName.psd1"
		if (Test-Path -LiteralPath $candidateManifest -PathType Leaf) {
			[System.IO.Path]::GetFullPath($candidatePath)
		}
	}
	$moduleCandidates = @($moduleCandidates | Sort-Object -Unique)
	if ($moduleCandidates.Count -eq 0 -or $moduleCandidates -notcontains $modulePath) {
		throw "The active module path '$modulePath' is not a standard installation path in the current PSModulePath."
	}
	if ($moduleCandidates.Count -gt 1) {
		throw "Multiple '$moduleName' installations were found in the current PSModulePath. Remove duplicates before updating: $($moduleCandidates -join '; ')"
	}

	$localManifest = Import-PowerShellDataFile -LiteralPath $manifestPath
	$localVersion = [version]$localManifest.ModuleVersion
	$escapedModuleName = [regex]::Escape($moduleName)
	$temporaryRoot = $null
	$backupPath = $null

	try {
		$release = Invoke-RestMethod -Uri 'https://api.github.com/repos/DonGrobione/StratoHiDriveUtils/releases/latest' -Headers @{
			Accept = 'application/vnd.github+json'
			'User-Agent' = $moduleName
			'X-GitHub-Api-Version' = '2022-11-28'
		} -Method Get -ErrorAction Stop

		$releaseAsset = @($release.assets | Where-Object { $_.name -match "^$escapedModuleName-[0-9]+\.[0-9]+\.[0-9]+\.zip$" })
		if ($releaseAsset.Count -ne 1) {
			throw 'The latest GitHub release does not contain exactly one valid module ZIP asset.'
		}

		$remoteVersion = [version]($releaseAsset[0].name -replace "^$escapedModuleName-|\.zip$")
		if ($remoteVersion -le $localVersion) {
			return [pscustomobject]@{
				Status = 'UpToDate'
				LocalVersion = $localVersion.ToString()
				RemoteVersion = $remoteVersion.ToString()
				ModulePath = $modulePath
			}
		}

		if (-not $PSCmdlet.ShouldProcess($modulePath, "Install $moduleName $remoteVersion from the GitHub ZIP release")) {
			return [pscustomobject]@{
				Status = 'UpdateAvailable'
				LocalVersion = $localVersion.ToString()
				RemoteVersion = $remoteVersion.ToString()
				ModulePath = $modulePath
			}
		}

		$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) "$moduleName-update-$([guid]::NewGuid().ToString('N'))"
		$backupPath = Join-Path ([System.IO.Path]::GetTempPath()) "$moduleName-backup-$([guid]::NewGuid().ToString('N'))"
		$zipPath = Join-Path $temporaryRoot $releaseAsset[0].name
		New-Item -ItemType Directory -Path $temporaryRoot -Force -ErrorAction Stop | Out-Null
		Invoke-WebRequest -Uri $releaseAsset[0].browser_download_url -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
		$extractPath = Join-Path $temporaryRoot 'Extracted'
		Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force -ErrorAction Stop

		$packageManifest = @(Get-ChildItem -LiteralPath $extractPath -Filter "$moduleName.psd1" -File -Recurse -ErrorAction Stop)
		if ($packageManifest.Count -ne 1) {
			throw 'The downloaded ZIP does not contain exactly one valid module manifest.'
		}
		$packageRoot = $packageManifest[0].Directory.FullName
		$packageData = Import-PowerShellDataFile -LiteralPath $packageManifest[0].FullName
		$packageVersion = [version]$packageData.ModuleVersion
		if ($packageVersion -ne $remoteVersion) {
			throw "The ZIP asset version $remoteVersion does not match the manifest version $packageVersion."
		}

		Copy-Item -LiteralPath $modulePath -Destination $backupPath -Recurse -Force -ErrorAction Stop
		try {
			Get-ChildItem -LiteralPath $modulePath -Force | Remove-Item -Recurse -Force -ErrorAction Stop
			$packageFiles = Get-ChildItem -LiteralPath $packageRoot -File -Recurse -ErrorAction Stop
			foreach ($packageFile in $packageFiles) {
				$relativePath = $packageFile.FullName.Substring($packageRoot.Length).TrimStart('\', '/')
				$destinationPath = Join-Path $modulePath $relativePath
				$destinationDirectory = Split-Path -Path $destinationPath -Parent
				New-Item -ItemType Directory -Path $destinationDirectory -Force -ErrorAction Stop | Out-Null
				Copy-Item -LiteralPath $packageFile.FullName -Destination $destinationPath -Force -ErrorAction Stop
			}
		}
		catch {
			Get-ChildItem -LiteralPath $modulePath -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
			Copy-Item -Path (Join-Path $backupPath '*') -Destination $modulePath -Recurse -Force -ErrorAction Stop
			throw
		}

		return [pscustomobject]@{
			Status = 'Updated'
			LocalVersion = $localVersion.ToString()
			RemoteVersion = $remoteVersion.ToString()
			ModulePath = $modulePath
			ReloadRequired = $true
		}
	}
	finally {
		if ($temporaryRoot) {
			Remove-Item -LiteralPath $temporaryRoot -Recurse -Force -ErrorAction SilentlyContinue
		}
		if ($backupPath) {
			Remove-Item -LiteralPath $backupPath -Recurse -Force -ErrorAction SilentlyContinue
		}
	}
}

Export-ModuleMember -Function Start-HiDrive, Stop-HiDrive, Get-HiDriveSyncRoot, Update-StratoHiDriveUtils
