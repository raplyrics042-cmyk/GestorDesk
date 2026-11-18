if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm https://raw.githubusercontent.com/TU_USUARIO/TU_REPOSITORIO/main/GestorAnyDesk.ps1 | iex`""
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$userPath = "$env:APPDATA\AnyDesk"
$sysPath = "$env:ProgramData\AnyDesk"
$backupRoot = "$env:USERPROFILE\Desktop\RespaldoAnyDesk"

function Write-Log($msg) {
    $txtLog.AppendText("[$(Get-Date -Format 'HH:mm:ss')] $msg`r`n")
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
    Update-Backups
}

function Restore-AnyDesk {
    if (-not $lstBackups.SelectedItem) {
        [System.Windows.Forms.MessageBox]::Show("Selecciona un respaldo de la lista.", "Aviso") | Out-Null
        return
    }
    $src = Join-Path $backupRoot $lstBackups.SelectedItem
    Stop-AnyDesk
    if (Test-Path "$src\user") { Copy-Item "$src\user\*" $userPath -Force }
    if (Test-Path "$src\system") { Copy-Item "$src\system\*" $sysPath -Force }
    Write-Log "Restaurado: $($lstBackups.SelectedItem)"
    Start-AnyDesk
    Start-Sleep -Seconds 2
    $lblId.Text = "ID actual: $(Get-AnyDeskId)"
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
    $lblId.Text = "ID actual: $(Get-AnyDeskId)"
}

function Update-Backups {
    $lstBackups.Items.Clear()
    if (Test-Path $backupRoot) {
        Get-ChildItem $backupRoot -Directory | Sort-Object Name -Descending | ForEach-Object { [void]$lstBackups.Items.Add($_.Name) }
    }
}

function New-Button($text, $x, $y, $color, $action) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.Location = New-Object System.Drawing.Point($x, $y)
    $b.Size = New-Object System.Drawing.Size(150, 38)
    $b.FlatStyle = "Flat"
    $b.FlatAppearance.BorderSize = 0
    $b.BackColor = $color
    $b.ForeColor = [System.Drawing.Color]::White
    $b.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $b.Cursor = "Hand"
    $b.Add_Click($action)
    return $b
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Gestor AnyDesk"
$form.Size = New-Object System.Drawing.Size(520, 560)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 250)
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "Gestor AnyDesk"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = [System.Drawing.Color]::FromArgb(30, 41, 59)
$lblTitle.Location = New-Object System.Drawing.Point(20, 15)
$lblTitle.AutoSize = $true

$lblId = New-Object System.Windows.Forms.Label
$lblId.Text = "ID actual: $(Get-AnyDeskId)"
$lblId.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$lblId.ForeColor = [System.Drawing.Color]::FromArgb(220, 38, 38)
$lblId.Location = New-Object System.Drawing.Point(22, 58)
$lblId.AutoSize = $true

$btnBackup = New-Button "Respaldar" 20 95 ([System.Drawing.Color]::FromArgb(37, 99, 235)) { Backup-AnyDesk }
$btnRestore = New-Button "Restaurar" 185 95 ([System.Drawing.Color]::FromArgb(22, 163, 74)) { Restore-AnyDesk }
$btnClean = New-Button "Limpieza Profunda" 350 95 ([System.Drawing.Color]::FromArgb(217, 119, 6)) { Clear-Traces }

$lblList = New-Object System.Windows.Forms.Label
$lblList.Text = "Respaldos disponibles"
$lblList.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$lblList.Location = New-Object System.Drawing.Point(20, 150)
$lblList.AutoSize = $true

$lstBackups = New-Object System.Windows.Forms.ListBox
$lstBackups.Location = New-Object System.Drawing.Point(20, 175)
$lstBackups.Size = New-Object System.Drawing.Size(480, 110)
$lstBackups.Font = New-Object System.Drawing.Font("Consolas", 10)

$lblLog = New-Object System.Windows.Forms.Label
$lblLog.Text = "Actividad"
$lblLog.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$lblLog.Location = New-Object System.Drawing.Point(20, 300)
$lblLog.AutoSize = $true

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Multiline = $true
$txtLog.ReadOnly = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.Location = New-Object System.Drawing.Point(20, 325)
$txtLog.Size = New-Object System.Drawing.Size(480, 185)
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 9)
$txtLog.BackColor = [System.Drawing.Color]::White

$form.Controls.AddRange(@($lblTitle, $lblId, $btnBackup, $btnRestore, $btnClean, $lblList, $lstBackups, $lblLog, $txtLog))

Update-Backups
Write-Log "Listo. Tu ID es $(Get-AnyDeskId)"
[void]$form.ShowDialog()