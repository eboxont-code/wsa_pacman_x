# Installs the current architecture-matched WSABuilds LTS package.
# The archive is downloaded directly from the upstream GitHub release and SHA-256
# checked before extraction. Existing WSA registrations are never removed/replaced.

param(
    [switch]$ResumeAfterRestart
)

$script:ResumeTaskName = 'WSA PacMan - Resume Android Runtime Setup'
$script:TranscriptStarted = $false

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Info([string]$Message) {
    Write-Host "[WSA PacMan] $Message" -ForegroundColor Cyan
}

function Write-WarningMessage([string]$Message) {
    Write-Host "[WSA PacMan] $Message" -ForegroundColor Yellow
}

function Read-Confirmation([string]$Message) {
    # Keep the helper console-free. Only hardware-virtualization ambiguity
    # requires a human choice; present that choice as a normal Windows dialog.
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $result = [System.Windows.Forms.MessageBox]::Show(
            $Message,
            'WSA PacMan prerequisite check',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        return ($result -eq [System.Windows.Forms.DialogResult]::Yes)
    }
    catch {
        Write-WarningMessage "Could not display the prerequisite confirmation dialog. Setup will stop safely. $($_.Exception.Message)"
        return $false
    }
}

function Ensure-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Info 'Administrator permission is required to register the Android subsystem.'
        $powershell = Join-Path $PSHOME 'powershell.exe'
        $arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '"'
        if ($ResumeAfterRestart) {
            $arguments += ' -ResumeAfterRestart'
        }
        try {
            $elevatedProcess = Start-Process -FilePath $powershell -ArgumentList $arguments -Verb RunAs -WindowStyle Hidden -Wait -PassThru
            if ($null -eq $elevatedProcess -or $elevatedProcess.ExitCode -ne 0) {
                Write-WarningMessage 'The elevated WSA runtime setup did not complete successfully.'
                exit 1
            }
            exit 0
        }
        catch {
            Write-WarningMessage "Could not complete the elevated WSA runtime setup. $($_.Exception.Message)"
            exit 1
        }
    }
}

function Remove-WsaResumeTask {
    try {
        $task = Get-ScheduledTask -TaskName $script:ResumeTaskName -ErrorAction SilentlyContinue
        if ($null -ne $task) {
            Unregister-ScheduledTask -InputObject $task -Confirm:$false -ErrorAction Stop
            Write-Info 'Removed the one-time automatic continuation task.'
        }
    }
    catch {
        Write-WarningMessage "Could not remove the automatic continuation task cleanly: $($_.Exception.Message)"
    }
}

