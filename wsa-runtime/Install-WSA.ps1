# Installs the current architecture-matched WSABuilds LTS package.
# The archive is downloaded directly from the upstream GitHub release and SHA-256
# checked before extraction. Existing WSA registrations are never removed/replaced.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Info([string]$Message) {
    Write-Host "[WSA PacMan] $Message" -ForegroundColor Cyan
}

function Write-WarningMessage([string]$Message) {
    Write-Host "[WSA PacMan] $Message" -ForegroundColor Yellow
}

function Read-Confirmation([string]$Message) {
    $answer = Read-Host "$Message [Y/N]"
    return ($answer -match '^(?i)y(es)?$')
}

function Ensure-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Info 'Administrator permission is required to register the Android subsystem.'
        $powershell = Join-Path $PSHOME 'powershell.exe'
        $arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '"'
        Start-Process -FilePath $powershell -ArgumentList $arguments -Verb RunAs | Out-Null
        exit 0
    }
}

function Get-NativeArchitecture {
    # IsWow64Process2 reports the actual host architecture even when this script
    # is running under x64 emulation on Windows 11 ARM64.
    if (-not ('WsaPacmanNativeMachine' -as [type])) {
        $nativeCode = @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

public static class WsaPacmanNativeMachine
{
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool IsWow64Process2(
        IntPtr process,
        out ushort processMachine,
        out ushort nativeMachine);

    [DllImport("kernel32.dll")]
    private static extern IntPtr GetCurrentProcess();

    public static ushort Get()
    {
        ushort processMachine;
        ushort nativeMachine;
        if (!IsWow64Process2(GetCurrentProcess(), out processMachine, out nativeMachine))
            throw new Win32Exception(Marshal.GetLastWin32Error());
        return nativeMachine == 0 ? processMachine : nativeMachine;
    }
}
'@
        Add-Type -TypeDefinition $nativeCode -ErrorAction Stop
    }

    try {
        $machine = [WsaPacmanNativeMachine]::Get()
        switch ($machine) {
            0x8664 { return 'x64' }
            0xAA64 { return 'arm64' }
            default { throw ('Unsupported native CPU architecture (machine code 0x{0:X4}).' -f $machine) }
        }
    }
    catch {
        # Older Windows builds may not expose IsWow64Process2. Fall back to WMI
        # and the architecture environment variables.
        $processor = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
        switch ([int]$processor.Architecture) {
            9  { return 'x64' }
            12 { return 'arm64' }
        }

        if ($env:PROCESSOR_ARCHITEW6432 -eq 'ARM64' -or $env:PROCESSOR_ARCHITECTURE -eq 'ARM64') {
            return 'arm64'
        }
        if ($env:PROCESSOR_ARCHITEW6432 -eq 'AMD64' -or $env:PROCESSOR_ARCHITECTURE -eq 'AMD64') {
            return 'x64'
        }
        throw 'Could not safely identify the native CPU architecture.'
    }
}

function Get-WindowsTarget {
    $versionKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $currentBuild = Get-ItemProperty -Path $versionKey
    $build = [int]$currentBuild.CurrentBuildNumber
    $revision = [int]$currentBuild.UBR
    $architecture = Get-NativeArchitecture

    if ($build -ge 22000) {
        if ($build -eq 22000 -and $revision -lt 526) {
            throw 'WSA requires Windows 11 build 22000.526 or later.'
        }
        if ($architecture -eq 'arm64') {
            return [pscustomobject]@{
                Architecture = $architecture
                OsFamily = 'Windows_11'
                TagPattern = '^Windows_11_.*_LTS_(?<lts>\d+)_arm64$'
                AssetPattern = 'NoGApps-NoAmazon\.7z$'
            }
        }
        return [pscustomobject]@{
            Architecture = $architecture
            OsFamily = 'Windows_11'
            TagPattern = '^Windows_11_.*_LTS_(?<lts>\d+)$'
            AssetPattern = 'NoGApps-NoAmazon\.7z$'
        }
    }

    if ($build -ge 19045) {
        if ($architecture -ne 'x64') {
            throw 'WSA community builds are not published for Windows 10 ARM64.'
        }
        if ($build -eq 19045 -and $revision -lt 2311) {
            throw 'WSA requires Windows 10 22H2 build 19045.2311 or later.'
        }
        return [pscustomobject]@{
            Architecture = $architecture
            OsFamily = 'Windows_10'
            TagPattern = '^Windows_10_.*_LTS_(?<lts>\d+)$'
            AssetPattern = 'NoGApps-NoAmazon_Windows_10\.7z$'
        }
    }

    throw 'This WSA setup supports Windows 11 build 22000.526+ and Windows 10 22H2 build 19045.2311+ only.'
}

