Set-StrictMode -Version Latest

# Converts a message into an ErrorRecord that exported functions pass to $PSCmdlet.ThrowTerminatingError().
function ConvertTo-ErrorRecord {
	[CmdletBinding()]
	[OutputType([System.Management.Automation.ErrorRecord])]
	param(
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$Message,

		[Parameter(Mandatory = $true)]
		[ValidatePattern('^HiDrive[A-Za-z]+$')]
		[string]$ErrorId,

		[Parameter(Mandatory = $true)]
		[System.Management.Automation.ErrorCategory]$Category,

		[Parameter()]
		[object]$TargetObject
	)

	$exception = New-Object -TypeName System.InvalidOperationException -ArgumentList $Message
	New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception, $ErrorId, $Category, $TargetObject
}

function Start-HiDrive {
	<#
	.SYNOPSIS
	Starts the STRATO HiDrive desktop application.

	.DESCRIPTION
	Searches HiDrive.App.exe under %ProgramFiles%, %ProgramFiles(x86)%, and %LOCALAPPDATA% in the subfolder STRATO\HiDrive and starts the first match.
	Throws a terminating error with the ID HiDriveExecutableNotFound when the executable is not found in any of these paths.

	.EXAMPLE
	Start-HiDrive

	Starts the HiDrive desktop application.

	.EXAMPLE
	Start-HiDrive -WhatIf

	Shows which executable would be started without starting it.

	.INPUTS
	None. You cannot pipe objects to Start-HiDrive.

	.OUTPUTS
	None. Start-HiDrive does not return output.

	.LINK
	https://github.com/DonGrobione/StratoHiDriveUtils
	#>
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
		$PSCmdlet.ThrowTerminatingError((ConvertTo-ErrorRecord -Message 'HiDrive.App.exe was not found in known installation paths.' -ErrorId 'HiDriveExecutableNotFound' -Category ObjectNotFound -TargetObject $hiDrivePotentialPaths))
	}

	if ($PSCmdlet.ShouldProcess($hiDrivePath, 'Start HiDrive application')) {
		Start-Process -FilePath $hiDrivePath -ErrorAction Stop | Out-Null
	}
}

function Stop-HiDrive {
	<#
	.SYNOPSIS
	Stops all running STRATO HiDrive processes.

	.DESCRIPTION
	Sends a graceful close request to every process whose name matches *HiDrive* and has a main window, waits briefly, and then force-stops the remaining matching processes.
	Returns without error when no HiDrive process is running.
	Writes a non-terminating error with the ID HiDriveProcessStopFailed for each process that cannot be force-stopped and continues with the remaining processes.

	.EXAMPLE
	Stop-HiDrive

	Stops the HiDrive desktop application and its sync process.

	.EXAMPLE
	Stop-HiDrive -ErrorAction Stop

	Stops HiDrive and throws a terminating error if a process cannot be stopped.

	.INPUTS
	None. You cannot pipe objects to Stop-HiDrive.

	.OUTPUTS
	None. Stop-HiDrive does not return output.

	.LINK
	https://github.com/DonGrobione/StratoHiDriveUtils
	#>
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
				Write-Error -Message "Unable to force-stop process '$($process.ProcessName)' (PID $($process.Id)): $($_.Exception.Message)" -Exception $_.Exception -Category $_.CategoryInfo.Category -ErrorId 'HiDriveProcessStopFailed' -TargetObject $process
			}
		}
	}
}