function Register-WsaResumeTask {
    # Run at this user's next interactive sign-in, elevated, so the runtime
    # installation can continue without requiring another Start-menu click.
    $userId = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $powershell = Join-Path $PSHOME 'powershell.exe'
    $scriptPath = '"' + $PSCommandPath + '"'
    $arguments = '-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File ' + $scriptPath + ' -ResumeAfterRestart'

    try {
        $action = New-ScheduledTaskAction -Execute $powershell -Argument $arguments -WorkingDirectory (Split-Path -Parent $PSCommandPath)
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $userId
        $principal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 12) -MultipleInstances IgnoreNew
        $task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'One-time WSA PacMan continuation after Windows virtualization features are enabled.'
        Register-ScheduledTask -TaskName $script:ResumeTaskName -InputObject $task -Force -ErrorAction Stop | Out-Null
        Write-Info 'Automatic continuation is registered for your next Windows sign-in.'
    }
    catch {
        throw "Windows enabled the virtualization features, but could not schedule automatic continuation. Details: $($_.Exception.Message)"
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
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    if ([int]$osInfo.ProductType -ne 1) {
        throw 'The WSA runtime helper supports Windows 10/11 desktop editions only; Windows Server is not supported.'
    }

    $versionKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $currentBuild = Get-ItemProperty -Path $versionKey
    $buildNumber = [int]$currentBuild.CurrentBuildNumber
    $revision = [int]$currentBuild.UBR
    $edition = [string]$currentBuild.EditionID
    $displayVersion = [string]$currentBuild.DisplayVersion

    # ProductName can retain a Windows 10 label on newer Windows 11 installations.
    # Use the build family for the displayed OS version instead.
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
        # An active Windows hypervisor confirms that firmware virtualization is usable.
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
        Write-WarningMessage 'Windows virtualization features are enabled or pending. Save your work and restart Windows when convenient.'
        Register-WsaResumeTask
        Write-Info 'After Windows restarts and you sign in, WSA PacMan will automatically resume the Android runtime setup.'
        Write-Info 'You do not need to reopen WSA PacMan or launch the helper manually.'
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

function Get-WsaSettingsApplicationId([string]$InstallLocation) {
    $manifestPath = Join-Path $InstallLocation 'AppxManifest.xml'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "The WSA manifest was not found at $manifestPath."
    }

    [xml]$manifest = Get-Content -LiteralPath $manifestPath -Raw
    $settingsApplication = $manifest.SelectNodes("//*[local-name()='Application']") |
        Where-Object { $_.GetAttribute('Executable') -match '(?i)WsaSettings\.exe$' } |
        Select-Object -First 1

    if ($null -eq $settingsApplication) {
        throw 'The WSA manifest does not declare an application for WsaSettings.exe.'
    }

    $applicationId = $settingsApplication.GetAttribute('Id')
    if ([string]::IsNullOrWhiteSpace($applicationId)) {
        throw 'The WSA Settings application has no registered Application Id.'
    }

    return $applicationId
}