function Get-ExistingWsaPackage {
    try {
        return @(
            Get-AppxPackage -AllUsers -ErrorAction Stop |
                Where-Object {
                    $_.Name -match 'WindowsSubsystemForAndroid' -or
                    $_.PackageFamilyName -match 'WindowsSubsystemForAndroid'
                }
        )
    }
    catch {
        throw "Could not safely check for an existing WSA installation. No changes were made. Details: $($_.Exception.Message)"
    }
}

function Confirm-WsaPrerequisites($Target) {
    $systemDrive = [IO.Path]::GetPathRoot($env:SystemRoot)
    $driveInfo = New-Object System.IO.DriveInfo($systemDrive)

    if ($driveInfo.DriveFormat -ne 'NTFS') {
        throw "The Windows system drive ($systemDrive) must use NTFS for WSA."
    }
    if ($driveInfo.AvailableFreeSpace -lt 10GB) {
        throw 'WSA requires at least 10 GB free on the Windows system drive. Free space and run this setup again.'
    }

    $computer = Get-CimInstance -ClassName Win32_ComputerSystem
    $memoryGb = [math]::Round($computer.TotalPhysicalMemory / 1GB, 1)
    if ($memoryGb -lt 8) {
        Write-WarningMessage "This PC reports $memoryGb GB RAM. The upstream WSA minimum is 8 GB; performance or installation may be unreliable."
        if (-not (Read-Confirmation 'Continue anyway?')) {
            exit 0
        }
    }

    $processor = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    if ($processor.VirtualizationFirmwareEnabled -eq $false) {
        if ($Target.Architecture -eq 'x64') {
            throw 'CPU virtualization is disabled in BIOS/UEFI. Enable Intel VT-x or AMD-V, restart Windows, then run this setup again.'
        }
        Write-WarningMessage 'Windows did not report the ARM64 firmware virtualization flag. The Windows hypervisor features will be checked next.'
    }

    $requiredFeatures = @('VirtualMachinePlatform', 'HypervisorPlatform')
    $missingFeatures = @()
    foreach ($featureName in $requiredFeatures) {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName $featureName -ErrorAction SilentlyContinue
        if ($null -eq $feature -or $feature.State -ne 'Enabled') {
            $missingFeatures += $featureName
        }
    }

    if ($missingFeatures.Count -gt 0) {
        Write-WarningMessage "Windows virtualization features need enabling: $($missingFeatures -join ', ')."
        if (Read-Confirmation 'Enable these Windows features now? A Windows restart will be required.') {
            foreach ($featureName in $missingFeatures) {
                Enable-WindowsOptionalFeature -Online -FeatureName $featureName -All -NoRestart | Out-Null
            }
            Write-Host ''
            Write-Info 'The Windows features have been enabled. Restart Windows, then run "Install matching WSA runtime" from the Start Menu.'
        }
        else {
            Write-Info 'No Windows features were changed.'
        }
        exit 0
    }
}

function Invoke-VerifiedDownload(
    [string]$Uri,
    [string]$Destination,
    [string]$Digest,
    [string]$Description
) {
    if ($Digest -notmatch '^sha256:([0-9a-fA-F]{64})$') {
        throw "The upstream release did not publish a SHA-256 digest for $Description. Refusing an unverifiable download."
    }

    $expectedDigest = $Matches[1].ToLowerInvariant()
    if (Test-Path -LiteralPath $Destination) {
        Remove-Item -LiteralPath $Destination -Force
    }

    Write-Info "Downloading $Description..."
    Invoke-WebRequest -UseBasicParsing -Uri $Uri -OutFile $Destination -Headers @{
        'User-Agent' = 'WSA-PacMan-Runtime-Setup'
        'Accept' = 'application/octet-stream'
    }

    if (-not (Test-Path -LiteralPath $Destination)) {
        throw "The download of $Description did not create a file."
    }

    $actualDigest = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualDigest -ne $expectedDigest) {
        Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
        throw "SHA-256 verification failed for $Description. The downloaded file was deleted."
    }
}

