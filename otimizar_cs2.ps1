#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Continue'

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator)) {
    Write-Host '[ERRO] Execute este script pelo INICIAR.bat com privilegios de Administrador.' -ForegroundColor Red
    Start-Sleep -Seconds 5
    exit 1
}

$Desktop = [Environment]::GetFolderPath('Desktop')
if ([string]::IsNullOrWhiteSpace($Desktop)) { $Desktop = Join-Path $env:USERPROFILE 'Desktop' }
$LogFile = Join-Path $Desktop 'log_otimizacao.txt'
Start-Transcript -Path $LogFile -Append -Force | Out-Null

function Write-Step([string]$Message) {
    Write-Host ('[>] ' + $Message) -ForegroundColor Cyan
}
function Write-Ok([string]$Message) {
    Write-Host ('[OK] ' + $Message) -ForegroundColor Green
}
function Write-Warn([string]$Message) {
    Write-Host ('[AVISO] ' + $Message) -ForegroundColor Yellow
}
function Write-Fail([string]$Message) {
    Write-Host ('[ERRO] ' + $Message) -ForegroundColor Red
}
function Set-RegValue {
    param([string]$Path, [string]$Name, [object]$Value, [string]$Type = 'DWord')
    try {
        if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force | Out-Null }
        New-ItemProperty -Path $Path -Name $Name -PropertyType $Type -Value $Value -Force | Out-Null
        Write-Host ('  - ' + $Name + ' = ' + $Value) -ForegroundColor DarkGray
    } catch {
        Write-Warn ('Falha em ' + $Path + '\' + $Name + ': ' + $_.Exception.Message)
    }
}

Clear-Host
Write-Host '============================================================' -ForegroundColor Magenta
Write-Host '      OTIMIZADOR AUTOMATICO - WINDOWS / COUNTER-STRIKE 2      ' -ForegroundColor Magenta
Write-Host '============================================================' -ForegroundColor Magenta
Write-Host ('Log detalhado: ' + $LogFile) -ForegroundColor Gray

