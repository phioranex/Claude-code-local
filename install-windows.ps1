# PowerShell helper to download and run Ollama installer (run as Administrator)
# Usage (run in Administrator PowerShell):
#   Set-ExecutionPolicy Bypass -Scope Process -Force; .\install-windows.ps1

$installer = "$env:TEMP\OllamaSetup.exe"
Write-Host "Downloading Ollama installer to: $installer"
Invoke-WebRequest -Uri "https://ollama.com/download/OllamaSetup.exe" -OutFile $installer -UseBasicParsing
Write-Host "Running installer (will request elevation)..."
Start-Process -FilePath $installer -Wait -Verb RunAs
Write-Host "Installer finished. You may need to add Ollama to PATH or restart your shell."