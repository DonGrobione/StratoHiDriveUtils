<#
.SYNOPSIS
Installs or updates DonGrobione.StratoHiDriveUtils from the latest GitHub ZIP release.

.DESCRIPTION
Checks the latest GitHub release, detects existing module installations in the current Windows PowerShell 5.1 PSModulePath, and installs the release as a versioned module folder in the current user's Windows PowerShell module directory, for example Modules\DonGrobione.StratoHiDriveUtils\<version>.
Each version is installed into its own folder like Install-Module; an existing valid folder of the current version is reused and never overwritten.
After a successful installation, older versions, flat installations without a version folder, Git working trees, and installations under the legacy module name StratoHiDriveUtils are removed.
Old installations that cannot be removed are reported as warnings.

.PARAMETER Force
Suppresses the confirmation prompt for replacing an existing installation.

.EXAMPLE
.\Install-StratoHiDriveUtils.ps1 -Force

Installs or updates DonGrobione.StratoHiDriveUtils without prompting.

.INPUTS
None. You cannot pipe objects to this script.

.OUTPUTS
System.String. A message that describes the installation result.

.NOTES
This script ships in the release ZIP and is versioned by the module manifest.
README.md contains the one-line command that downloads and runs it via Invoke-RestMethod and Invoke-Expression.
Rerun it to repair an installation or when Update-HiDriveUtility cannot update across a breaking change.

.LINK
https://github.com/DonGrobione/StratoHiDriveUtils
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
	[switch]$Force
)

Set-StrictMode -Version Latest

$moduleName = 'DonGrobione.StratoHiDriveUtils'
$legacyModuleName = 'StratoHiDriveUtils'
$escapedModuleName = [regex]::Escape($moduleName)
$repositoryName = 'DonGrobione/StratoHiDriveUtils'
$temporaryRoot = $null

