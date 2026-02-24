# update.ps1 - ESET App Updater (Win7/8 -> Chocolatey, Win10/11 -> WinGet)
# Logs: C:\ESET-AppUpdate\update.log

$ErrorActionPreference = 'Stop'

$LogDir  = 'C:\ESET-AppUpdate'
$LogFile = Join-Path $LogDir 'update.log'
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

function Write-Log([string]$msg){
  $ts = (Get-Date).ToString('s')
  $line = "$ts  $msg"
  Add-Content -Path $LogFile -Value $line
  Write-Output $line
}

function Get-OsInfo {
  $os = Get-CimInstance Win32_OperatingSystem
  $ver = [version]$os.Version
  [pscustomobject]@{
    Caption = $os.Caption
    Version = $ver
    Build   = $os.BuildNumber
    Major   = $ver.Major
    Minor   = $ver.Minor
  }
}

function Ensure-Chocolatey {
  if (Get-Command choco.exe -ErrorAction SilentlyContinue) {
    Write-Log "Chocolatey ya está instalado."
    return
  }

  Write-Log "Chocolatey no encontrado. Instalando..."
  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  } catch {}

  Set-ExecutionPolicy Bypass -Scope Process -Force | Out-Null

  $installScript = Invoke-WebRequest -UseBasicParsing -Uri 'https://community.chocolatey.org/install.ps1'
  Invoke-Expression $installScript.Content

  if (-not (Get-Command choco.exe -ErrorAction SilentlyContinue)) {
    throw "Chocolatey no pudo instalarse."
  }

  # Evita confirmaciones globalmente (unattended)
  & choco feature enable -n=allowGlobalConfirmation --limit-output | Out-Null
  Write-Log "Chocolatey instalado y allowGlobalConfirmation habilitado."
}

function Run-ChocoUpgradeAll {
  Write-Log "Ejecutando: choco upgrade all -y --no-progress --limit-output"
  & choco upgrade all -y --no-progress --limit-output 2>&1 | ForEach-Object { Write-Log $_ }
  Write-Log "Chocolatey finalizó con exit code: $LASTEXITCODE"
}

function Ensure-WinGet {
  if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
    Write-Log "WinGet disponible en PATH."
    return
  }

  # Intentar localizar winget.exe en WindowsApps (si PATH no lo incluye)
  $wa = Join-Path $env:ProgramFiles 'WindowsApps'
  if (Test-Path $wa) {
    $wg = Get-ChildItem -Path $wa -Filter winget.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($wg) {
      Write-Log "WinGet encontrado en: $($wg.FullName)"
      $env:WINGET_PATH = $wg.FullName
      return
    }
  }

  Write-Log "WinGet no encontrado. Intentando reparar/instalar con Microsoft.WinGet.Client..."
  try { Install-PackageProvider -Name NuGet -Force | Out-Null } catch {}
  try { Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery -Scope AllUsers | Out-Null } catch {}

  if (Get-Module -ListAvailable -Name Microsoft.WinGet.Client) {
    try {
      Repair-WinGetPackageManager -Force -Latest | Out-Null
      Write-Log "Repair-WinGetPackageManager ejecutado."
    } catch {
      Write-Log "Repair-WinGetPackageManager falló: $($_.Exception.Message)"
    }
  }

  if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
    Write-Log "WinGet disponible luego de repair."
    return
  }

  # Fallback: instalar App Installer (incluye WinGet) desde GitHub Releases
  $tmp = Join-Path $env:TEMP 'Microsoft.DesktopAppInstaller.msixbundle'
  Write-Log "Descargando App Installer (msixbundle) desde GitHub: $tmp"
  Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle' -OutFile $tmp

  Write-Log "Instalando App Installer (Add-AppxPackage)..."
  Add-AppxPackage -Path $tmp

  if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
    Write-Log "WinGet disponible luego de instalar App Installer."
    return
  }

  # Reintentar búsqueda en WindowsApps
  if (Test-Path $wa) {
    $wg = Get-ChildItem -Path $wa -Filter winget.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($wg) {
      Write-Log "WinGet encontrado en WindowsApps: $($wg.FullName)"
      $env:WINGET_PATH = $wg.FullName
      return
    }
  }

  throw "WinGet no está disponible después de los intentos de reparación/instalación."
}

function Run-WinGetUpgradeAll {
  $wg = (Get-Command winget.exe -ErrorAction SilentlyContinue)?.Source
  if (-not $wg -and $env:WINGET_PATH) { $wg = $env:WINGET_PATH }
  if (-not $wg) { throw "No se pudo resolver la ruta a winget.exe" }

  $args = @(
    'upgrade','--all',
    '--silent',
    '--accept-package-agreements','--accept-source-agreements',
    '--disable-interactivity',
    '--include-unknown'
  )

  Write-Log ("Ejecutando: {0} {1}" -f $wg, ($args -join ' '))
  & $wg @args 2>&1 | ForEach-Object { Write-Log $_ }
  $exit = $LASTEXITCODE
  Write-Log "WinGet finalizó con exit code: $exit"
  exit $exit
}

# MAIN
$info = Get-OsInfo
Write-Log "OS: $($info.Caption)  Version: $($info.Version)  Build: $($info.Build)"

# Windows 7/8/8.1 => 6.1 / 6.2 / 6.3
if ($info.Major -eq 6 -and ($info.Minor -in 1,2,3)) {
  Ensure-Chocolatey
  Run-ChocoUpgradeAll
  exit 0
}

# Windows 10/11 => 10.0
if ($info.Major -eq 10) {
  Ensure-WinGet
  Run-WinGetUpgradeAll
}

throw "Sistema operativo no soportado: $($info.Version)"
