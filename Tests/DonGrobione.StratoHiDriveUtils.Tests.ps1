<#
.SYNOPSIS
Pester tests for the DonGrobione.StratoHiDriveUtils module.

.DESCRIPTION
Validates the module manifest, the release packaging, the project documents, code quality, comment-based help, and the behavior of every exported function.
All file system changes happen in the Pester TestDrive, and GitHub calls are replaced by mocks that serve a release ZIP built from the working tree.
Requires Windows PowerShell 5.1, Pester 5, and PSScriptAnalyzer.

.EXAMPLE
Invoke-Pester -Path .\Tests -Output Detailed

Runs all tests from the repository root.
#>

#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables between discovery, setup, and test blocks.')]
param()

Set-StrictMode -Version Latest

BeforeDiscovery {
	$repositoryRoot = Split-Path -Path $PSScriptRoot -Parent
	$manifestData = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'DonGrobione.StratoHiDriveUtils.psd1')
	$exportedFunctionNames = @($manifestData.FunctionsToExport | ForEach-Object { @{ Name = $_ } })
	$scriptFileNames = @($manifestData.FileList | Where-Object { $_ -match '\.psm?1$' } | ForEach-Object { @{ Name = $_ } })
	$parsedFileNames = @($scriptFileNames) + @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1' -File | ForEach-Object { @{ Name = "Tests\$($_.Name)" } })
}

BeforeAll {
	. (Join-Path $PSScriptRoot 'TestHelpers.ps1')
	$script:releaseZip = Join-Path $TestDrive 'release.zip'
	New-TestReleaseZip -Path $script:releaseZip -ManifestVersion $script:releaseVersion.ToString()
	$script:mismatchedReleaseZip = Join-Path $TestDrive 'mismatched.zip'
	New-TestReleaseZip -Path $script:mismatchedReleaseZip -ManifestVersion ([version]::new($script:releaseVersion.Major, $script:releaseVersion.Minor + 1, 0)).ToString()
}

Describe 'Module manifest' {
	It 'passes Test-ModuleManifest' {
		{ Test-ModuleManifest -Path $script:manifestPath -ErrorAction Stop } | Should -Not -Throw
	}

	It 'uses a three-part semantic version in the line format the release workflow reads' {
		$script:manifestData.ModuleVersion | Should -Match '^\d+\.\d+\.\d+$'
		Get-Content -LiteralPath $script:manifestPath | Where-Object { $_ -match "^\s*ModuleVersion = '\d+\.\d+\.\d+'" } | Should -HaveCount 1
	}

	It 'targets Windows PowerShell 5.1 Desktop' {
		$script:manifestData.PowerShellVersion | Should -Be '5.1'
		$script:manifestData.CompatiblePSEditions | Should -Be @('Desktop')
	}

	It 'contains the PowerShell Gallery metadata' {
		$script:manifestData.Author | Should -Be 'DonGrobione'
		foreach ($key in 'Author', 'CompanyName', 'Copyright', 'Description', 'GUID') {
			$script:manifestData[$key] | Should -Not -BeNullOrEmpty -Because "$key is required"
		}
		$script:manifestData.Copyright | Should -Match 'AGPL-3\.0'
		$psData = $script:manifestData.PrivateData.PSData
		foreach ($key in 'Tags', 'ProjectUri', 'LicenseUri', 'ReleaseNotes') {
			$psData[$key] | Should -Not -BeNullOrEmpty -Because "PSData.$key is required"
		}
		$psData.Tags | Should -Contain 'Windows'
		$psData.Tags | Should -Contain 'PSEdition_Desktop'
		@($psData.Tags | Where-Object { $_ -match '\s' }) | Should -BeNullOrEmpty
		$psData.ProjectUri | Should -Be 'https://github.com/DonGrobione/StratoHiDriveUtils'
		$psData.LicenseUri | Should -Be "$($psData.ProjectUri)/blob/main/LICENSE"
		$psData.ReleaseNotes | Should -Match "^$([regex]::Escape($script:releaseVersion.ToString())):"
	}

	It 'exports exactly the functions listed in FunctionsToExport and nothing else' {
		$script:manifestData.CmdletsToExport | Should -BeNullOrEmpty
		$script:manifestData.VariablesToExport | Should -BeNullOrEmpty
		$script:manifestData.AliasesToExport | Should -BeNullOrEmpty
		@($script:manifestData.FunctionsToExport | Where-Object { $_ -match '\*' }) | Should -BeNullOrEmpty

		Import-Module -Name $script:manifestPath -Force
		$exportedCommands = @(Get-Command -Module $script:moduleName | Select-Object -ExpandProperty Name | Sort-Object)
		$exportedCommands | Should -Be @($script:manifestData.FunctionsToExport | Sort-Object)
		$moduleSource = Get-Content -LiteralPath (Join-Path $script:repositoryRoot "$script:moduleName.psm1") -Raw
		$exportLine = [regex]::Match($moduleSource, 'Export-ModuleMember -Function (?<Names>.+)').Groups['Names'].Value
		@($exportLine -split ',' | ForEach-Object { $_.Trim() } | Sort-Object) | Should -Be $exportedCommands
	}

	It 'lists exactly the files that the release workflow ships in FileList, including the installer' {
		@($script:manifestData.FileList | Sort-Object) | Should -Be (Get-ShippedFile)
		$script:manifestData.FileList | Should -Contain 'Install-StratoHiDriveUtils.ps1'
	}

	It 'states the manifest version in README.md' {
		Get-Content -LiteralPath (Join-Path $script:repositoryRoot 'README.md') -Raw |
			Should -Match ([regex]::Escape("Current manifest version: ``$script:releaseVersion``"))
	}
}