function Get-HiDriveSyncRoot {
	<#
	.SYNOPSIS
	Gets the local sync root folder of the STRATO HiDrive desktop application.

	.DESCRIPTION
	Reads the sync root path from HiDrive log entries instead of the HiDrive SQLite database to stay dependency-free.
	Searches the application logs log.txt, log.0.txt, and so on under %LOCALAPPDATA%\HiDrive\Logs and the sync logs syncLog.txt, syncLog.0.txt, and so on in the numeric subfolders of %LOCALAPPDATA%\HiDrive\Data.
	Files are searched from the most recently written to the oldest, and the last matching entry of the first file with a match is returned.
	When no entry is found, writes a non-terminating error with the ID HiDriveSyncRootNotFound that names the searched folders and any unreadable log files, and returns no output.

	.EXAMPLE
	Get-HiDriveSyncRoot

	Returns the sync root path, for example C:\Users\<User>\HiDrive.

	.EXAMPLE
	try {
		$syncRoot = Get-HiDriveSyncRoot -ErrorAction Stop
	} catch {
		Write-Warning "Sync root lookup failed: $($_.Exception.Message)"
	}

	Reads the sync root and lets the calling script handle a failed lookup.

	.INPUTS
	None. You cannot pipe objects to Get-HiDriveSyncRoot.

	.OUTPUTS
	System.String. The sync root path.

	.LINK
	https://github.com/DonGrobione/StratoHiDriveUtils
	#>
	[CmdletBinding()]
	[OutputType([string])]
	param()

	$pattern = '(?:FileSystemSnapshot: Get file system snapshot started\. Root|FSW: started for root) (?<Root>.+?)\s*\|'
	$logFiles = @()
	$unreadableLogs = @()

	# Folders that cannot be listed yield no log files instead of extra error records.
	$logRoot = Join-Path $env:LOCALAPPDATA 'HiDrive\Logs'
	if (Test-Path -LiteralPath $logRoot -PathType Container) {
		$logFiles += @(Get-ChildItem -LiteralPath $logRoot -File -Force -ErrorAction Ignore |
			Where-Object { $_.Name -match '^log(\.\d+)?\.txt$' })
	}

	$dataRoot = Join-Path $env:LOCALAPPDATA 'HiDrive\Data'
	if (Test-Path -LiteralPath $dataRoot -PathType Container) {
		$syncLogDirectories = Get-ChildItem -LiteralPath $dataRoot -Directory -Recurse -Force -ErrorAction Ignore |
			Where-Object { $_.Name -match '^\d+\.\d+$' }

		foreach ($directory in $syncLogDirectories) {
			$logFiles += @(Get-ChildItem -LiteralPath $directory.FullName -File -Force -ErrorAction Ignore |
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
			$unreadableLogs += "'$($logFile.FullName)' ($($_.Exception.Message))"
		}
	}

	$message = "No HiDrive sync root entry was found in $($logFiles.Count) HiDrive log file(s) under '$logRoot' and '$dataRoot'."
	if ($unreadableLogs.Count -gt 0) {
		$message += " $($unreadableLogs.Count) log file(s) could not be read: $($unreadableLogs -join '; ')."
	}

	Write-Error -Message $message -Category ObjectNotFound -ErrorId 'HiDriveSyncRootNotFound' -TargetObject $env:LOCALAPPDATA
}

function Update-HiDriveUtility {
	<#
	.SYNOPSIS
	Updates DonGrobione.StratoHiDriveUtils to the latest GitHub release.

	.DESCRIPTION
	Checks the latest GitHub release and, when it is newer than the loaded version, installs it into its own version folder next to the existing versions in the active module folder, like Update-Module.
	An existing valid folder of the release version is reused and never overwritten; if the installation fails, only the new version folder is removed and the loaded version stays untouched.
	After a successful installation, older version folders and flat installation files without a version folder are removed, and newer version folders are kept.
	Old items that cannot be removed are returned in the FailedRemovals property and reported as a warning.
	The update is refused for Git working trees and when the module exists in more than one PSModulePath entry.
	Failures are terminating errors with IDs that start with HiDrive, for example HiDriveGitInstallation or HiDriveReleaseVersionMismatch.
	If the update fails because of a breaking change, reinstall the module with Install-StratoHiDriveUtils.ps1.

	.EXAMPLE
	Update-HiDriveUtility

	Installs the latest release after confirmation and removes older versions.

	.EXAMPLE
	Update-HiDriveUtility -WhatIf

	Reports whether an update is available without changing anything.

	.INPUTS
	None. You cannot pipe objects to Update-HiDriveUtility.

	.OUTPUTS
	System.Management.Automation.PSCustomObject. A status object with the properties Status (UpToDate, UpdateAvailable, or Updated), LocalVersion, RemoteVersion, and ModulePath; updated installations also contain RemovedItems, FailedRemovals, and ReloadRequired.

	.LINK
	https://github.com/DonGrobione/StratoHiDriveUtils
	#>
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
	[OutputType([pscustomobject])]
	param()

	$moduleName = $ExecutionContext.SessionState.Module.Name
	$modulePath = [System.IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\')
	$manifestPath = Join-Path $modulePath "$moduleName.psd1"
	if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
		$PSCmdlet.ThrowTerminatingError((ConvertTo-ErrorRecord -Message "The active module manifest was not found at '$manifestPath'." -ErrorId 'HiDriveModuleManifestNotFound' -Category ObjectNotFound -TargetObject $manifestPath))
	}

	# The module runs either from a versioned folder <ModuleBase>\<ModuleName>\<Version> or from a legacy flat folder <ModuleBase>\<ModuleName>.
	$moduleFolderName = Split-Path -Path $modulePath -Leaf
	$parsedVersion = $null
	if ($moduleFolderName -eq $moduleName) {
		$moduleRoot = $modulePath
	}
	elseif ([version]::TryParse($moduleFolderName, [ref]$parsedVersion) -and (Split-Path -Path (Split-Path -Path $modulePath -Parent) -Leaf) -eq $moduleName) {
		$moduleRoot = Split-Path -Path $modulePath -Parent
	}
	else {
		$PSCmdlet.ThrowTerminatingError((ConvertTo-ErrorRecord -Message "The active module path '$modulePath' is not a standard '$moduleName' installation path." -ErrorId 'HiDriveModulePathInvalid' -Category InvalidOperation -TargetObject $modulePath))
	}

	if ((Test-Path -LiteralPath (Join-Path $moduleRoot '.git')) -or (Test-Path -LiteralPath (Join-Path $modulePath '.git'))) {
		$PSCmdlet.ThrowTerminatingError((ConvertTo-ErrorRecord -Message "The active module path '$modulePath' is a Git installation. Replace it with the ZIP release by running the installer before using Update-HiDriveUtility." -ErrorId 'HiDriveGitInstallation' -Category InvalidOperation -TargetObject $modulePath))
	}

	$moduleBase = Split-Path -Path $moduleRoot -Parent
	$modulePathEntries = @($env:PSModulePath -split [System.IO.Path]::PathSeparator |
		Where-Object { $_ } |
		ForEach-Object { [System.IO.Path]::GetFullPath($_).TrimEnd('\') } |
		Sort-Object -Unique)
	if ($modulePathEntries -notcontains $moduleBase) {
		$PSCmdlet.ThrowTerminatingError((ConvertTo-ErrorRecord -Message "The active module path '$modulePath' is not located in the current PSModulePath." -ErrorId 'HiDriveModulePathNotInPSModulePath' -Category InvalidOperation -TargetObject $modulePath))
	}
	$moduleRoots = @($modulePathEntries |
		ForEach-Object { Join-Path $_ $moduleName } |
		Where-Object { Test-Path -LiteralPath $_ -PathType Container })
	if ($moduleRoots.Count -gt 1) {
		$PSCmdlet.ThrowTerminatingError((ConvertTo-ErrorRecord -Message "'$moduleName' is installed in multiple PSModulePath entries. Remove the duplicates before updating: $($moduleRoots -join '; ')" -ErrorId 'HiDriveDuplicateInstallation' -Category InvalidOperation -TargetObject $moduleRoots))
	}

	$localManifest = Import-PowerShellDataFile -LiteralPath $manifestPath
	$localVersion = [version]$localManifest.ModuleVersion
	$escapedModuleName = [regex]::Escape($moduleName)
	$temporaryRoot = $null

	try {
		$release = Invoke-RestMethod -Uri 'https://api.github.com/repos/DonGrobione/StratoHiDriveUtils/releases/latest' -Headers @{
			Accept = 'application/vnd.github+json'
			'User-Agent' = $moduleName
			'X-GitHub-Api-Version' = '2022-11-28'
		} -Method Get -ErrorAction Stop

		$releaseAsset = @($release.assets | Where-Object { $_.name -match "^$escapedModuleName-[0-9]+\.[0-9]+\.[0-9]+\.zip$" })
		if ($releaseAsset.Count -ne 1) {
			throw (ConvertTo-ErrorRecord -Message 'The latest GitHub release does not contain exactly one valid module ZIP asset.' -ErrorId 'HiDriveReleaseAssetInvalid' -Category InvalidData -TargetObject $release)
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

		# Like Install-Module, each version gets its own folder; an existing folder of the release version is reused if valid and never overwritten.
		$targetPath = Join-Path $moduleRoot $remoteVersion.ToString()
		$targetManifest = Join-Path $targetPath "$moduleName.psd1"
		$isAlreadyInstalled = $false
		if (Test-Path -LiteralPath $targetPath) {
			if (-not (Test-Path -LiteralPath $targetManifest -PathType Leaf) -or [version](Import-PowerShellDataFile -LiteralPath $targetManifest).ModuleVersion -ne $remoteVersion) {
				throw (ConvertTo-ErrorRecord -Message "The folder '$targetPath' exists but does not contain a valid $moduleName $remoteVersion installation. Remove it and run the update again." -ErrorId 'HiDriveVersionFolderInvalid' -Category InvalidData -TargetObject $targetPath)
			}
			$isAlreadyInstalled = $true
		}

		if (-not $PSCmdlet.ShouldProcess($targetPath, "Install $moduleName $remoteVersion from the GitHub ZIP release and remove older versions")) {
			return [pscustomobject]@{
				Status = 'UpdateAvailable'
				LocalVersion = $localVersion.ToString()
				RemoteVersion = $remoteVersion.ToString()
				ModulePath = $modulePath
			}
		}

		if (-not $isAlreadyInstalled) {
			$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) "$moduleName-update-$([guid]::NewGuid().ToString('N'))"
			$zipPath = Join-Path $temporaryRoot $releaseAsset[0].name
			New-Item -ItemType Directory -Path $temporaryRoot -Force -ErrorAction Stop | Out-Null
			Invoke-WebRequest -Uri $releaseAsset[0].browser_download_url -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
			$extractPath = Join-Path $temporaryRoot 'Extracted'
			Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force -ErrorAction Stop

			$packageManifest = @(Get-ChildItem -LiteralPath $extractPath -Filter "$moduleName.psd1" -File -Recurse -ErrorAction Stop)
			if ($packageManifest.Count -ne 1) {
				throw (ConvertTo-ErrorRecord -Message 'The downloaded ZIP does not contain exactly one valid module manifest.' -ErrorId 'HiDriveReleaseManifestInvalid' -Category InvalidData -TargetObject $zipPath)
			}
			$packageRoot = $packageManifest[0].Directory.FullName
			$packageData = Import-PowerShellDataFile -LiteralPath $packageManifest[0].FullName
			$packageVersion = [version]$packageData.ModuleVersion
			if ($packageVersion -ne $remoteVersion) {
				throw (ConvertTo-ErrorRecord -Message "The ZIP asset version $remoteVersion does not match the manifest version $packageVersion." -ErrorId 'HiDriveReleaseVersionMismatch' -Category InvalidData -TargetObject $zipPath)
			}

			# The version folder is created by this call, so on failure it is removed again and older versions stay untouched.
			New-Item -ItemType Directory -Path $targetPath -ErrorAction Stop | Out-Null
			try {
				Copy-Item -Path (Join-Path $packageRoot '*') -Destination $targetPath -Recurse -Force -ErrorAction Stop
			}
			catch {
				$installError = $_
				try {
					Remove-Item -LiteralPath $targetPath -Recurse -Force -ErrorAction Stop
				}
				catch {
					throw (ConvertTo-ErrorRecord -Message "Installing $moduleName $remoteVersion failed: $($installError.Exception.Message) The incomplete version folder '$targetPath' could not be removed: $($_.Exception.Message)" -ErrorId 'HiDriveIncompleteVersionFolder' -Category WriteError -TargetObject $targetPath)
				}
				throw $installError
			}
		}

		# Legacy flat installation files and version folders older than the release are removed; newer versions are kept.
		$removedItems = @()
		$failedRemovals = @()
		$oldItems = @(Get-ChildItem -LiteralPath $moduleRoot -Force -ErrorAction Stop | Where-Object {
			$itemVersion = $null
			(-not $_.PSIsContainer) -or
			([version]::TryParse($_.Name, [ref]$itemVersion) -and $itemVersion -lt $remoteVersion)
		})
		foreach ($oldItem in $oldItems) {
			try {
				Remove-Item -LiteralPath $oldItem.FullName -Recurse -Force -ErrorAction Stop
				$removedItems += $oldItem.FullName
			}
			catch {
				$failedRemovals += "'$($oldItem.FullName)' ($($_.Exception.Message))"
			}
		}
		if ($failedRemovals.Count -gt 0) {
			Write-Warning "$moduleName $remoteVersion was installed, but these old installation items could not be removed: $($failedRemovals -join '; ')"
		}

		return [pscustomobject]@{
			Status = 'Updated'
			LocalVersion = $localVersion.ToString()
			RemoteVersion = $remoteVersion.ToString()
			ModulePath = $targetPath
			RemovedItems = $removedItems
			FailedRemovals = $failedRemovals
			ReloadRequired = $true
		}
	}
	catch {
		$PSCmdlet.ThrowTerminatingError($_)
	}
	finally {
		if ($temporaryRoot -and (Test-Path -LiteralPath $temporaryRoot)) {
			try {
				Remove-Item -LiteralPath $temporaryRoot -Recurse -Force -ErrorAction Stop
			}
			catch {
				Write-Warning "The temporary folder '$temporaryRoot' could not be removed: $($_.Exception.Message)"
			}
		}
	}
}

Export-ModuleMember -Function Start-HiDrive, Stop-HiDrive, Get-HiDriveSyncRoot, Update-HiDriveUtility
