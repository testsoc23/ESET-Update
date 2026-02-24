# App Updater (Chocolatey / WinGet)

Script PowerShell para actualizar aplicaciones automáticamente en endpoints Windows
a través de *ESET PROTECT (Run Command Task)*.

El script detecta el sistema operativo y actúa de la siguiente manera:

- *Windows 7 / 8 / 8.1*
  - Instala Chocolatey si no está presente
  - Ejecuta choco upgrade all -y en modo silencioso

- *Windows 10 / 11*
  - Verifica disponibilidad de WinGet
  - Intenta reparar/instalar WinGet si es necesario
  - Ejecuta winget upgrade --all --silent aceptando acuerdos automáticamente

---

## Objetivo

Permitir la actualización masiva de software en equipos donde:
- Los usuarios no son administradores
- La ejecución debe realizarse como *LocalSystem*
- No debe requerir interacción del usuario
- Debe minimizar ventanas o prompts

---

## Requisitos

- Windows 7, 8, 8.1, 10 u 11
- PowerShell 5.1 o superior
- Acceso a internet para:
  - Chocolatey
  - WinGet
  - GitHub (si se descarga el script desde allí)

---

## ⚙️ Ejecución desde ESET PROTECT

Crear una tarea:

*Client Task → Run Command*

Comando:

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p='C:\ESET-AppUpdate\update.ps1'; New-Item -ItemType Directory -Path (Split-Path $p) -Force | Out-Null; Invoke-WebRequest -UseBasicParsing -Uri 'RAW_URL_AQUI' -OutFile $p; powershell.exe -NoProfile -ExecutionPolicy Bypass -File $p"