Describe 'Project documents' {
	It 'has README.md, LICENSE, and CHANGELOG.md at the project root' {
		foreach ($document in 'README.md', 'LICENSE', 'CHANGELOG.md') {
			Join-Path $script:repositoryRoot $document | Should -Exist
		}
		Get-Content -LiteralPath (Join-Path $script:repositoryRoot 'LICENSE') -TotalCount 1 | Should -Match 'GNU AFFERO GENERAL PUBLIC LICENSE'
	}

	It 'documents the manifest version as the newest entry in CHANGELOG.md' {
		$versionHeadings = @(Get-Content -LiteralPath (Join-Path $script:repositoryRoot 'CHANGELOG.md') | Where-Object { $_ -match '^## \[' })
		$versionHeadings[0] | Should -Match "^## \[$([regex]::Escape($script:releaseVersion.ToString()))\] - \d{4}-\d{2}-\d{2}$"
	}

	It 'contains no email address in any shipped file' {
		$emailPattern = '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
		foreach ($file in (Get-ShippedFile)) {
			Select-String -LiteralPath (Join-Path $script:repositoryRoot $file) -Pattern $emailPattern | Should -BeNullOrEmpty -Because "$file must not contain an email address"
		}
	}
}

Describe 'Code quality' {
	It '<Name> parses without errors' -ForEach $parsedFileNames {
		$parseErrors = $null
		[void][System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:repositoryRoot $Name), [ref]$null, [ref]$parseErrors)
		$parseErrors | Should -BeNullOrEmpty
	}

	It 'has no PSScriptAnalyzer findings in the shipped PowerShell files' {
		Import-Module -Name PSScriptAnalyzer -ErrorAction Stop
		$findings = foreach ($file in @($script:manifestData.FileList | Where-Object { $_ -match '\.ps(m|d)?1$' })) {
			Invoke-ScriptAnalyzer -Path (Join-Path $script:repositoryRoot $file)
		}
		@($findings | ForEach-Object { "$($_.ScriptName):$($_.Line) $($_.RuleName)" }) | Should -BeNullOrEmpty
	}

	It '<Name> has its own test file' -ForEach $scriptFileNames {
		Join-Path $PSScriptRoot "$([System.IO.Path]::GetFileNameWithoutExtension($Name)).Tests.ps1" | Should -Exist
	}

	It 'reports terminating errors of exported functions through ThrowTerminatingError' {
		$moduleAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:repositoryRoot "$script:moduleName.psm1"), [ref]$null, [ref]$null)
		foreach ($functionName in $script:manifestData.FunctionsToExport) {
			$functionAst = $moduleAst.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $functionName }, $false)
			# A throw is allowed only inside a try statement whose catch passes the error to ThrowTerminatingError.
			$throwsOutsideTry = @($functionAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.ThrowStatementAst] }, $true) | Where-Object {
				$parent = $_.Parent
				while ($parent -ne $functionAst -and $parent -isnot [System.Management.Automation.Language.TryStatementAst]) {
					$parent = $parent.Parent
				}
				$parent -eq $functionAst
			})
			$throwsOutsideTry | Should -BeNullOrEmpty -Because "$functionName must report terminating errors through ThrowTerminatingError"
		}
	}
}