function Enable-WsaDeveloperMode($Package) {
    # WSA Android Developer mode is stored in this user's settings.dat registry
    # hive. Do not change the separate Windows OS Developer Mode setting, and do
    # not replace the complete hive with a pre-patched file.
    $settingsPath = $null
    $hiveLoaded = $false
    $patchSucceeded = $false
    $hiveName = 'WSAPacmanDeveloperMode_' + [guid]::NewGuid().ToString('N')
    $hiveSubKey = $hiveName
    $hiveMount = "HKLM\$hiveName"
    $regExe = Join-Path $env:SystemRoot 'System32\reg.exe'

    try {
        if ([string]::IsNullOrWhiteSpace([string]$Package.PackageFamilyName)) {
            throw 'The registered WSA package did not report a PackageFamilyName.'
        }

        $settingsDirectory = Join-Path (Join-Path $env:LOCALAPPDATA 'Packages') (Join-Path $Package.PackageFamilyName 'Settings')
        $settingsPath = Join-Path $settingsDirectory 'settings.dat'

        $settingsAppLaunchedBySetup = $false
        $settingsProcessIdsBeforeLaunch = @()
        if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) {
            # First launch creates WSA's per-user settings hive. Launch the
            # package's registered Settings app rather than assuming an ID.
            $settingsExecutable = Join-Path $Package.InstallLocation 'WsaSettings.exe'
            $settingsProcessIdsBeforeLaunch = @(
                Get-CimInstance Win32_Process -Filter "Name='WsaSettings.exe'" -ErrorAction SilentlyContinue |
                    Where-Object { $_.ExecutablePath -and $_.ExecutablePath -ieq $settingsExecutable } |
                    Select-Object -ExpandProperty ProcessId
            )
            $settingsApplicationId = Get-WsaSettingsApplicationId -InstallLocation $Package.InstallLocation
            $aumid = "$($Package.PackageFamilyName)!$settingsApplicationId"
            Write-Info 'Initializing the new WSA user settings hive.'
            Start-Process -FilePath (Join-Path $env:SystemRoot 'explorer.exe') -ArgumentList "shell:AppsFolder\$aumid" -WindowStyle Hidden | Out-Null
            $settingsAppLaunchedBySetup = $true

            $deadline = (Get-Date).AddSeconds(60)
            while ((Get-Date) -lt $deadline -and -not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) {
                Start-Sleep -Seconds 1
            }
        }

        if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) {
            throw "WSA did not create its settings.dat file at $settingsPath within 60 seconds."
        }

        # Close only a WsaSettings.exe process that did not exist before this
        # setup launched the Settings app. Never close the user's existing app.
        if ($settingsAppLaunchedBySetup) {
            $settingsExecutable = Join-Path $Package.InstallLocation 'WsaSettings.exe'
            if (Test-Path -LiteralPath $settingsExecutable -PathType Leaf) {
                $newSettingsProcesses = @(
                    Get-CimInstance Win32_Process -Filter "Name='WsaSettings.exe'" -ErrorAction SilentlyContinue |
                        Where-Object {
                            $_.ExecutablePath -and
                            $_.ExecutablePath -ieq $settingsExecutable -and
                            $_.ProcessId -notin $settingsProcessIdsBeforeLaunch
                        }
                )
                foreach ($settingsProcess in $newSettingsProcesses) {
                    try {
                        $process = Get-Process -Id ([int]$settingsProcess.ProcessId) -ErrorAction Stop
                        if ($process.MainWindowHandle -ne 0) {
                            [void]$process.CloseMainWindow()
                            [void]$process.WaitForExit(5000)
                        }
                    }
                    catch {
                        # If it remains active, reg.exe load below fails safely.
                    }
                }
            }
        }

        $backupPath = $settingsPath + '.pre-dev-mode.' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.bak'
        Copy-Item -LiteralPath $settingsPath -Destination $backupPath -ErrorAction Stop
        Write-Info "Backed up the original WSA settings hive to $backupPath."

        if (-not (Test-Path -LiteralPath $regExe -PathType Leaf)) {
            throw "Windows Registry tool was not found at $regExe."
        }

        & $regExe load $hiveMount $settingsPath | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Could not mount the WSA settings hive (reg.exe exit code $LASTEXITCODE). The original settings file was not changed."
        }
        $hiveLoaded = $true

        if (-not ('WsaPacmanRawRegistryValue' -as [type])) {
            $registryHelperSource = @'
using System;
using System.Runtime.InteropServices;

public sealed class WsaPacmanRegistryReadResult
{
    public int Status { get; private set; }
    public uint Type { get; private set; }
    public byte[] Data { get; private set; }

    public WsaPacmanRegistryReadResult(int status, uint type, byte[] data)
    {
        Status = status;
        Type = type;
        Data = data ?? new byte[0];
    }
}

public static class WsaPacmanRawRegistryValue
{
    private const int ERROR_SUCCESS = 0;
    private const int KEY_QUERY_VALUE = 0x0001;
    private const int KEY_SET_VALUE = 0x0002;
    private const int ERROR_INVALID_DATA = 13;
    private static readonly IntPtr HKEY_LOCAL_MACHINE =
        new IntPtr(unchecked((int)0x80000002));

    [DllImport("advapi32.dll", EntryPoint = "RegOpenKeyExW", CharSet = CharSet.Unicode, ExactSpelling = true)]
    private static extern int RegOpenKeyEx(
        IntPtr hKey, string subKey, uint options, int desiredAccess, out IntPtr result);

    [DllImport("advapi32.dll", EntryPoint = "RegQueryValueExW", CharSet = CharSet.Unicode, ExactSpelling = true)]
    private static extern int RegQueryValueSize(
        IntPtr key, string valueName, IntPtr reserved, out uint type, IntPtr data, ref uint dataSize);

    [DllImport("advapi32.dll", EntryPoint = "RegQueryValueExW", CharSet = CharSet.Unicode, ExactSpelling = true)]
    private static extern int RegQueryValueData(
        IntPtr key, string valueName, IntPtr reserved, out uint type, [Out] byte[] data, ref uint dataSize);

    [DllImport("advapi32.dll", EntryPoint = "RegSetValueExW", CharSet = CharSet.Unicode, ExactSpelling = true)]
    private static extern int RegSetValue(
        IntPtr key, string valueName, uint reserved, uint type, byte[] data, uint dataSize);

    [DllImport("advapi32.dll", EntryPoint = "RegCloseKey", ExactSpelling = true)]
    private static extern int RegCloseKey(IntPtr key);

    public static WsaPacmanRegistryReadResult Read(string subKey, string valueName)
    {
        IntPtr key = IntPtr.Zero;
        int status = RegOpenKeyEx(HKEY_LOCAL_MACHINE, subKey, 0, KEY_QUERY_VALUE, out key);
        if (status != ERROR_SUCCESS)
            return new WsaPacmanRegistryReadResult(status, 0, null);

        try
        {
            uint type = 0;
            uint size = 0;
            status = RegQueryValueSize(key, valueName, IntPtr.Zero, out type, IntPtr.Zero, ref size);
            if (status != ERROR_SUCCESS)
                return new WsaPacmanRegistryReadResult(status, type, null);
            if (size > 65536)
                return new WsaPacmanRegistryReadResult(ERROR_INVALID_DATA, type, null);

            byte[] data = new byte[(int)size];
            if (size > 0)
            {
                status = RegQueryValueData(key, valueName, IntPtr.Zero, out type, data, ref size);
                if (status != ERROR_SUCCESS)
                    return new WsaPacmanRegistryReadResult(status, type, null);
                if (size < data.Length)
                    Array.Resize(ref data, (int)size);
            }

            return new WsaPacmanRegistryReadResult(ERROR_SUCCESS, type, data);
        }
        finally
        {
            RegCloseKey(key);
        }
    }

    public static int Write(string subKey, string valueName, uint type, byte[] data)
    {
        IntPtr key = IntPtr.Zero;
        int status = RegOpenKeyEx(HKEY_LOCAL_MACHINE, subKey, 0, KEY_SET_VALUE, out key);
        if (status != ERROR_SUCCESS)
            return status;

        try
        {
            return RegSetValue(key, valueName, 0, type, data, (uint)data.Length);
        }
        finally
        {
            RegCloseKey(key);
        }
    }
}
'@
            Add-Type -TypeDefinition $registryHelperSource -ErrorAction Stop
        }

        # WSA stores DeveloperModeEnabled as a 9-byte custom registry value.
        # Preserve its 8-byte metadata when the value already exists.
        $developerModeValueType = [uint32]0x05F5E10B
        $read = [WsaPacmanRawRegistryValue]::Read($hiveSubKey, 'DeveloperModeEnabled')

        if ($read.Status -eq 2) {
            # Fresh WSA settings hive: first byte is the enabled flag; the
            # remaining bytes are its FILETIME metadata.
            $payload = New-Object byte[] 9
            $payload[0] = 1
            [byte[]]$fileTime = [BitConverter]::GetBytes([DateTime]::UtcNow.ToFileTimeUtc())
            [Array]::Copy($fileTime, 0, $payload, 1, 8)
            $writeType = $developerModeValueType
            Write-Info 'Creating the WSA DeveloperModeEnabled setting in the fresh settings hive.'
        }
        elseif ($read.Status -ne 0) {
            throw "Could not read WSA DeveloperModeEnabled (Windows registry error $($read.Status))."
        }
        else {
            if ($read.Type -ne $developerModeValueType -or $read.Data.Length -ne 9) {
                throw "WSA DeveloperModeEnabled has an unrecognized registry type/length ($($read.Type)/$($read.Data.Length)); refusing to alter the settings hive."
            }
            if ($read.Data[0] -notin @(0, 1)) {
                throw "WSA DeveloperModeEnabled has an unexpected flag byte ($($read.Data[0])); refusing to alter the settings hive."
            }
            if ($read.Data[0] -eq 1) {
                Write-Info 'WSA Android Developer mode is already enabled.'
                $patchSucceeded = $true
            }
            else {
                $payload = [byte[]]$read.Data.Clone()
                $payload[0] = 1
                $writeType = $read.Type
                Write-Info 'Enabling WSA Android Developer mode while preserving the existing hive metadata.'
            }
        }

        if (-not $patchSucceeded) {
            $writeStatus = [WsaPacmanRawRegistryValue]::Write($hiveSubKey, 'DeveloperModeEnabled', $writeType, $payload)
            if ($writeStatus -ne 0) {
                throw "Could not write WSA DeveloperModeEnabled (Windows registry error $writeStatus)."
            }

            $verify = [WsaPacmanRawRegistryValue]::Read($hiveSubKey, 'DeveloperModeEnabled')
            if ($verify.Status -ne 0 -or $verify.Type -ne $writeType -or $verify.Data.Length -ne 9 -or $verify.Data[0] -ne 1) {
                throw 'WSA DeveloperModeEnabled read-back verification failed.'
            }

            Write-Info 'WSA Android Developer mode was enabled and verified in settings.dat.'
            $patchSucceeded = $true
        }
    }
    catch {
        Write-WarningMessage "Could not enable WSA Android Developer mode automatically: $($_.Exception.Message)"
        Write-Host 'WSA remains installed. Open WSA Settings > Advanced settings and turn Developer mode on manually if needed.'
        $patchSucceeded = $false
    }
    finally {
        if ($hiveLoaded) {
            & $regExe unload $hiveMount | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-WarningMessage 'The temporary WSA settings hive could not be unloaded cleanly. Restart Windows before manually editing WSA settings.'
                $patchSucceeded = $false
            }
        }
    }

    return [bool]$patchSucceeded
}

