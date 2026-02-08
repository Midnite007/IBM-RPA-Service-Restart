param(
    [string]$ServiceName = "IBM Robotic Process Automation Agent"
)

$ErrorActionPreference = "Stop"

function Now {
    return (Get-Date -Format "HH:mm:ss")
}

function Log {
    param(
        [string]$Level,
        [string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::White
    )
    Write-Host "[$(Now)] [$Level] $Message" -ForegroundColor $Color
}

function Ensure-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)

    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Log "WARN" "Not running as Administrator. Requesting elevation..." Yellow
        $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        $psExe = if ($PSVersionTable.PSVersion.Major -ge 6) { "pwsh" } else { "powershell.exe" }
		Start-Process $psExe -Verb RunAs -ArgumentList $args
        exit 0
    }
}

Ensure-Admin

function Show-Progress {
    param(
        [string]$Activity,
        [int]$Percent
    )
    Write-Progress -Activity $Activity -PercentComplete $Percent
}

function Kill-ServiceProcess {
    param([string]$Name)

    $svc = Get-CimInstance Win32_Service -Filter "Name='$Name'"
    if ($svc -and $svc.ProcessId -ne 0) {
        Log "WARN" "Killing process $($svc.ProcessId)..." Yellow
        Stop-Process -Id $svc.ProcessId -Force
        Start-Sleep -Seconds 5
    }
}

Log "INFO" "Running with administrative privileges." Cyan
Log "INFO" "Searching for service." Cyan

$service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

if (-not $service) {
    Log "ERROR" "Service not found." Red
    exit 1
}

Log "OK" "Service found. Current status: $($service.Status)" Green

# --- STOP PHASE ---
if ($service.Status -ne 'Stopped') {
    Log "INFO" "Stopping service (timeout: 60 seconds)..." Cyan

    try {
        Stop-Service -Name $ServiceName -Force -ErrorAction Stop
    }
    catch {
        Log "WARN" "Stop-Service failed. Forcing kill..." Yellow
        Kill-ServiceProcess -Name $ServiceName
    }

    $elapsed = 0
    while ((Get-Service $ServiceName).Status -ne 'Stopped') {
        if ($elapsed -ge 60) {
            Log "WARN" "Service still not stopped. Forcing kill..." Yellow
            Kill-ServiceProcess -Name $ServiceName
            break
        }
        $percent = [math]::Min(100, ($elapsed / 60) * 100)
        Show-Progress "Stopping service" $percent
        Start-Sleep -Seconds 1
        $elapsed++
    }
    Show-Progress "Stopping service" 100
}

$service = Get-Service $ServiceName
if ($service.Status -ne 'Stopped') {
    Log "ERROR" "Service could not be stopped even after kill." Red
    exit 2
}

Log "OK" "Service stopped successfully." Green

# --- START PHASE ---
Log "INFO" "Starting service (timeout: 60 seconds)..." Cyan
Start-Service -Name $ServiceName

$elapsed = 0
while ((Get-Service $ServiceName).Status -ne 'Running') {
    if ($elapsed -ge 60) {
        Log "ERROR" "Service did not start within 100 seconds." Red
        exit 3
    }
    $percent = [math]::Min(100, ($elapsed / 60) * 100)
    Show-Progress "Starting service" $percent
    Start-Sleep -Seconds 1
    $elapsed++
}
Show-Progress "Starting service" 100

Log "SUCCESS" "Service restarted successfully." Green

exit 0