Describe 'Comment-based help of <Name>' -ForEach $exportedFunctionNames {
	BeforeAll {
		Import-Module -Name $script:manifestPath -Force
		$help = Get-Help -Name $Name -Full
	}

	It 'has a synopsis' {
		$help.Synopsis | Should -Not -BeNullOrEmpty
		$help.Synopsis | Should -Not -Match "^\s*$([regex]::Escape($Name))\s*(\[|$)" -Because 'an auto-generated synopsis means the help block is missing'
	}

	It 'has a description' {
		($help.Description | Out-String).Trim() | Should -Not -BeNullOrEmpty
	}

	It 'has at least one example' {
		@($help.Examples.Example).Count | Should -BeGreaterThan 0
	}

	It 'links to the project page' {
		@($help.RelatedLinks.NavigationLink.Uri) | Should -Contain $script:projectUri
	}
}

Describe 'Get-HiDriveSyncRoot' {
	BeforeAll {
		Import-Module -Name $script:manifestPath -Force
		$script:originalLocalAppData = $env:LOCALAPPDATA
	}

	BeforeEach {
		$env:LOCALAPPDATA = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
		$logRoot = Join-Path $env:LOCALAPPDATA 'HiDrive\Logs'
		$syncLogRoot = Join-Path $env:LOCALAPPDATA 'HiDrive\Data\52794237.1'
	}

	AfterEach {
		$env:LOCALAPPDATA = $script:originalLocalAppData
	}

	It 'writes the HiDriveSyncRootNotFound error and returns no output when no log exists' {
		$result = Get-HiDriveSyncRoot -ErrorAction SilentlyContinue -ErrorVariable lookupErrors
		$result | Should -BeNullOrEmpty
		@($lookupErrors | Where-Object { $_.FullyQualifiedErrorId -like 'HiDriveSyncRootNotFound*' }) | Should -HaveCount 1
		{ Get-HiDriveSyncRoot -ErrorAction Stop } | Should -Throw -ErrorId 'HiDriveSyncRootNotFound,Get-HiDriveSyncRoot'
	}

	It 'reads the snapshot entry from the HiDrive 6.5 application log' {
		New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
		Set-Content -LiteralPath (Join-Path $logRoot 'log.txt') -Value 'INFO FileSystemSnapshot: Get file system snapshot started. Root C:\Users\Test\HiDrive | details'
		Get-HiDriveSyncRoot | Should -Be 'C:\Users\Test\HiDrive'
	}

	It 'reads the watcher entry from the HiDrive 7 sync log' {
		New-Item -ItemType Directory -Path $syncLogRoot -Force | Out-Null
		Set-Content -LiteralPath (Join-Path $syncLogRoot 'syncLog.txt') -Value 'INFO FSW: started for root D:\HiDrive | details'
		Get-HiDriveSyncRoot | Should -Be 'D:\HiDrive'
	}

	It 'searches rotated logs when the current log has no entry' {
		New-Item -ItemType Directory -Path $syncLogRoot -Force | Out-Null
		Set-Content -LiteralPath (Join-Path $syncLogRoot 'syncLog.txt') -Value 'INFO unrelated entry'
		Set-Content -LiteralPath (Join-Path $syncLogRoot 'syncLog.0.txt') -Value 'INFO FSW: started for root E:\Rotated |'
		(Get-Item -LiteralPath (Join-Path $syncLogRoot 'syncLog.0.txt')).LastWriteTime = (Get-Date).AddHours(-1)
		Get-HiDriveSyncRoot | Should -Be 'E:\Rotated'
	}

	It 'prefers the most recently written log and its last entry' {
		New-Item -ItemType Directory -Path $logRoot, $syncLogRoot -Force | Out-Null
		Set-Content -LiteralPath (Join-Path $logRoot 'log.txt') -Value 'FileSystemSnapshot: Get file system snapshot started. Root C:\Old |'
		(Get-Item -LiteralPath (Join-Path $logRoot 'log.txt')).LastWriteTime = (Get-Date).AddDays(-1)
		Set-Content -LiteralPath (Join-Path $syncLogRoot 'syncLog.txt') -Value @('FSW: started for root D:\Earlier |', 'FSW: started for root D:\Latest |')
		Get-HiDriveSyncRoot | Should -Be 'D:\Latest'
	}

	It 'names unreadable log files in the error message' {
		New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
		$lockedLog = Join-Path $logRoot 'log.txt'
		Set-Content -LiteralPath $lockedLog -Value 'locked'
		$lock = [System.IO.File]::Open($lockedLog, 'Open', 'ReadWrite', 'None')
		try {
			{ Get-HiDriveSyncRoot -ErrorAction Stop } | Should -Throw -ExpectedMessage '*could not be read*log.txt*'
		}
		finally {
			$lock.Dispose()
		}
	}
}

