if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$userPath = "$env:APPDATA\AnyDesk"
$sysPath = "$env:ProgramData\AnyDesk"
$backupRoot = "$env:USERPROFILE\Desktop\RespaldoAnyDesk"

function Write-Log($msg) {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $msg"
}

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

function Get-Backups {
    if (Test-Path $backupRoot) {
        return @(Get-ChildItem $backupRoot -Directory | Sort-Object Name -Descending | ForEach-Object { $_.Name })
    }
    return @()
}

function Backup-AnyDesk {
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
    Write-Log "Respaldo creado en: $dest"
    Start-AnyDesk
}

function Restore-AnyDesk {
    $backups = Get-Backups
    if ($backups.Count -eq 0) {
        Write-Log "No hay respaldos disponibles."
        return
    }
    Write-Host ""
    Write-Host "Respaldos disponibles:"
    for ($i = 0; $i -lt $backups.Count; $i++) {
        Write-Host "  [$($i + 1)] $($backups[$i])"
    }
    $sel = Read-Host "Numero de respaldo a restaurar (Enter para cancelar)"
    if ([string]::IsNullOrWhiteSpace($sel)) { return }
    $idx = 0
    if (-not [int]::TryParse($sel, [ref]$idx) -or $idx -lt 1 -or $idx -gt $backups.Count) {
        Write-Log "Seleccion invalida."
        return
    }
    $name = $backups[$idx - 1]
    $src = Join-Path $backupRoot $name
    Stop-AnyDesk
    if (Test-Path "$src\user") { Copy-Item "$src\user\*" $userPath -Force }
    if (Test-Path "$src\system") { Copy-Item "$src\system\*" $sysPath -Force }
    Write-Log "Restaurado: $name"
    Start-AnyDesk
    Start-Sleep -Seconds 2
    Write-Log "ID actual: $(Get-AnyDeskId)"
}

function Clear-Traces {
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
    Write-Log "Limpieza profunda completada: $count archivo(s) eliminados."
    Start-AnyDesk
    Start-Sleep -Seconds 2
    Write-Log "ID actual: $(Get-AnyDeskId)"
}

while ($true) {
    Write-Host ""
    Write-Host "===== Gestor AnyDesk ====="
    Write-Host "ID actual: $(Get-AnyDeskId)"
    Write-Host "[1] Respaldar"
    Write-Host "[2] Restaurar"
    Write-Host "[3] Limpieza Profunda"
    Write-Host "[0] Salir"
    $op = Read-Host "Opcion"
    switch ($op) {
        "1" { Backup-AnyDesk }
        "2" { Restore-AnyDesk }
        "3" { Clear-Traces }
        "0" { break }
        default { Write-Log "Opcion invalida." }
    }
}