# 1. PONTO DE RESTAURACAO
Write-Step 'Criando ponto de restauracao do sistema...'
try {
    try { Enable-ComputerRestore -Drive 'C:\' } catch {}
    Checkpoint-Computer -Description 'Restauracao antes da Otimizacao CS2' -RestorePointType 'MODIFY_SETTINGS'
    Write-Ok 'Ponto de restauracao criado.'
} catch {
    Write-Warn ('Ponto de restauracao nao criado: ' + $_.Exception.Message)
}

# 2. WINGET
Write-Step 'Verificando/instalando runtimes e aplicativos pelo winget...'
$winget = Get-Command winget.exe -ErrorAction SilentlyContinue
if ($winget) {
    $Packages = @(
        'Valve.Steam',
        'Microsoft.VCRedist.2005.x86',
        'Microsoft.VCRedist.2005.x64',
        'Microsoft.VCRedist.2008.x86',
        'Microsoft.VCRedist.2008.x64',
        'Microsoft.VCRedist.2010.x86',
        'Microsoft.VCRedist.2010.x64',
        'Microsoft.VCRedist.2012.x86',
        'Microsoft.VCRedist.2012.x64',
        'Microsoft.VCRedist.2013.x86',
        'Microsoft.VCRedist.2013.x64',
        'Microsoft.VCRedist.2015+.x86',
        'Microsoft.VCRedist.2015+.x64',
        'Microsoft.DirectX',
        'Discord.Discord',
        '7zip.7zip'
    )
    foreach ($Package in $Packages) {
        Write-Host ('  -> ' + $Package) -ForegroundColor White
        $arguments = @('install','--exact','--id',$Package,'--silent','--accept-package-agreements','--accept-source-agreements','--disable-interactivity')
        try {
            & $winget.Source @arguments
            if ($LASTEXITCODE -eq 0) { Write-Ok ('Instalado/verificado: ' + $Package) }
            elseif ($LASTEXITCODE -eq -1978335189) { Write-Warn ('Ja instalado: ' + $Package) }
            else { Write-Warn ('Nao concluido pelo winget (' + $LASTEXITCODE + '): ' + $Package) }
        } catch {
            Write-Warn ('Falha ao executar winget para ' + $Package + ': ' + $_.Exception.Message)
        }
    }
} else {
    Write-Warn 'winget nao esta disponivel neste sistema.'
}

# 3. ENERGIA E CPU
Write-Step 'Configurando plano de energia e estado da CPU...'
try {
    $ultimate = 'e9a42b02-d5df-448d-a0f3-a92b98bf6dc9'
    $existing = powercfg.exe /list
    $scheme = 'SCHEME_CURRENT'
    if ($existing -notmatch 'Desempenho') {
        powercfg.exe /duplicatescheme $ultimate | Out-Null
    }
    $guidMatch = [regex]::Match($existing + "`n" + (powercfg.exe /list), '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})')
    $ultimateScheme = (powercfg.exe /list | Select-String -Pattern '9.?42b02|Ultimate|Desempenho').Line
    if ($ultimateScheme -match '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}') {
        $scheme = $Matches[0]
    } else {
        $scheme = 'SCHEME_CURRENT'
    }
    powercfg.exe /setactive $scheme

    $processorGUID = '54533251-82be-4824-96c1-0b0642e5e2f0'
    foreach ($setting in @('CPMINCORES','CPMAXCORES','PROCTHROTTLEMIN','PROCTHROTTLEMAX','PERFINCPOL','PERDECPOL')) {
        powercfg.exe /setacvalueindex $scheme $processorGUID $setting 100
        powercfg.exe /setdcvalueindex $scheme $processorGUID $setting 100
    }
    powercfg.exe /setacvalueindex $scheme $processorGUID 'IDLESCALING' 0
    powercfg.exe /setdcvalueindex $scheme $processorGUID 'IDLESCALING' 0
    powercfg.exe /setactive $scheme
    Write-Ok 'Plano energetico aplicado; nucleo reservado e throttling desativados.'
} catch {
    Write-Warn ('Falha parcial no plano de energia: ' + $_.Exception.Message)
}

# Core Parking via registro (programas podem ler estes valores)
Set-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-0b0642e5e2f0\0cc5b647-c1df-4637-891a-dec35c318583' 'ValueMax' 100 'DWord'
Set-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-0b0642e5e2f0\0cc5b647-c1df-4637-891a-dec35c318583' 'ValueMin' 100 'DWord'

# 4. MOUSE E TECLADO
Write-Step 'Aplicando configuracao 1:1 de mouse e filas de entrada...'
Set-RegValue 'HKCU:\Control Panel\Mouse' 'MouseSpeed' '0' 'String'
Set-RegValue 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' '0' 'String'
Set-RegValue 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' '0' 'String'
Set-RegValue 'HKCU:\Control Panel\Mouse' 'MouseSensitivity' '10' 'String'
Set-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters' 'MouseDataQueueSize' 256 'DWord'
Set-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters' 'KeyboardDataQueueSize' 256 'DWord'

# 5. GAMING, DVR, UI E GPU
Write-Step 'Otimizando Windows Gaming, DVR e HAGS...'
Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0 'DWord'
Set-RegValue 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0 'DWord'
Set-RegValue 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1 'DWord'
Set-RegValue 'HKCU:\Software\Microsoft\GameBar' 'UseNexusForGameBarEnabled' 0 'DWord'
Set-RegValue 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1 'DWord'
Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 0 'DWord'
Set-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\GameDVR' 'AllowGameDVR' 0 'DWord'
Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0 'DWord'
Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings' 'NOC_GLOBAL_SETTING_ALLOW_TOASTS_ABOVE_LOCK' 0 'DWord'
Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications' 'ToastEnabled' 0 'DWord'
Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled' 1 'DWord'
Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-310093Enabled' 0 'DWord'
Set-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2 'DWord'
Set-RegValue 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\System' 'AllowGameMode' 1 'DWord'

# 6. REDE
Write-Step 'Otimizando latencia de rede e DNS Cloudflare...'
try {
    Set-DnsClientServerAddress -InterfaceIndex (Get-NetAdapter | Where-Object Status -eq 'Up').ifIndex -ServerAddresses ('1.1.1.1','1.0.0.1') -ErrorAction SilentlyContinue
    Write-Ok 'DNS configurado para Cloudflare nas interfaces ativas.'
} catch {
    Write-Warn ('Falha ao configurar DNS: ' + $_.Exception.Message)
}
try {
    ipconfig.exe /flushdns | Out-Null
    Clear-DnsClientCache
    Write-Ok 'Cache DNS limpo.'
} catch { Write-Warn 'Falha ao limpar parte do cache DNS.' }

$tcpInterfaces = Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces' -ErrorAction SilentlyContinue
foreach ($iface in $tcpInterfaces) {
    Set-RegValue $iface.PSPath 'TcpAckFrequency' 1 'DWord'
    Set-RegValue $iface.PSPath 'TCPNoDelay' 1 'DWord'
}
Set-RegValue 'HKLM:\SOFTWARE\Microsoft\MSMQ\Parameters' 'TCPNoDelay' 1 'DWord'

# 7. DEBLOAT SEGURO
Write-Step 'Removendo bloatwares nativos sem afetar Store/Update/anti-cheats...'
$RemovePatterns = @(
    '*BingNews*','*BingWeather*','*Cortana*','*MicrosoftSolitaireCollection*',
    '*Microsoft3DViewer*','*Clipchamp*','*Getstarted*','*Todos*','*People*',
    '*WindowsFeedbackHub*','*WindowsMaps*','*ZuneMusic*','*ZuneVideo*',
    '*549981C3F5F10*','*MSPaint*','*MixedReality.Portal*','*GetHelp*',
    '*Office.OneNote*','*SkypeApp*','*BingSearch*','*WindowsCommunicationsApps*'
)
foreach ($pattern in $RemovePatterns) {
    try {
        $packages = Get-AppxPackage -AllUsers -Name $pattern -ErrorAction SilentlyContinue
        foreach ($package in $packages) {
            Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction SilentlyContinue
            Write-Host ('  - Removido: ' + $package.Name) -ForegroundColor DarkGray
        }
        $provisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like $pattern }
        foreach ($package in $provisioned) {
            Remove-AppxProvisionedPackage -Online -PackageName $package.PackageName -ErrorAction SilentlyContinue | Out-Null
        }
    } catch {
        Write-Warn ('Pacote ignorado/ja ausente: ' + $pattern)
    }
}