Describe 'Start-HiDrive' {
	BeforeAll {
		Import-Module -Name $script:manifestPath -Force
		$script:originalEnvironment = @{}
		foreach ($variableName in 'ProgramFiles', 'ProgramFiles(x86)', 'LOCALAPPDATA') {
			$script:originalEnvironment[$variableName] = [Environment]::GetEnvironmentVariable($variableName, 'Process')
		}
	}

	BeforeEach {
		$sandbox = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
		foreach ($variableName in 'ProgramFiles', 'ProgramFiles(x86)', 'LOCALAPPDATA') {
			[Environment]::SetEnvironmentVariable($variableName, (Join-Path $sandbox $variableName), 'Process')
		}
		Mock -CommandName Start-Process -ModuleName $script:moduleName -MockWith { }
	}

	AfterEach {
		foreach ($variableName in $script:originalEnvironment.Keys) {
			[Environment]::SetEnvironmentVariable($variableName, $script:originalEnvironment[$variableName], 'Process')
		}
	}

	It 'throws when HiDrive.App.exe is not installed' {
		{ Start-HiDrive } | Should -Throw -ExpectedMessage '*HiDrive.App.exe was not found*' -ErrorId 'HiDriveExecutableNotFound,Start-HiDrive'
		Should -Invoke -CommandName Start-Process -ModuleName $script:moduleName -Times 0 -Exactly
	}

	It 'starts HiDrive.App.exe from the first known installation path' {
		$executable = Join-Path $env:LOCALAPPDATA 'STRATO\HiDrive\HiDrive.App.exe'
		New-Item -ItemType File -Path $executable -Force | Out-Null
		Start-HiDrive
		Should -Invoke -CommandName Start-Process -ModuleName $script:moduleName -Times 1 -Exactly -ParameterFilter { $FilePath -eq $executable }
	}

	It 'does not start anything with -WhatIf' {
		New-Item -ItemType File -Path (Join-Path $env:ProgramFiles 'STRATO\HiDrive\HiDrive.App.exe') -Force | Out-Null
		Start-HiDrive -WhatIf
		Should -Invoke -CommandName Start-Process -ModuleName $script:moduleName -Times 0 -Exactly
	}
}

