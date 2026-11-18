if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm https://raw.githubusercontent.com/raplyrics042-cmyk/GestorDesk/refs/heads/main/GestorAnyDesk.ps1 | iex`""
    exit
}

$userPath = "$env:APPDATA\AnyDesk"
$sysPath = "$env:ProgramData\AnyDesk"
$backupRoot = "$env:USERPROFILE\Desktop\RespaldoAnyDesk"

function Get-AnyDeskId {
    $conf = Join-Path $sysPath "system.conf"
    if (Test-Path $conf) {
        $line = Select-String -Path $conf -Pattern "^ad\.anynet\.id=(\d+)" | Select-Object -First 1
        if ($line) { return $line.Matches[0].Groups[1].Value }
    }
    return "No detectado"
}

function Stop-AnyDesk {
    Get-Process -Name "AnyDesk" -ErrorAction SilentlyContinue | Stop-Process -Force
    Get-Service -Name "AnyDesk" -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Running" } | Stop-Service -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

function Start-AnyDesk {
    Get-Service -Name "AnyDesk" -ErrorAction SilentlyContinue | Where-Object { $_.Status -ne "Running" } | Start-Service -ErrorAction SilentlyContinue
    $exe = @("$env:ProgramFiles\AnyDesk\AnyDesk.exe", "${env:ProgramFiles(x86)}\AnyDesk\AnyDesk.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($exe) { Start-Process $exe }
}

function Backup-AnyDesk {
    Write-Host "`n[+] Respaldando configuracion y sesiones..." -ForegroundColor Cyan
    Stop-AnyDesk
    $dest = Join-Path $backupRoot (Get-Date -Format "yyyy-MM-dd_HH-mm-ss")
    New-Item -ItemType Directory -Path "$dest\user" -Force | Out-Null
    New-Item -ItemType Directory -Path "$dest\system" -Force | Out-Null
    $userFiles = @("user.conf", "service.conf", "system.conf") + (Get-ChildItem $userPath -Filter "*address*" -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    foreach ($f in $userFiles) {
        $p = Join-Path $userPath $f
        if (Test-Path $p) { Copy-Item $p "$dest\user" -Force }
    }
    foreach ($f in @("system.conf", "service.conf")) {
        $p = Join-Path $sysPath $f
        if (Test-Path $p) { Copy-Item $p "$dest\system" -Force }
    }
    Write-Host "[OK] Respaldo guardado en: $dest" -ForegroundColor Green
    Start-AnyDesk
    Pause
}

function Restore-AnyDesk {
    Write-Host "`n[+] Buscando respaldos disponibles en el Escritorio..." -ForegroundColor Cyan
    if (!(Test-Path $backupRoot)) {
        Write-Host "[!] No se encontro la carpeta de respaldos." -ForegroundColor Yellow
        Pause
        return
    }
    $backups = Get-ChildItem $backupRoot -Directory | Sort-Object Name -Descending
    if (!$backups) {
        Write-Host "[!] No hay respaldos guardados." -ForegroundColor Yellow
        Pause
        return
    }
    
    for ($i = 0; $i -lt $backups.Count; $i++) {
        Write-Host "[$i] $($backups[$i].Name)"
    }
    
    $sel = Read-Host "Selecciona el numero del respaldo a restaurar"
    if ($sel -match '^\d+$' -and $sel -lt $backups.Count) {
        $src = $backups[$sel].FullName
        Stop-AnyDesk
        if (Test-Path "$src\user") { Copy-Item "$src\user\*" $userPath -Force }
        if (Test-Path "$src\system") { Copy-Item "$src\system\*" $sysPath -Force }
        Write-Host "[OK] Restauracion completada." -ForegroundColor Green
        Start-AnyDesk
    } else {
        Write-Host "[X] Seleccion invalida." -ForegroundColor Red
    }
    Pause
}

function Clear-Traces {
    Write-Host "`n[+] Ejecutando limpieza profunda..." -ForegroundColor Cyan
    Stop-AnyDesk
    $count = 0
    $targets = @(
        "$userPath\service.conf",
        "$userPath\ad.trace",
        "$userPath\ad_svc.trace",
        "$sysPath\service.conf"
    )
    foreach ($file in $targets) {
        if (Test-Path $file) {
            Remove-Item $file -Force -ErrorAction SilentlyContinue
            $count++
        }
    }
    foreach ($base in @($userPath, $sysPath)) {
        Get-ChildItem $base -Include "*.trace", "*.log" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
            $count++
        }
    }
    Write-Host "[OK] Limpieza profunda completada: $count archivo(s) eliminados." -ForegroundColor Green
    Start-AnyDesk
    Start-Sleep -Seconds 2
    Write-Host "[INFO] ID actual: $(Get-AnyDeskId)" -ForegroundColor Yellow
    Pause
}

do {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "       GESTOR ANYDESK (MODO TEXTO)      " -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " ID Actual: $(Get-AnyDeskId)" -ForegroundColor Green
    Write-Host "----------------------------------------"
    Write-Host " [1] Respaldar sesiones y configuracion"
    Write-Host " [2] Restaurar un respaldo"
    Write-Host " [3] Limpieza Profunda (Anti-publicidad)"
    Write-Host " [4] Salir"
    Write-Host "========================================"
    $op = Read-Host "Selecciona una opcion"

    switch ($op) {
        '1' { Backup-AnyDesk }
        '2' { Restore-AnyDesk }
        '3' { Clear-Traces }
        '4' { exit }
    }
} while ($true)