# 8. PRECONFIGURACAO CS2
Write-Step 'Criando prioridade alta para cs2.exe...'
Set-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\cs2.exe\PerfOptions' 'CpuPriorityClass' 3 'DWord'

# 9. FINALIZADOR CS2 NA AREA DE TRABALHO
Write-Step 'Criando ferramentas automaticas para finalizar o CS2 apos o download...'
$FinalizerPs1 = Join-Path $Desktop 'Finalizar_CS2.ps1'
$FinalizerBat = Join-Path $Desktop 'Finalizar_CS2.bat'

$Autoexec = @'
// Autoexec competitiva gerada automaticamente
con_enable 1
fps_max 0
cl_autohelp 0
gameinstructor_enable 0
cl_showloadout 1
rate 1000000
cl_updaterate_mp 128
cl_cmdrate 128
cl_interp 0
cl_interp_ratio 1
cl_bob_lower_amt 5
cl_bobamt_lat 0.1
cl_bobamt_vert 0.1
cl_bobcycle 0.98
r_drawtracers_firstperson 1
mm_dedicated_search_maxping 50
'@

<# Template incorporado desativado para evitar here-strings aninhadas.
$FinalizerScript = @'
#Requires -Version 5.1
[CmdletBinding()] param()
$Desktop = [Environment]::GetFolderPath('Desktop')
$Log = Join-Path $Desktop 'log_finalizar_cs2.txt'
Start-Transcript -Path $Log -Append -Force | Out-Null
Write-Host '=== Finalizador automatico do CS2 ===' -ForegroundColor Cyan