function Install-WsaFromFolder([string]$Folder) {
    $runBatch = Get-ChildItem -LiteralPath $Folder -Filter 'Run.bat' -File -Recurse |
        Select-Object -First 1
    if ($null -eq $runBatch) {
        throw "The extracted upstream package did not contain Run.bat. The files have been kept at $Folder for inspection."
    }

    $workingDirectory = $runBatch.DirectoryName
    $upstreamScript = Join-Path $workingDirectory 'Install.ps1'
    if (-not (Test-Path -LiteralPath $upstreamScript -PathType Leaf)) {
        throw "The extracted package did not contain Install.ps1 beside Run.bat. The files have been kept at $Folder for inspection."
    }

    Write-Host ''
    Write-Info 'Registering the WSA Android runtime in the background.'
    Write-Info 'Running the upstream Install.ps1 directly; its Run.bat launcher opens a separate visible PowerShell window.'

    $sourceText = Get-Content -LiteralPath $upstreamScript -Raw
    if ($sourceText -notmatch '(?i)Add-AppxPackage\s+-ForceApplicationShutdown\s+-ForceUpdateFromAnyVersion\s+-Register\s+\.\\AppxManifest\.xml') {
        throw "The upstream Install.ps1 has an unexpected structure. Refusing to patch or run an unrecognized installer. The original file was left untouched."
    }

    # Create a temporary sibling copy so all upstream relative paths remain valid.
    # Keep the verified upstream Install.ps1 unchanged.
    $unattendedScript = Join-Path $workingDirectory 'Install-WSA-PacMan-Unattended.ps1'
    $logDirectory = Join-Path $env:ProgramData 'WSABuilds\Logs'
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    $logStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $stdoutLog = Join-Path $logDirectory ("WSA-Upstream-$logStamp.stdout.log")
    $stderrLog = Join-Path $logDirectory ("WSA-Upstream-$logStamp.stderr.log")

    # Upstream Finish() launches Magisk and Play Store after registering WSA.
    # This helper selects a NoGApps package, so don't launch unrelated Android apps.
    $finishPattern = '(?ims)^Function\s+Finish\s*\{.*?^\}'
    if (-not [regex]::IsMatch($sourceText, $finishPattern)) {
        throw 'The upstream installer has an unrecognized Finish() function. Refusing to launch unrelated Android apps automatically.'
    }
    $finishReplacement = 'Function Finish {' + [Environment]::NewLine +
        "    Write-Output 'WSA runtime registration completed.'" + [Environment]::NewLine + '}'
    $finishEvaluator = [System.Text.RegularExpressions.MatchEvaluator]{
        param($match)
        return $finishReplacement
    }
    $sourceText = [regex]::Replace($sourceText, $finishPattern, $finishEvaluator)

    # Upstream prompts for keypresses on completion and error branches. Remove
    # the waits. An existing-install confirmation gets a null key, i.e. "No".
    $readKeyPattern = '(?m)(\$[A-Za-z_][A-Za-z0-9_]*\s*=\s*)\$Host\.UI\.RawUI\.ReadKey\(''NoEcho,IncludeKeyDown''\);?'
    $readKeyMatches = [regex]::Matches($sourceText, $readKeyPattern)
    if ($readKeyMatches.Count -eq 0) {
        throw 'The upstream installer no longer contains the expected keypress prompt pattern. Refusing to run an unverified unattended variant.'
    }
    $readKeyEvaluator = [System.Text.RegularExpressions.MatchEvaluator]{
        param($match)
        return $match.Groups[1].Value + '$null'
    }
    $sourceText = [regex]::Replace($sourceText, $readKeyPattern, $readKeyEvaluator)
    if ($sourceText -match '(?i)RawUI\.ReadKey\s*\(') {
        throw 'The upstream installer contains an unrecognized interactive keypress prompt. Refusing to run it hidden because that could leave setup waiting indefinitely.'
    }

    # Never let the upstream error-recovery path uninstall an existing package.
    $preservePattern = '(?ims)^ElseIf\s*\(\s*\$null\s*-Ne\s*\$Installed\s*\)\s*\{.*?^\}'
    if (-not [regex]::IsMatch($sourceText, $preservePattern)) {
        throw 'The upstream installer no longer has the expected existing-package recovery path. Refusing an unattended install until that path can be reviewed.'
    }
    $preserveReplacement = 'ElseIf ($null -Ne $Installed) {' + [Environment]::NewLine +
        "    throw 'WSA registration failed while an existing package is present. PacMan will not uninstall or replace it.'" + [Environment]::NewLine + '}'
    $preserveEvaluator = [System.Text.RegularExpressions.MatchEvaluator]{
        param($match)
        return $preserveReplacement
    }
    $sourceText = [regex]::Replace($sourceText, $preservePattern, $preserveEvaluator)

    # The outer PacMan helper is already elevated. Keep even an unexpected
    # upstream self-elevation or conhost fallback hidden.
    $sourceText = $sourceText.Replace(
        'Start-Process -PassThru -Verb RunAs $pwsh -Args',
        'Start-Process -PassThru -Verb RunAs -WindowStyle Hidden $pwsh -Args'
    )
    $sourceText = $sourceText.Replace(
        'Start-Process conhost.exe -Args',
        'Start-Process conhost.exe -WindowStyle Hidden -Args'
    )

    [System.IO.File]::WriteAllText(
        $unattendedScript,
        $sourceText,
        [System.Text.UTF8Encoding]::new($false)
    )

    try {
        $powershell = Join-Path $PSHOME 'powershell.exe'
        if (-not (Test-Path -LiteralPath $powershell -PathType Leaf)) {
            throw "Windows PowerShell could not be found at $powershell."
        }

        $arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $unattendedScript + '"'
        $process = Start-Process -FilePath $powershell -ArgumentList $arguments -WorkingDirectory $workingDirectory -WindowStyle Hidden -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog -Wait -PassThru

        if ($process.ExitCode -ne 0) {
            $stderrTail = if (Test-Path -LiteralPath $stderrLog) {
                (Get-Content -LiteralPath $stderrLog -Tail 20 -ErrorAction SilentlyContinue) -join ' '
            } else { '' }
            throw "The hidden upstream WSA registration process exited with code $($process.ExitCode). Details: $stderrTail. Logs: $stdoutLog and $stderrLog"
        }
    }
    finally {
        Remove-Item -LiteralPath $unattendedScript -Force -ErrorAction SilentlyContinue
    }

    Start-Sleep -Seconds 3
    $registered = Get-ExistingWsaPackage
    if ($registered.Count -eq 0) {
        throw "The upstream installer finished, but Windows did not report a registered WSA package. Logs: $stdoutLog and $stderrLog. The original files were kept at $workingDirectory."
    }

    Write-Info "Upstream installer output: $stdoutLog"
    Write-Info "Upstream installer errors: $stderrLog"
    return $registered
}

