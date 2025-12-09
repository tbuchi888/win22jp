# japaneseSetupScript.ps1 - 外部ファイル呼び出し版（修正）
$logPath = 'C:\WindowsAzure\Logs\JapaneseSetup'
$statusPath = 'C:\JapaneseLangSetup'
$scriptPath = 'C:\JapaneseLangSetup\setup-japanese.ps1'
$downloadPath = $PSScriptRoot  # Custom Script Extension のダウンロードフォルダ

if (-not (Test-Path $logPath)) { New-Item -Path $logPath -ItemType Directory -Force }
if (-not (Test-Path $statusPath)) { New-Item -Path $statusPath -ItemType Directory -Force }

function Write-Log { param([string]$Message); $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'; "$ts - $Message" | Out-File -FilePath "$logPath\setup.log" -Append; Write-Output $Message }

Write-Log "Japanese Language Setup started"
Write-Log "Download path: $downloadPath"

# Step1/Step2 スクリプトを永続的なフォルダにコピー（重要！）
Copy-Item "$downloadPath\change-ws2022-lang-ja-step1-noreboot.ps1" "$statusPath\" -Force
Copy-Item "$downloadPath\change-ws2022-lang-ja-step2-noreboot.ps1" "$statusPath\" -Force
Write-Log "Scripts copied to $statusPath"

# setup-japanese.ps1 の内容（$statusPath 内のスクリプトを参照）
$mainScript = @'
$logPath = 'C:\WindowsAzure\Logs\JapaneseSetup'
$statusPath = 'C:\JapaneseLangSetup'
function Write-Log { param([string]$Message); $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'; "$ts - $Message" | Out-File -FilePath "$logPath\setup.log" -Append }

$step1Done = Join-Path $statusPath 'step1.done'
$step2Done = Join-Path $statusPath 'step2.done'
$step1Script = Join-Path $statusPath 'change-ws2022-lang-ja-step1-noreboot.ps1'
$step2Script = Join-Path $statusPath 'change-ws2022-lang-ja-step2-noreboot.ps1'

Write-Log "Status: Step1=$([System.IO.File]::Exists($step1Done)), Step2=$([System.IO.File]::Exists($step2Done))"

if (-not (Test-Path $step1Done)) {
    Write-Log "Step 1: Running $step1Script"
    try {
        & $step1Script
        New-Item -Path $step1Done -ItemType File -Force
        Write-Log 'Step 1 completed. Rebooting...'
        shutdown /r /t 10 /c 'Japanese Setup - Reboot 1'
    } catch {
        Write-Log "Step 1 failed: $_"
        Write-Log "Cleaning up scheduled task due to Step 1 failure"
        Unregister-ScheduledTask -TaskName 'JapaneseLanguageSetup' -Confirm:$false -ErrorAction SilentlyContinue
    }
    exit 0
}

if ((Test-Path $step1Done) -and (-not (Test-Path $step2Done))) {
    Write-Log "Step 2: Running $step2Script"
    try {
        & $step2Script
        New-Item -Path $step2Done -ItemType File -Force
        Write-Log 'Step 2 completed.'
        # Schedule task deletion 1 hour after Step2 completion
        Write-Log 'Scheduling task cleanup in 1 hour...'
        # Create a cleanup command that removes both tasks
        $cleanupCmd = "Unregister-ScheduledTask -TaskName 'JapaneseLanguageSetup' -Confirm:`$false -ErrorAction SilentlyContinue; Unregister-ScheduledTask -TaskName 'JapaneseLanguageSetup_Cleanup' -Confirm:`$false -ErrorAction SilentlyContinue"
        $cleanupAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -Command `"$cleanupCmd`""
        $cleanupTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddHours(1)
        $cleanupPrincipal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
        $cleanupSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        Register-ScheduledTask -TaskName 'JapaneseLanguageSetup_Cleanup' -Action $cleanupAction -Trigger $cleanupTrigger -Principal $cleanupPrincipal -Settings $cleanupSettings -Force | Out-Null
        Write-Log 'Task cleanup scheduled. Final reboot...'
        shutdown /r /t 10 /c 'Japanese Setup - Final Reboot'
    } catch {
        Write-Log "Step 2 failed: $_"
        Write-Log "Cleaning up scheduled tasks due to Step 2 failure"
        Unregister-ScheduledTask -TaskName 'JapaneseLanguageSetup' -Confirm:$false -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName 'JapaneseLanguageSetup_Cleanup' -Confirm:$false -ErrorAction SilentlyContinue
    }
    exit 0
}

if ((Test-Path $step1Done) -and (Test-Path $step2Done)) {
    Write-Log 'Already completed'
    Unregister-ScheduledTask -TaskName 'JapaneseLanguageSetup' -Confirm:$false -ErrorAction SilentlyContinue
}
'@

$mainScript | Out-File -FilePath $scriptPath -Encoding UTF8 -Force
Write-Log "Main script saved to $scriptPath"

# タスクスケジューラに登録
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
Register-ScheduledTask -TaskName 'JapaneseLanguageSetup' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force
Write-Log 'Scheduled task registered'

Write-Log 'Starting Step 1...'
& powershell.exe -ExecutionPolicy Bypass -File $scriptPath
Write-Log 'Initial script completed'