Describe 'Stop-HiDrive' {
	BeforeAll {
		Import-Module -Name $script:manifestPath -Force
	}

	BeforeEach {
		Mock -CommandName Start-Sleep -ModuleName $script:moduleName -MockWith { }
		Mock -CommandName Stop-Process -ModuleName $script:moduleName -MockWith { }
	}

	It 'returns without error when no HiDrive process is running' {
		Mock -CommandName Get-Process -ModuleName $script:moduleName -MockWith { }
		{ Stop-HiDrive -ErrorAction Stop } | Should -Not -Throw
		Should -Invoke -CommandName Stop-Process -ModuleName $script:moduleName -Times 0 -Exactly
	}

	It 'closes windowed processes gracefully without forcing them' {
		$script:closeRequests = 0
		$script:getProcessCalls = 0
		Mock -CommandName Get-Process -ModuleName $script:moduleName -MockWith {
			$script:getProcessCalls++
			if ($script:getProcessCalls -eq 1) {
				$process = [pscustomobject]@{ ProcessName = 'HiDrive.App'; Id = 101; MainWindowHandle = 1 }
				$process | Add-Member -MemberType ScriptMethod -Name CloseMainWindow -Value { $script:closeRequests++; $true }
				$process
			}
		}
		Stop-HiDrive
		$script:closeRequests | Should -Be 1
		Should -Invoke -CommandName Stop-Process -ModuleName $script:moduleName -Times 0 -Exactly
	}

	It 'force-stops remaining processes' {
		Mock -CommandName Get-Process -ModuleName $script:moduleName -MockWith { [pscustomobject]@{ ProcessName = 'HiDrive.Sync'; Id = 202; MainWindowHandle = 0 } }
		Stop-HiDrive
		Should -Invoke -CommandName Stop-Process -ModuleName $script:moduleName -Times 1 -Exactly -ParameterFilter { $Id -eq 202 -and $Force }
	}

	It 'writes the HiDriveProcessStopFailed error for a process that cannot be stopped' {
		Mock -CommandName Get-Process -ModuleName $script:moduleName -MockWith { [pscustomobject]@{ ProcessName = 'HiDrive.Sync'; Id = 303; MainWindowHandle = 0 } }
		Mock -CommandName Stop-Process -ModuleName $script:moduleName -MockWith { throw 'Access is denied.' }
		Stop-HiDrive -ErrorAction SilentlyContinue -ErrorVariable stopErrors
		# The ErrorVariable also collects the exception of the internally caught Stop-Process failure, which is not an ErrorRecord.
		@($stopErrors | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] -and $_.FullyQualifiedErrorId -like 'HiDriveProcessStopFailed*' }) | Should -HaveCount 1
	}
}