try {
    Ensure-Administrator

    $logDirectory = Join-Path $env:ProgramData 'WSABuilds\Logs'
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    $logPath = Join-Path $logDirectory ("Install-WSA-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    try {
        Start-Transcript -Path $logPath -Force | Out-Null
        $script:TranscriptStarted = $true
    }
    catch {
        Write-WarningMessage "A diagnostic log could not be started: $($_.Exception.Message)"
    }

    if ($ResumeAfterRestart) {
        Remove-WsaResumeTask
        Write-Info 'Windows sign-in detected after the prerequisite restart; automatically resuming setup.'
    }

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
        exit 0
    }

    $previousUserData = Join-Path $env:LOCALAPPDATA 'Packages\MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe\LocalCache\userdata.vhdx'
    if (Test-Path -LiteralPath $previousUserData) {
        Write-WarningMessage 'A previous WSA Userdata.vhdx was found even though no WSA package is currently registered.'
        Write-Host "Possible Android app data is stored here: $previousUserData"
        Write-Host 'Copy this file to a safe backup location and move the original out of the WSA package folder before running a fresh install.'
        Write-Info 'No download, extraction, installation or deletion was performed.'
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

    Write-Info 'The WSA runtime installation task was selected. Continuing automatically with download, verification, extraction and registration.'

    $root = Join-Path $env:ProgramData 'WSABuilds'
    $installFolder = Join-Path $root ("WSA-" + $release.tag_name)
    $downloadsFolder = Join-Path $root 'Downloads'
    $toolsFolder = Join-Path $root 'Tools'
    New-Item -ItemType Directory -Path $root, $downloadsFolder, $toolsFolder -Force | Out-Null

    $runBatchAlreadyExtracted = Get-ChildItem -LiteralPath $installFolder -Filter 'Run.bat' -File -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($null -eq $runBatchAlreadyExtracted) {
        if (Test-Path -LiteralPath $installFolder) {
            $preservedFolder = "$installFolder.incomplete.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Move-Item -LiteralPath $installFolder -Destination $preservedFolder -ErrorAction Stop
            Write-WarningMessage "A previous incomplete extraction was preserved at $preservedFolder."
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
    $developerModeEnabled = Enable-WsaDeveloperMode -Package $registeredPackage
    if (-not $developerModeEnabled) {
        Write-WarningMessage 'WSA installation completed, but Android Developer mode needs manual confirmation in WSA Settings.'
    }
    Write-Host ''
    Write-Info "WSA is registered: $($registeredPackage.Name)"
    Write-Info "The WSA files are stored at: $installFolder"
    Write-Info 'The WSA files must remain on this PC. Windows uses them to run WSA.'
    Write-Host 'Next: WSA is installed. Open WSA PacMan to connect to the Android runtime.'

    if ($archivePath -and (Test-Path -LiteralPath $archivePath)) {
        Remove-Item -LiteralPath $archivePath -Force
    }
    Remove-WsaResumeTask
    if ($script:TranscriptStarted) {
        Stop-Transcript | Out-Null
        $script:TranscriptStarted = $false
    }
}
catch {
    Write-Host ''
    Write-WarningMessage $_.Exception.Message
    Write-Host 'No existing WSA installation was automatically uninstalled or overwritten.'
    if ($script:TranscriptStarted) {
        Stop-Transcript | Out-Null
        Write-Host "Diagnostic log: $logPath"
        $script:TranscriptStarted = $false
    }
    exit 1
}
