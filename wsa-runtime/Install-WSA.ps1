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
    $buildNumber = [int]$currentBuild.CurrentBuildNumber
    $revision = [int]$currentBuild.UBR
    $edition = [string]$currentBuild.EditionID
    $displayVersion = [string]$currentBuild.DisplayVersion

    # ProductName may continue to say "Windows 10" on newer Windows 11 installs.
    # Use the OS build family for an accurate user-facing label.
    if ($buildNumber -ge 28000) {
        $windowsLabel = 'Windows 11 26H1'
    }
    elseif ($buildNumber -ge 26300) {
        $windowsLabel = 'Windows 11 26H2'
    }
    elseif ($buildNumber -ge 26200) {
        $windowsLabel = 'Windows 11 25H2'
    }
    elseif ($buildNumber -ge 26100) {
        $windowsLabel = 'Windows 11 24H2'
    }
    elseif ($buildNumber -ge 22631) {
        $windowsLabel = 'Windows 11 23H2'
    }
    elseif ($buildNumber -ge 22000) {
        $windowsLabel = 'Windows 11'
    }
    elseif ($buildNumber -ge 19045) {
        $windowsLabel = 'Windows 10 22H2'
    }
    else {
        $windowsLabel = [string]$currentBuild.ProductName
    }

    $versionSuffix = if ($displayVersion) { ", version $displayVersion" } else { '' }
    Write-Info ("Windows version: {0}{1}, build {2}.{3}; edition: {4}" -f $windowsLabel, $versionSuffix, $buildNumber, $revision, $edition)
    Write-Info "Native CPU architecture: $($Target.Architecture) (supported)"

    $systemDrive = [IO.Path]::GetPathRoot($env:SystemRoot)
    $driveInfo = New-Object System.IO.DriveInfo($systemDrive)

    if ($driveInfo.DriveFormat -ne 'NTFS') {
        throw "The Windows system drive ($systemDrive) uses $($driveInfo.DriveFormat). WSA requires NTFS. Free space alone will not fix this; do not convert or format the system drive as part of this setup."
    }
    Write-Info "System drive file system: NTFS (passed)"

    $freeSpaceGb = [math]::Round($driveInfo.AvailableFreeSpace / 1GB, 1)
    if ($driveInfo.AvailableFreeSpace -lt 10GB) {
        throw "WSA requires at least 10 GB free on the Windows system drive. Only $freeSpaceGb GB is available. Free disk space and run this setup again."
    }
    Write-Info "Free system-drive space: $freeSpaceGb GB (passed)"

    $computer = Get-CimInstance -ClassName Win32_ComputerSystem
    $memoryGb = [math]::Round($computer.TotalPhysicalMemory / 1GB, 1)
    if ($memoryGb -lt 8) {
        throw "This PC has $memoryGb GB RAM. The upstream WSA minimum is 8 GB. RAM cannot be added by this installer; upgrade the hardware or use a different PC."
    }
    Write-Info "Installed RAM: $memoryGb GB (passed; 8 GB minimum)"

    $processor = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    $firmwareVirtualizationEnabled = $processor.VirtualizationFirmwareEnabled
    $vmMonitorExtensions = $processor.VMMonitorModeExtensions
    $slatExtensions = $processor.SecondLevelAddressTranslationExtensions
    $hypervisorPresent = $computer.HypervisorPresent -eq $true

    Write-Info "Processor: $($processor.Name)"
    Write-Info ("Virtualization diagnostics: firmware flag={0}; VM monitor extensions={1}; SLAT={2}; Windows hypervisor active={3}" -f $firmwareVirtualizationEnabled, $vmMonitorExtensions, $slatExtensions, $hypervisorPresent)

    if ($hypervisorPresent) {
        # A running Windows hypervisor could not be active without hardware
        # virtualization. Prefer this live state over a possibly stale WMI flag.
        Write-Info 'Hardware virtualization: Windows hypervisor is already active (passed)'
    }
    elseif ($firmwareVirtualizationEnabled -eq $true) {
        Write-Info 'Hardware virtualization: enabled in firmware (passed)'
    }
    elseif ($firmwareVirtualizationEnabled -eq $false) {
        Write-WarningMessage 'The WMI firmware flag says virtualization is disabled. This can be inaccurate on some firmware/Windows combinations.'
        if (Read-Confirmation 'Open Task Manager > Performance > CPU. Does it show Virtualization: Enabled? Choose Y only when you can see Enabled.') {
            Write-Info 'Hardware virtualization manually confirmed as Enabled in Task Manager. Continuing with Windows feature checks.'
        }
        else {
            throw 'Hardware virtualization still appears to be disabled. Windows cannot safely switch Intel VT-x / AMD-V / SVM in BIOS/UEFI. Enable it using Settings > System > Recovery > Advanced startup > Restart now > Troubleshoot > Advanced options > UEFI Firmware Settings, then enable Intel Virtualization Technology (VT-x/VMX) or AMD SVM Mode and save changes. Do not change unrelated firmware settings.'
        }
    }
    else {
        Write-WarningMessage 'Windows could not read the firmware virtualization flag.'
        if (Read-Confirmation 'Open Task Manager > Performance > CPU. Does it show Virtualization: Enabled? Choose Y only when you can see Enabled.') {
            Write-Info 'Hardware virtualization manually confirmed as Enabled in Task Manager. Continuing with Windows feature checks.'
        }
        else {
            throw 'Could not confirm hardware virtualization. Check Task Manager > Performance > CPU; enable virtualization in BIOS/UEFI if it says Disabled.'
        }
    }

    try {
        $gpuNames = @(
            Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop |
                ForEach-Object { [string]$_.Name } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
        if ($gpuNames.Count -eq 0) {
            Write-WarningMessage 'Windows did not report a graphics adapter. WSA graphics compatibility could not be checked.'
        }
        else {
            Write-Info "Detected graphics adapter(s): $($gpuNames -join ', ')"
            if (($gpuNames -join ' ') -match '(?i)Intel.*HD Graphics 530') {
                Write-WarningMessage 'The upstream WSABuilds guide reports issues with Intel HD Graphics 530 and older. WSA may fail to start or show graphics problems on this adapter.'
            }
        }
    }
    catch {
        Write-WarningMessage "The graphics adapter could not be queried. This is not an automatic blocker, but WSA graphics compatibility is unverified. $($_.Exception.Message)"
    }

    $requiredFeatures = @('VirtualMachinePlatform', 'HypervisorPlatform')
    $missingFeatures = @()
    $restartRequired = $false

    foreach ($featureName in $requiredFeatures) {
        try {
            $feature = Get-WindowsOptionalFeature -Online -FeatureName $featureName -ErrorAction Stop
        }
        catch {
            throw "Could not inspect the required Windows feature '$featureName'. No feature changes were made. Run Windows Update and retry, or enable it manually from OptionalFeatures.exe. Details: $($_.Exception.Message)"
        }

        switch ([string]$feature.State) {
            'Enabled' {
                Write-Info ("Windows feature {0}: Enabled (passed)" -f $featureName)
            }
            'EnablePending' {
                Write-WarningMessage ("Windows feature {0} is enabled but waiting for a restart." -f $featureName)
                $restartRequired = $true
            }
            { $_ -in @('Disabled', 'DisabledWithPayloadRemoved') } {
                $missingFeatures += $featureName
                Write-WarningMessage ("Windows feature {0} is disabled; the helper will enable it automatically." -f $featureName)
            }
            default {
                throw "Windows feature '$featureName' has unexpected state '$($feature.State)'. No WSA installation was started."
            }
        }
    }

    if ($missingFeatures.Count -gt 0) {
        foreach ($featureName in $missingFeatures) {
            Write-Info ("Enabling Windows feature: {0}" -f $featureName)
            try {
                Enable-WindowsOptionalFeature -Online -FeatureName $featureName -All -NoRestart -ErrorAction Stop | Out-Null
            }
            catch {
                throw "Windows could not enable '$featureName'. Check Windows Update and available component-store files, then retry. You can also enable it from an elevated PowerShell window with: Enable-WindowsOptionalFeature -Online -FeatureName $featureName -All. Details: $($_.Exception.Message)"
            }

            $verifiedFeature = Get-WindowsOptionalFeature -Online -FeatureName $featureName -ErrorAction Stop
            if ($verifiedFeature.State -notin @('Enabled', 'EnablePending')) {
                throw "Windows did not confirm that '$featureName' was enabled (state: $($verifiedFeature.State)). WSA installation was stopped."
            }
            Write-Info ("Windows feature {0}: {1} (verified)" -f $featureName, $verifiedFeature.State)
        }

        $restartRequired = $true
    }

    if ($restartRequired) {
        Write-Host ''
        Write-WarningMessage 'Windows virtualization features are enabled or pending, but Windows must restart before WSA can be installed.'
        Write-Info 'Save your work and restart Windows. Then open Start > WSA PacMan > Install matching WSA Android runtime.'
        Write-Info 'The helper will re-check every requirement and continue with the matching runtime after restart.'
        exit 0
    }

    Write-Info 'Windows virtualization features: both enabled (passed)'
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