$Roots = @()
Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object { $Roots += $_.DeviceID }
$Roots += 'C:'
$Roots = $Roots | Select-Object -Unique

$LibraryPaths = New-Object System.Collections.Generic.List[string]
foreach ($root in $Roots) {
    $steamRoot = Join-Path $root 'Steam'
    $steamApp = Join-Path $root 'Program Files (x86)\Steam'
    foreach ($candidate in @($steamRoot,$steamApp)) {
        if (Test-Path $candidate) { [void]$LibraryPaths.Add($candidate) }
    }
}

try {
    $steamPath = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -Name SteamPath -ErrorAction Stop).SteamPath
    if ($steamPath) { [void]$LibraryPaths.Add($steamPath) }
} catch {}

foreach ($steamLib in @($LibraryPaths)) {
    $libraryFile = Join-Path $steamLib 'steamapps\libraryfolders.vdf'
    if (Test-Path $libraryFile) {
        $text = Get-Content $libraryFile -Raw
        $matches = [regex]::Matches($text, '"path"\s*"([^"]+)"','IgnoreCase')
        foreach ($match in $matches) {
            $path = $match.Groups[1].Value.Replace('\\','\')
            if (Test-Path $path) { [void]$LibraryPaths.Add($path) }
        }
    }
}

$LibraryPaths = $LibraryPaths | Select-Object -Unique
$CS2Exe = $null
$CfgDir = $null
foreach ($library in $LibraryPaths) {
    $exe1 = Join-Path $library 'steamapps\common\Counter-Strike Global Offensive\game\bin\win64\cs2.exe'
    $cfg1 = Join-Path $library 'steamapps\common\Counter-Strike Global Offensive\game\csgo\cfg'
    if (Test-Path $exe1) { $CS2Exe = $exe1; $CfgDir = $cfg1; break }

    $exe2 = Join-Path $library 'steamapps\common\Counter-Strike Global Offensive\game\bin\win64\cs2.exe'
    if (Test-Path $exe2) { $CS2Exe = $exe2; $CfgDir = Split-Path $exe2 -Parent | Split-Path -Parent | Split-Path -Parent | ForEach-Object { Join-Path $_ 'csgo\cfg' }; break }
}

if (-not $CS2Exe) {
    foreach ($root in $Roots) {
        $candidate = Get-ChildItem -LiteralPath $root -Filter cs2.exe -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -like '*Counter-Strike Global Offensive*\game\bin\win64\cs2.exe' } |
            Select-Object -First 1
        if ($candidate) {
            $CS2Exe = $candidate.FullName
            $gameDir = $candidate.Directory.FullName | Split-Path -Parent | Split-Path -Parent
            $CfgDir = Join-Path $gameDir 'csgo\cfg'
            break
        }
    }
}

if (-not $CS2Exe) {
    Write-Host '[AGUARDANDO] CS2 ainda nao encontrado. Execute novamente apos concluir o download.' -ForegroundColor Yellow
    Stop-Transcript | Out-Null
    exit 1
}

New-Item -ItemType Directory -Path $CfgDir -Force | Out-Null
$AutoexecText = @'
AUTOEXEC_CONTENT
'@
[System.IO.File]::WriteAllText((Join-Path $CfgDir 'autoexec.cfg'), $AutoexecText, [System.Text.UTF8Encoding]::new($false))
Write-Host ('[OK] Autoexec criada: ' + (Join-Path $CfgDir 'autoexec.cfg')) -ForegroundColor Green

