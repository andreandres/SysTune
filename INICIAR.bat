@echo off
setlocal EnableExtensions

REM Contorna a ExecutionPolicy e solicita privilegios administrativos uma unica vez.
where powershell.exe >nul 2>&1 || (
    echo ERRO: PowerShell nao foi encontrado.
    pause
    exit /b 1
)

net session >nul 2>&1
if errorlevel 1 (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','%~dp0otimizar_cs2.ps1' -Verb RunAs -WindowStyle Normal"
    exit /b
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0otimizar_cs2.ps1"
exit /b %errorlevel%
