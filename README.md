# Service Restart (PowerShell)

A small PowerShell script to stop and start a Windows service with basic logging, a progress indicator, and a fallback that force-kills the service process if a normal stop fails.

File: `Service_restart.ps1`

## What it does

1. Ensures the script is running elevated (Administrator). If not, it re-launches itself with UAC elevation.
2. Looks up the target Windows service.
3. Stops the service (up to 60 seconds).
   - If `Stop-Service` fails, it attempts to kill the service’s process by PID via `Win32_Service` (CIM/WMI) and retries/waits.
4. Starts the service (up to 60 seconds).
5. Returns an exit code suitable for automation.

## Requirements

- Windows (uses Windows services and `Win32_Service`).
- PowerShell 5.1+ or PowerShell 7+.
- Administrator privileges (the script self-elevates).

## Usage

Run from an elevated PowerShell session, or let the script prompt for elevation:

### Parameter

- `-ServiceName` (string)
  - Default: `IBM Robotic Process Automation Agent`
  - Intended to be the **service name** (not the display name).

## Implementation notes and caveats

- **Timeouts:** Stop and start loops are implemented with a 60 second limit.  
  The start-phase error message mentions “100 seconds”, but the code enforces 60 seconds. If you rely on the message, adjust it or the timeout value.
- **Force kill fallback:** The fallback uses `Get-CimInstance Win32_Service` to read the service `ProcessId` and calls `Stop-Process -Force` on that PID. This is a blunt mechanism and should be used with care for services that share processes (for example `svchost` hosted services). In those cases, killing the PID may affect other services.
- **Service identifier consistency:** The kill logic queries `Win32_Service` by `Name` and assumes the same identifier you pass to `-ServiceName`. This must match the actual service name.