# Compatibilidade: desativa Otimizacoes de Tela Inteira
try {
    $layers = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
    if (-not (Test-Path $layers)) { New-Item -Path $layers -Force | Out-Null }
    $current = (Get-ItemProperty -LiteralPath $layers -Name $CS2Exe -ErrorAction SilentlyContinue).$CS2Exe
    $flags = @()
    if ($current) { $flags = @($current -split ' ' | Where-Object { $_ }) }
    $flags = @($flags | Where-Object { $_ -ne 'DISABLEDXMAXIMIZEDWINDOWEDMODE' })
    $flags += '~ DISABLEDXMAXIMIZEDWINDOWEDMODE'
    Set-ItemProperty -LiteralPath $layers -Name $CS2Exe -Value ($flags -join ' ') -Type String
    Write-Host '[OK] Otimizacao de tela inteira desativada.' -ForegroundColor Green
} catch {
    Write-Host ('[ERRO] Compatibilidade: ' + $_.Exception.Message) -ForegroundColor Red
}

# GPU de Alto Desempenho
try {
    $gpuKey = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
    if (-not (Test-Path $gpuKey)) { New-Item -Path $gpuKey -Force | Out-Null }
    Set-ItemProperty -LiteralPath $gpuKey -Name $CS2Exe -Value 'GpuPreference=2;' -Type String
    Write-Host '[OK] GPU de Alto Desempenho configurada.' -ForegroundColor Green
} catch {
    Write-Host ('[ERRO] GPU: ' + $_.Exception.Message) -ForegroundColor Red
}

# Alta prioridade de processo
try {
    $priorityKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\cs2.exe\PerfOptions'
    if (-not (Test-Path $priorityKey)) { New-Item -Path $priorityKey -Force | Out-Null }
    Set-ItemProperty -LiteralPath $priorityKey -Name 'CpuPriorityClass' -Value 3 -Type DWord
} catch {}

Write-Host 'Finalizacao concluida.' -ForegroundColor Green
Stop-Transcript | Out-Null
'@
#>

$templatePath = Join-Path $PSScriptRoot 'Finalizar_CS2.ps1.template'
if (Test-Path $templatePath) {
    $FinalizerScript = [System.IO.File]::ReadAllText($templatePath)
    $AutoexecBytes = [System.Text.Encoding]::UTF8.GetBytes($Autoexec)
    $AutoexecBase64 = [Convert]::ToBase64String($AutoexecBytes)
    $FinalizerScript = $FinalizerScript.Replace('__AUTOEXEC_BASE64__', $AutoexecBase64)
    [System.IO.File]::WriteAllText($FinalizerPs1, $FinalizerScript, [System.Text.UTF8Encoding]::new($false))
} else {
    Write-Warn ('Template do finalizador nao encontrado: ' + $templatePath)
}

$BatContent = "@echo off`r`nsetlocal`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$FinalizerPs1`"`r`n"
[System.IO.File]::WriteAllText($FinalizerBat, $BatContent, [System.Text.UTF8Encoding]::new($false))
Write-Ok ('Criado: ' + $FinalizerBat)

# Tarefa leve no logon: tenta finalizar automaticamente quando o CS2 estiver presente.
try {
    $taskName = 'Finalizar_CS2_Auto'
    $action = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument ('/d /c ""' + $FinalizerBat + '""')
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
    Write-Ok ('Tarefa agendada criada: ' + $taskName)
} catch {
    Write-Warn ('Tarefa agendada nao criada: ' + $_.Exception.Message)
}

# 10. RESUMO E REINICIO
Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host '                 OTIMIZACAO CONCLUIDA' -ForegroundColor Green
Write-Host ('Log salvo em: ' + $LogFile) -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green

for ($seconds = 15; $seconds -ge 1; $seconds--) {
    Write-Host ('Reiniciando automaticamente em ' + $seconds + ' segundo(s). Pressione Ctrl+C para cancelar.') -ForegroundColor Yellow
    try {
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.Modifiers -band [ConsoleModifiers]::Control -and $key.Key -eq [ConsoleKey]::C) {
                Write-Host 'Reinicio cancelado pelo usuario.' -ForegroundColor Cyan
                Stop-Transcript | Out-Null
                exit 0
            }
        }
    } catch {}
    Start-Sleep -Seconds 1
}

Stop-Transcript | Out-Null
Restart-Computer -Force