Describe 'Update-HiDriveUtility' {
	BeforeAll {
		$script:originalModulePath = $env:PSModulePath
		$script:olderVersion = '0.9.0'
		$script:oldestVersion = '0.8.0'
		$script:newerVersion = '99.0.0'
	}

	BeforeEach {
		$moduleBase = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
		$moduleRoot = Join-Path $moduleBase $script:moduleName
		$targetPath = Join-Path $moduleRoot $script:releaseVersion.ToString()
		$env:PSModulePath = $moduleBase
		$script:servedZip = $script:releaseZip

		# Imports an installed test copy and redirects its GitHub calls to the local release ZIP.
		function Import-TestInstallation {
			param([string]$Path)

			Get-Module -Name $script:moduleName | Remove-Module -Force
			Import-Module -Name (Join-Path $Path "$script:moduleName.psd1") -Force
			Mock -CommandName Invoke-RestMethod -ModuleName $script:moduleName -MockWith { Get-TestRelease }
			Mock -CommandName Invoke-WebRequest -ModuleName $script:moduleName -MockWith { Copy-Item -LiteralPath $script:servedZip -Destination $OutFile }
		}
	}

	AfterEach {
		Get-Module -Name $script:moduleName | Remove-Module -Force
		$env:PSModulePath = $script:originalModulePath
	}

	It 'migrates a flat installation into a version folder and removes older versions but keeps newer ones' {
		New-TestInstallation -Path $moduleRoot -Version $script:olderVersion
		New-TestInstallation -Path (Join-Path $moduleRoot $script:oldestVersion) -Version $script:oldestVersion
		New-TestInstallation -Path (Join-Path $moduleRoot $script:newerVersion) -Version $script:newerVersion
		Import-TestInstallation -Path $moduleRoot

		$result = Update-HiDriveUtility -Confirm:$false

		$result.Status | Should -Be 'Updated'
		$result.ModulePath | Should -Be $targetPath
		$result.FailedRemovals | Should -BeNullOrEmpty
		Join-Path $targetPath "$script:moduleName.psd1" | Should -Exist
		Join-Path $targetPath 'Install-StratoHiDriveUtils.ps1' | Should -Exist
		@(Get-ChildItem -LiteralPath $moduleRoot -File -Force) | Should -BeNullOrEmpty
		Join-Path $moduleRoot $script:oldestVersion | Should -Not -Exist
		Join-Path $moduleRoot $script:newerVersion | Should -Exist
		@(Get-ChildItem -LiteralPath $moduleRoot -Directory -Force | Where-Object { $_.Name -notmatch '^\d+\.\d+\.\d+$' }) | Should -BeNullOrEmpty
	}

	It 'replaces an older version folder' {
		New-TestInstallation -Path (Join-Path $moduleRoot $script:olderVersion) -Version $script:olderVersion
		Import-TestInstallation -Path (Join-Path $moduleRoot $script:olderVersion)

		(Update-HiDriveUtility -Confirm:$false).Status | Should -Be 'Updated'

		Join-Path $targetPath "$script:moduleName.psd1" | Should -Exist
		Join-Path $moduleRoot $script:olderVersion | Should -Not -Exist
	}

	It 'reports an available update without changes when -WhatIf is used' {
		New-TestInstallation -Path (Join-Path $moduleRoot $script:olderVersion) -Version $script:olderVersion
		Import-TestInstallation -Path (Join-Path $moduleRoot $script:olderVersion)

		(Update-HiDriveUtility -WhatIf).Status | Should -Be 'UpdateAvailable'

		$targetPath | Should -Not -Exist
		Should -Invoke -CommandName Invoke-WebRequest -ModuleName $script:moduleName -Times 0 -Exactly
	}

	It 'reports UpToDate when the loaded version is the latest release' {
		New-TestInstallation -Path $targetPath -Version $script:releaseVersion.ToString()
		Import-TestInstallation -Path $targetPath

		(Update-HiDriveUtility -Confirm:$false).Status | Should -Be 'UpToDate'
	}

	It 'throws and leaves the installed version untouched when the ZIP manifest version does not match' {
		New-TestInstallation -Path (Join-Path $moduleRoot $script:olderVersion) -Version $script:olderVersion
		Import-TestInstallation -Path (Join-Path $moduleRoot $script:olderVersion)
		$script:servedZip = $script:mismatchedReleaseZip

		{ Update-HiDriveUtility -Confirm:$false } | Should -Throw -ExpectedMessage '*does not match the manifest version*' -ErrorId 'HiDriveReleaseVersionMismatch,Update-HiDriveUtility'

		Join-Path $moduleRoot "$script:olderVersion\$script:moduleName.psd1" | Should -Exist
		$targetPath | Should -Not -Exist
	}

	It 'reuses a valid existing folder of the release version without overwriting it' {
		New-TestInstallation -Path (Join-Path $moduleRoot $script:olderVersion) -Version $script:olderVersion
		New-TestInstallation -Path $targetPath -Version $script:releaseVersion.ToString()
		Set-Content -LiteralPath (Join-Path $targetPath 'marker.txt') -Value 'keep'
		Import-TestInstallation -Path (Join-Path $moduleRoot $script:olderVersion)

		(Update-HiDriveUtility -Confirm:$false).Status | Should -Be 'Updated'

		Join-Path $targetPath 'marker.txt' | Should -Exist
		Join-Path $moduleRoot $script:olderVersion | Should -Not -Exist
		Should -Invoke -CommandName Invoke-WebRequest -ModuleName $script:moduleName -Times 0 -Exactly
	}

	It 'refuses to use an invalid existing folder of the release version' {
		New-TestInstallation -Path (Join-Path $moduleRoot $script:olderVersion) -Version $script:olderVersion
		New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
		Set-Content -LiteralPath (Join-Path $targetPath 'foreign.txt') -Value 'foreign'
		Import-TestInstallation -Path (Join-Path $moduleRoot $script:olderVersion)

		{ Update-HiDriveUtility -Confirm:$false } | Should -Throw -ExpectedMessage '*does not contain a valid*' -ErrorId 'HiDriveVersionFolderInvalid,Update-HiDriveUtility'

		Join-Path $targetPath 'foreign.txt' | Should -Exist
		Join-Path $moduleRoot $script:olderVersion | Should -Exist
	}

	It 'refuses to update a Git working tree' {
		New-TestInstallation -Path $moduleRoot -Version $script:olderVersion
		New-Item -ItemType Directory -Path (Join-Path $moduleRoot '.git') | Out-Null
		Import-TestInstallation -Path $moduleRoot

		{ Update-HiDriveUtility -Confirm:$false } | Should -Throw -ExpectedMessage '*is a Git installation*' -ErrorId 'HiDriveGitInstallation,Update-HiDriveUtility'
	}

	It 'throws HiDriveReleaseAssetInvalid when the release has no module ZIP asset' {
		New-TestInstallation -Path (Join-Path $moduleRoot $script:olderVersion) -Version $script:olderVersion
		Import-TestInstallation -Path (Join-Path $moduleRoot $script:olderVersion)
		Mock -CommandName Invoke-RestMethod -ModuleName $script:moduleName -MockWith { [pscustomobject]@{ assets = @() } }

		{ Update-HiDriveUtility -Confirm:$false } | Should -Throw -ErrorId 'HiDriveReleaseAssetInvalid,Update-HiDriveUtility'

		$targetPath | Should -Not -Exist
	}

	It 'refuses to update when the module exists in more than one PSModulePath entry' {
		New-TestInstallation -Path (Join-Path $moduleRoot $script:olderVersion) -Version $script:olderVersion
		$secondBase = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
		New-TestInstallation -Path (Join-Path $secondBase "$script:moduleName\$script:olderVersion") -Version $script:olderVersion
		$env:PSModulePath = "$moduleBase;$secondBase"
		Import-TestInstallation -Path (Join-Path $moduleRoot $script:olderVersion)

		{ Update-HiDriveUtility -Confirm:$false } | Should -Throw -ExpectedMessage '*multiple PSModulePath entries*' -ErrorId 'HiDriveDuplicateInstallation,Update-HiDriveUtility'
	}

	It 'reports old versions that cannot be removed without failing the update' {
		$olderPath = Join-Path $moduleRoot $script:olderVersion
		New-TestInstallation -Path $olderPath -Version $script:olderVersion
		Import-TestInstallation -Path $olderPath
		$lock = [System.IO.File]::Open((Join-Path $olderPath 'LICENSE'), 'Open', 'Read', 'None')
		try {
			$result = Update-HiDriveUtility -Confirm:$false -WarningAction SilentlyContinue -WarningVariable updateWarnings
		}
		finally {
			$lock.Dispose()
		}

		$result.Status | Should -Be 'Updated'
		@($result.FailedRemovals) | Should -HaveCount 1
		@($updateWarnings) | Should -HaveCount 1
		Join-Path $targetPath "$script:moduleName.psd1" | Should -Exist
	}
}