function Get-LatestMatchingWsaAsset($Target) {
    $headers = @{
        'User-Agent' = 'WSA-PacMan-Runtime-Setup'
        'Accept' = 'application/vnd.github+json'
    }
    $releases = Invoke-RestMethod -Method Get -Uri 'https://api.github.com/repos/MustardChef/WSABuilds/releases?per_page=100' -Headers $headers

    $candidates = @(
        foreach ($release in $releases) {
            $match = [regex]::Match([string]$release.tag_name, $Target.TagPattern)
            if (-not $release.draft -and -not $release.prerelease -and $match.Success) {
                [pscustomobject]@{
                    Release = $release
                    LtsNumber = [int]$match.Groups['lts'].Value
                }
            }
        }
    )

    $chosen = $candidates |
        Sort-Object @{ Expression = { $_.LtsNumber }; Descending = $true },
                    @{ Expression = { $_.Release.published_at }; Descending = $true } |
        Select-Object -First 1

    if ($null -eq $chosen) {
        throw "No published WSABuilds LTS package was found for $($Target.OsFamily) $($Target.Architecture)."
    }

    $asset = $chosen.Release.assets |
        Where-Object {
            $_.name -match $Target.AssetPattern -and
            $_.name -notmatch 'magisk'
        } |
        Sort-Object size |
        Select-Object -First 1

    if ($null -eq $asset) {
        throw "The latest WSABuilds LTS release ($($chosen.Release.tag_name)) has no matching NoGApps/NoAmazon package."
    }

    return [pscustomobject]@{
        Release = $chosen.Release
        Asset = $asset
    }
}

function Get-LatestSevenZipTool([string]$Destination) {
    $headers = @{
        'User-Agent' = 'WSA-PacMan-Runtime-Setup'
        'Accept' = 'application/vnd.github+json'
    }
    $release = Invoke-RestMethod -Method Get -Uri 'https://api.github.com/repos/ip7z/7zip/releases/latest' -Headers $headers
    $asset = $release.assets | Where-Object { $_.name -eq '7zr.exe' } | Select-Object -First 1
    if ($null -eq $asset) {
        throw 'Could not find the official 7-Zip standalone extractor.'
    }

    Invoke-VerifiedDownload -Uri $asset.browser_download_url -Destination $Destination -Digest $asset.digest -Description "7-Zip $($release.tag_name) extractor"
}

function Install-WsaFromFolder([string]$Folder) {
    $runBatch = Get-ChildItem -LiteralPath $Folder -Filter 'Run.bat' -File -Recurse |
        Select-Object -First 1
    if ($null -eq $runBatch) {
        throw "The extracted upstream package did not contain Run.bat. The files have been kept at $Folder for inspection."
    }

    $workingDirectory = $runBatch.DirectoryName
    Write-Host ''
    Write-Info "Starting the upstream WSA installer from $workingDirectory"
    Write-WarningMessage 'Do not close the installer window while WSA is being registered.'

    $argumentLine = '/d /c "' + $runBatch.FullName + '"'
    $process = Start-Process -FilePath $env:ComSpec -ArgumentList $argumentLine -WorkingDirectory $workingDirectory -Wait -PassThru

    if ($process.ExitCode -ne 0) {
        throw "The upstream WSA installer exited with code $($process.ExitCode). The extracted files were kept at $workingDirectory."
    }

    Start-Sleep -Seconds 3
    $registered = Get-ExistingWsaPackage
    if ($registered.Count -eq 0) {
        throw "The upstream installer finished, but Windows did not report a registered WSA package. The extracted files were kept at $workingDirectory."
    }

    return $registered
}