try {
	$release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repositoryName/releases/latest" -Headers @{
		Accept = 'application/vnd.github+json'
		'User-Agent' = $moduleName
		'X-GitHub-Api-Version' = '2022-11-28'
	} -Method Get -ErrorAction Stop

	$releaseAssets = @($release.assets | Where-Object { $_.name -match "^$escapedModuleName-[0-9]+\.[0-9]+\.[0-9]+\.zip$" })
	if ($releaseAssets.Count -ne 1) {
		throw 'The latest GitHub release does not contain exactly one valid module ZIP asset.'
	}

	$releaseVersion = [version]($releaseAssets[0].name -replace "^$escapedModuleName-|\.zip$")
	$pathEntries = @($env:PSModulePath -split [System.IO.Path]::PathSeparator |
		Where-Object { $_ } |
		ForEach-Object { [System.IO.Path]::GetFullPath($_).TrimEnd('\') } |
		Sort-Object -Unique)

	# Installations are either flat (<ModuleBase>\<Name>\<Name>.psd1) or versioned (<ModuleBase>\<Name>\<Version>\<Name>.psd1).
	$moduleCandidates = @(foreach ($pathEntry in $pathEntries) {
		foreach ($candidateName in @($moduleName, $legacyModuleName)) {
			$candidateRoot = Join-Path $pathEntry $candidateName
			if (-not (Test-Path -LiteralPath $candidateRoot -PathType Container)) {
				continue
			}

			$rootIsGit = Test-Path -LiteralPath (Join-Path $candidateRoot '.git')
			$flatManifest = Join-Path $candidateRoot "$candidateName.psd1"
			if (Test-Path -LiteralPath $flatManifest -PathType Leaf) {
				[pscustomobject]@{
					Path = $candidateRoot
					Root = $candidateRoot
					Version = [version](Import-PowerShellDataFile -LiteralPath $flatManifest).ModuleVersion
					IsGit = $rootIsGit
					IsLegacy = $candidateName -eq $legacyModuleName
					IsVersioned = $false
				}
			}

			foreach ($versionFolder in @(Get-ChildItem -LiteralPath $candidateRoot -Directory -Force -ErrorAction Stop)) {
				$folderVersion = $null
				$versionManifest = Join-Path $versionFolder.FullName "$candidateName.psd1"
				if ([version]::TryParse($versionFolder.Name, [ref]$folderVersion) -and (Test-Path -LiteralPath $versionManifest -PathType Leaf)) {
					[pscustomobject]@{
						Path = $versionFolder.FullName
						Root = $candidateRoot
						Version = [version](Import-PowerShellDataFile -LiteralPath $versionManifest).ModuleVersion
						IsGit = $rootIsGit -or (Test-Path -LiteralPath (Join-Path $versionFolder.FullName '.git'))
						IsLegacy = $candidateName -eq $legacyModuleName
						IsVersioned = $true
					}
				}
			}
		}
	})

	$validCurrentInstallations = @($moduleCandidates | Where-Object { $_.Version -eq $releaseVersion -and $_.IsVersioned -and -not $_.IsGit -and -not $_.IsLegacy })
	if ($moduleCandidates.Count -eq 1 -and $validCurrentInstallations.Count -eq 1) {
		Write-Output "$moduleName $releaseVersion is already installed at '$($validCurrentInstallations[0].Path)'. No changes were made."
		return
	}

	$userDocuments = [Environment]::GetFolderPath('MyDocuments')
	if ([string]::IsNullOrWhiteSpace($userDocuments)) {
		$userDocuments = Join-Path $HOME 'Documents'
	}
	$userModuleBase = [System.IO.Path]::GetFullPath((Join-Path $userDocuments 'WindowsPowerShell\Modules')).TrimEnd('\')
	if ($pathEntries -notcontains $userModuleBase) {
		throw "The target module directory '$userModuleBase' is not part of the current PSModulePath."
	}
	$targetRoot = Join-Path $userModuleBase $moduleName
	$targetPath = Join-Path $targetRoot $releaseVersion.ToString()

	# Like Install-Module, each version gets its own folder; an existing folder of the release version is reused if valid and never overwritten.
	$isAlreadyInstalled = @($moduleCandidates | Where-Object { $_.Path -eq $targetPath -and $_.Version -eq $releaseVersion }).Count -gt 0
	if (-not $isAlreadyInstalled -and (Test-Path -LiteralPath $targetPath)) {
		throw "The folder '$targetPath' exists but does not contain a valid $moduleName $releaseVersion installation. Remove it and run the installer again."
	}

	$action = "Install release $releaseVersion at '$targetPath' and remove older $moduleName and $legacyModuleName installations"
	# Under irm | iex, $PSCmdlet does not exist and parameters keep their defaults, so the installer runs without a confirmation prompt there.
	$shouldInstall = $false
	$cmdletValue = Get-Variable -Name PSCmdlet -ValueOnly -ErrorAction Ignore
	if ($WhatIfPreference) {
		$shouldInstall = $false
	} elseif ($Force) {
		$shouldInstall = $true
	} elseif ($null -ne $cmdletValue -and $cmdletValue.ShouldProcess($targetPath, $action)) {
		$shouldInstall = $true
	} elseif ($null -eq $cmdletValue) {
		$shouldInstall = $true
	}
	if (-not $shouldInstall) {
		Write-Output "$moduleName $releaseVersion is available. No changes were made."
		return
	}

	if (-not $isAlreadyInstalled) {
		$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) "$moduleName-installer-$([guid]::NewGuid().ToString('N'))"
		$zipPath = Join-Path $temporaryRoot $releaseAssets[0].name
		$extractPath = Join-Path $temporaryRoot 'Extracted'
		New-Item -ItemType Directory -Path $temporaryRoot -Force -ErrorAction Stop | Out-Null
		Invoke-WebRequest -Uri $releaseAssets[0].browser_download_url -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
		Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force -ErrorAction Stop

		$packageManifests = @(Get-ChildItem -LiteralPath $extractPath -Filter "$moduleName.psd1" -File -Recurse -ErrorAction Stop)
		if ($packageManifests.Count -ne 1) {
			throw 'The downloaded ZIP does not contain exactly one valid module manifest.'
		}
		$packageRoot = $packageManifests[0].Directory.FullName
		$packageData = Import-PowerShellDataFile -LiteralPath $packageManifests[0].FullName
		$packageVersion = [version]$packageData.ModuleVersion
		if ($packageVersion -ne $releaseVersion) {
			throw "The ZIP asset version $releaseVersion does not match the manifest version $packageVersion."
		}

		# The version folder is created by this run, so on failure it is removed again and existing installations stay untouched.
		New-Item -ItemType Directory -Path $targetRoot -Force -ErrorAction Stop | Out-Null
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
				throw "Installing $moduleName $releaseVersion failed: $($installError.Exception.Message) The incomplete version folder '$targetPath' could not be removed: $($_.Exception.Message)"
			}
			throw $installError
		}
	}

	# Old installations are removed only after the new version is installed; versioned folders are removed as a whole, flat installations lose everything except version folders.
	Get-Module -Name $moduleName, $legacyModuleName | Remove-Module -Force -ErrorAction SilentlyContinue
	$failedRemovals = @()
	foreach ($candidate in @($moduleCandidates | Where-Object { $_.Path -ne $targetPath })) {
		if ($candidate.IsVersioned) {
			$oldItems = @(Get-Item -LiteralPath $candidate.Path -Force -ErrorAction Stop)
		}
		else {
			$oldItems = @(Get-ChildItem -LiteralPath $candidate.Root -Force -ErrorAction Stop | Where-Object {
				$itemVersion = $null
				-not ($_.PSIsContainer -and [version]::TryParse($_.Name, [ref]$itemVersion))
			})
		}

		foreach ($oldItem in $oldItems) {
			try {
				Remove-Item -LiteralPath $oldItem.FullName -Recurse -Force -ErrorAction Stop
			}
			catch {
				$failedRemovals += "'$($oldItem.FullName)' ($($_.Exception.Message))"
			}
		}
	}

	foreach ($oldRoot in @($moduleCandidates | Where-Object { $_.Root -ne $targetRoot } | Select-Object -ExpandProperty Root -Unique)) {
		if ((Test-Path -LiteralPath $oldRoot -PathType Container) -and -not (Get-ChildItem -LiteralPath $oldRoot -Force -ErrorAction Stop)) {
			try {
				Remove-Item -LiteralPath $oldRoot -Force -ErrorAction Stop
			}
			catch {
				$failedRemovals += "'$oldRoot' ($($_.Exception.Message))"
			}
		}
	}

	if ($failedRemovals.Count -gt 0) {
		Write-Warning "$moduleName $releaseVersion was installed, but these old installation items could not be removed: $($failedRemovals -join '; ')"
	}
	Write-Output "$moduleName $releaseVersion was installed at '$targetPath'. Start a new Windows PowerShell session or import the module again."
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
