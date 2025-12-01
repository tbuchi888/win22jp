$logPath = 'C:\\WindowsAzure\\Logs\\JapaneseSetup'
$statusPath = 'C:\\ProgramData\\JapaneseLangSetup'
$scriptPath = 'C:\\ProgramData\\JapaneseLangSetup\\setup-japanese.ps1'

if (-not (Test-Path $logPath)) { New-Item -Path $logPath -ItemType Directory -Force }
if (-not (Test-Path $statusPath)) { New-Item -Path $statusPath -ItemType Directory -Force }

function Write-Log { param([string]$Message); $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'; \"$ts - $Message\" | Out-File -FilePath \"$logPath\\setup.log\" -Append; Write-Output $Message }

Write-Log 'Japanese Language Setup started'

$mainScript = @'
$logPath = 'C:\WindowsAzure\Logs\JapaneseSetup'
$statusPath = 'C:\ProgramData\JapaneseLangSetup'
function Write-Log { param([string]$Message); $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'; "$ts - $Message" | Out-File -FilePath "$logPath\setup.log" -Append }

$step1Done = Join-Path $statusPath 'step1.done'
$step2Done = Join-Path $statusPath 'step2.done'

Write-Log "Status: Step1=$([System.IO.File]::Exists($step1Done)), Step2=$([System.IO.File]::Exists($step2Done))"

if (-not (Test-Path $step1Done)) {
    Write-Log 'Step 1: Installing Japanese language pack'
    try {
        Install-Language -Language ja-JP -CopyToSettings
        $lang = New-WinUserLanguageList -Language 'ja-JP'
        $lang.Add('en-US')
        Set-WinUserLanguageList -LanguageList $lang -Force
        Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true
        New-Item -Path $step1Done -ItemType File -Force
        Write-Log 'Step 1 completed. Rebooting...'
        shutdown /r /t 10 /c 'Japanese Setup - Reboot 1'
    } catch { Write-Log "Step 1 failed: $_" }
    exit 0
}

if ((Test-Path $step1Done) -and (-not (Test-Path $step2Done))) {
    Write-Log 'Step 2: Setting Japanese as default'
    try {
        Set-WinSystemLocale -SystemLocale ja-JP
        Set-WinUILanguageOverride -Language ja-JP
        Set-WinHomeLocation -GeoId 122
        Set-TimeZone -Id 'Tokyo Standard Time'
        Set-Culture -CultureInfo ja-JP
        Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true
        New-Item -Path $step2Done -ItemType File -Force
        Write-Log 'Step 2 completed.'
        Unregister-ScheduledTask -TaskName 'JapaneseLanguageSetup' -Confirm:$false -ErrorAction SilentlyContinue
        Write-Log 'Task removed. Final reboot...'
        shutdown /r /t 10 /c 'Japanese Setup - Final Reboot'
    } catch { Write-Log "Step 2 failed: $_" }
    exit 0
}

if ((Test-Path $step1Done) -and (Test-Path $step2Done)) {
    Write-Log 'Already completed'
    Unregister-ScheduledTask -TaskName 'JapaneseLanguageSetup' -Confirm:$false -ErrorAction SilentlyContinue
}
'@

$mainScript | Out-File -FilePath $scriptPath -Encoding UTF8 -Force
Write-Log "Script saved to $scriptPath"

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
Register-ScheduledTask -TaskName 'JapaneseLanguageSetup' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force
Write-Log 'Scheduled task registered'

Write-Log 'Starting Step 1...'
& powershell.exe -ExecutionPolicy Bypass -File $scriptPath
Write-Log 'Initial script completed'