try {
    Ensure-Administrator
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    Write-Host ''
    Write-Info 'Architecture-aware Android runtime setup'
    Write-Host 'This downloads the current upstream WSABuilds LTS archive directly from GitHub.'
    Write-Host 'Default package: Android 13, no Google Play Services, no Amazon Appstore.'
    Write-Host ''

    $target = Get-WindowsTarget
    Write-Info "Detected Windows target: $($target.OsFamily), native CPU: $($target.Architecture)"

    $existingPackages = Get-ExistingWsaPackage
    if ($existingPackages.Count -gt 0) {
        $package = $existingPackages | Select-Object -First 1
        $installedArchitecture = [string]$package.Architecture
        Write-Host ''
        Write-Info "An existing WSA package is already registered: $($package.Name) ($installedArchitecture)."
        if (($target.Architecture -eq 'arm64' -and $installedArchitecture -match 'Arm64') -or
            ($target.Architecture -eq 'x64' -and $installedArchitecture -match 'X64')) {
            Write-Info 'It appears to match this PC. No WSA files or user data were changed.'
            Write-Host 'Open Windows Subsystem for Android Settings, enable Developer mode, then open WSA PacMan.'
        }
        else {
            Write-WarningMessage 'The registered WSA architecture does not match this PC. No uninstall or replacement was attempted.'
            Write-Host 'Back up Userdata.vhdx before any manual architecture change:'
            Write-Host "$env:LOCALAPPDATA\Packages\MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe\LocalCache\userdata.vhdx"
        }
        Read-Host 'Press Enter to close'
        exit 0
    }

    $previousUserData = Join-Path $env:LOCALAPPDATA 'Packages\MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe\LocalCache\userdata.vhdx'
    if (Test-Path -LiteralPath $previousUserData) {
        Write-WarningMessage 'A previous WSA Userdata.vhdx was found even though no WSA package is currently registered.'
        Write-Host "Possible Android app data is stored here: $previousUserData"
        Write-Host 'Copy this file to a safe backup location and move the original out of the WSA package folder before running a fresh install.'
        Write-Info 'No download, extraction, installation or deletion was performed.'
        Read-Host 'Press Enter to close'
        exit 0
    }

    Confirm-WsaPrerequisites -Target $target

    $computer = Get-CimInstance -ClassName Win32_ComputerSystem
    $memoryGb = [math]::Round($computer.TotalPhysicalMemory / 1GB, 1)
    $systemDrive = [IO.Path]::GetPathRoot($env:SystemRoot)
    $driveInfo = New-Object System.IO.DriveInfo($systemDrive)

    $assetInfo = Get-LatestMatchingWsaAsset -Target $target
    $release = $assetInfo.Release
    $asset = $assetInfo.Asset
    $archiveSizeGb = [math]::Round($asset.size / 1GB, 2)

    Write-Host ''
    Write-Info "Selected release: $($release.name)"
    Write-Info "Selected package: $($asset.name)"
    Write-Info "Compressed download: approximately $archiveSizeGb GB"
    Write-Info "Free space on $systemDrive $([math]::Round($driveInfo.AvailableFreeSpace / 1GB, 1)) GB"
    Write-Host ''
    Write-WarningMessage 'Microsoft ended official WSA support on 5 March 2025. This is an unofficial community build.'
    Write-WarningMessage 'The selected NoGApps package does not include Google Play Store or Google Play Services.'
    Write-Host 'The extracted WSA folder must remain on this PC after installation.'
    Write-Host ''

    if (-not (Read-Confirmation 'Download, verify, extract and install this matching WSA package now?')) {
        Write-Info 'Cancelled. Nothing was installed or replaced.'
        exit 0
    }

    $root = Join-Path $env:ProgramData 'WSABuilds'
    $installFolder = Join-Path $root ("WSA-" + $release.tag_name)
    $downloadsFolder = Join-Path $root 'Downloads'
    $toolsFolder = Join-Path $root 'Tools'
    New-Item -ItemType Directory -Path $root, $downloadsFolder, $toolsFolder -Force | Out-Null

    $runBatchAlreadyExtracted = Get-ChildItem -LiteralPath $installFolder -Filter 'Run.bat' -File -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($null -eq $runBatchAlreadyExtracted) {
        if (Test-Path -LiteralPath $installFolder) {
            if (-not (Read-Confirmation "A partial folder already exists at $installFolder. Remove that incomplete folder and download again?")) {
                Write-Info 'Cancelled. Existing files were left untouched.'
                exit 0
            }
            Remove-Item -LiteralPath $installFolder -Recurse -Force
        }
        New-Item -ItemType Directory -Path $installFolder -Force | Out-Null
    }
    else {
        Write-Info 'Found a previously extracted copy of this exact LTS release. It will be reused.'
    }

    if ($null -eq $runBatchAlreadyExtracted) {
        $sevenZipPath = Join-Path $toolsFolder '7zr.exe'
        Get-LatestSevenZipTool -Destination $sevenZipPath

        $archivePath = Join-Path $downloadsFolder $asset.name
        Invoke-VerifiedDownload -Uri $asset.browser_download_url -Destination $archivePath -Digest $asset.digest -Description $asset.name

        Write-Info 'Extracting the verified WSA archive. This can take several minutes.'
        & $sevenZipPath x $archivePath "-o$installFolder" -y
        if ($LASTEXITCODE -ne 0) {
            throw "7-Zip extraction failed with exit code $LASTEXITCODE. The download and partial files were left for inspection."
        }
    }

    $installedPackages = Install-WsaFromFolder -Folder $installFolder
    $registeredPackage = $installedPackages | Select-Object -First 1
    Write-Host ''
    Write-Info "WSA is registered: $($registeredPackage.Name)"
    Write-Info "The WSA files are stored at: $installFolder"
    Write-Info 'The WSA files must remain on this PC. Windows uses them to run WSA.'
    Write-Host 'Next: open Windows Subsystem for Android Settings, enable Developer mode, and then launch WSA PacMan.'

    if ($archivePath -and (Test-Path -LiteralPath $archivePath)) {
        Remove-Item -LiteralPath $archivePath -Force
    }

    Read-Host 'Press Enter to close'
}
catch {
    Write-Host ''
    Write-WarningMessage $_.Exception.Message
    Write-Host 'No existing WSA installation was automatically uninstalled or overwritten.'
    Read-Host 'Press Enter to close'
    exit 1
}
