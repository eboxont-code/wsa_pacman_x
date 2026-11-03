[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ExpectedAdbPath
)

$ErrorActionPreference = 'Stop'

function Get-MatchingPacmanAdbProcesses {
    $expectedPath = [System.IO.Path]::GetFullPath($ExpectedAdbPath)
    @(
        Get-CimInstance -ClassName Win32_Process -Filter "Name='adb.exe'" -ErrorAction Stop |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace([string]$_.ExecutablePath) -and
                [string]::Equals(
                    [System.IO.Path]::GetFullPath([string]$_.ExecutablePath),
                    $expectedPath,
                    [System.StringComparison]::OrdinalIgnoreCase
                )
            }
    )
}

try {
    $matchingProcesses = @(Get-MatchingPacmanAdbProcesses)

    # Do not touch an ADB server started from Android Studio, platform-tools,
    # another emulator, or any executable outside this exact PacMan install.
    if ($matchingProcesses.Count -eq 0) {
        exit 0
    }

    Write-Output 'Stopping the ADB server belonging to this WSA PacMan installation.'
    & $ExpectedAdbPath kill-server
    if ($LASTEXITCODE -ne 0) {
        throw "The bundled adb.exe kill-server command returned exit code $LASTEXITCODE."
    }

    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    do {
        Start-Sleep -Milliseconds 200
        $remaining = @(Get-MatchingPacmanAdbProcesses)
    } while ($remaining.Count -gt 0 -and [DateTime]::UtcNow -lt $deadline)

    if ($remaining.Count -gt 0) {
        $pids = ($remaining | ForEach-Object { [string]$_.ProcessId }) -join ', '
        throw "The WSA PacMan ADB process is still running (PID: $pids)."
    }

    exit 0
}
catch {
    [Console]::Error.WriteLine("WSA PacMan ADB shutdown failed: $($_.Exception.Message)")
    exit 1
}
