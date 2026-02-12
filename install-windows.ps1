# Claude Code Local - Windows installer (PowerShell)
# Usage (run in an elevated PowerShell when installers require admin):
#   Set-ExecutionPolicy Bypass -Scope Process -Force; .\install-windows.ps1

function Log-Step($m) { Write-Host "[STEP] $m" -ForegroundColor Cyan }
function Log-Success($m) { Write-Host "[OK]   $m" -ForegroundColor Green }
function Log-Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Log-Error($m) { Write-Host "[ERR]  $m" -ForegroundColor Red }

# Helper: run a command and return $true on success
function Try-Command($cmd, [switch]$NoThrow) {
    try {
        & $cmd 2>$null
        return $true
    } catch {
        if (-not $NoThrow) { return $false } else { return $false }
    }
}

# 1) Ensure Ollama is installed
Log-Step "Checking for 'ollama' in PATH..."
$ollama = Get-Command ollama -ErrorAction SilentlyContinue
if ($null -eq $ollama) {
    Log-Warn "Ollama not found — downloading installer..."
    $installer = Join-Path $env:TEMP "OllamaSetup.exe"
    $url = "https://ollama.com/download/OllamaSetup.exe"
    Log-Step "Downloading Ollama installer to: $installer"
    try {
        Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing -ErrorAction Stop
    } catch {
        Log-Error "Failed to download Ollama installer: $($_.Exception.Message)"
        exit 1
    }

    Log-Step "Running Ollama installer (may prompt for elevation)..."
    Start-Process -FilePath $installer -Wait -Verb RunAs
    # Refresh command lookup
    $ollama = Get-Command ollama -ErrorAction SilentlyContinue
    if ($null -ne $ollama) { Log-Success "Ollama installed." } else { Log-Warn "Ollama installer finished but 'ollama' not in PATH. You may need to restart your shell." }
} else {
    Log-Success "Ollama found: $($ollama.Path)"
}

# 2) Ensure Ollama API is running on 127.0.0.1:11434
function Test-OllamaApi() {
    try {
        $resp = Invoke-WebRequest -Uri 'http://127.0.0.1:11434/' -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

Log-Step "Checking Ollama API on http://127.0.0.1:11434..."
if (Test-OllamaApi) {
    Log-Success "Ollama API responding."
} else {
    Log-Warn "Ollama API not responding. Attempting to start Ollama (background)..."
    $ollamaCmd = Get-Command ollama -ErrorAction SilentlyContinue
    if ($null -ne $ollamaCmd) {
        try {
            $p = Start-Process -FilePath $ollamaCmd.Path -ArgumentList 'serve' -WindowStyle Hidden -PassThru
            Start-Sleep -Seconds 3
            if (Test-OllamaApi) { Log-Success "Started Ollama and API is responding." } else { Log-Warn "Started Ollama but API did not respond on port 11434." }
        } catch {
            Log-Warn "Failed to start Ollama automatically: $($_.Exception.Message)"
        }
    } else {
        Log-Error "Cannot start Ollama because 'ollama' command is not available."; exit 1
    }
}

# 3) Pull GPT-OSS model into Ollama
Log-Step "Pulling GPT-OSS model into Ollama (ollama pull gpt-oss)..."
try {
    & ollama pull gpt-oss
    Log-Success "gpt-oss model pulled into Ollama."
} catch {
    Log-Warn "Failed to pull gpt-oss model (it may already be present or Ollama not running): $($_.Exception.Message)"
}

# 4) Install Claude CLI — NOTE: official bootstrap supports Linux/mac only.
# Try to install via WSL if available, otherwise instruct the user.
$wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
if ($null -ne $wsl) {
    Log-Step "WSL detected — attempting to install Claude inside WSL (uses Linux installer)..."
    try {
        # Run bootstrap inside WSL (latest). If WSL lacks network/tools, this may fail.
        wsl.exe bash -lc "curl -fsSL https://claude.ai/install.sh | bash -s -- latest"
        Log-Success "Attempted Claude install inside WSL. If successful, use 'wsl claude' or configure WSL PATH access."
    } catch {
        Log-Warn "WSL install attempt failed: $($_.Exception.Message)"
    }
} else {
    Log-Warn "Windows native Claude installer not available. The official Claude bootstrap currently supports macOS/Linux only."
    Log-Warn "Options: install WSL and re-run this script, or follow manual Windows instructions at the Claude distribution page."
}

# 5) Set persistent ANTHROPIC environment variables for Windows user
Log-Step "Setting persistent ANTHROPIC environment variables for current user..."
try {
    setx ANTHROPIC_API_URL "http://127.0.0.1:11434" | Out-Null
    setx ANTHROPIC_API_BASE "http://127.0.0.1:11434" | Out-Null
    setx ANTHROPIC_MODEL "gpt-oss" | Out-Null
    Log-Success "Set ANTHROPIC_API_URL, ANTHROPIC_API_BASE, ANTHROPIC_MODEL for current user (requires new shell session)."
} catch {
    Log-Warn "Failed to set env vars with setx: $($_.Exception.Message)"
}

# 6) Ensure PowerShell profile contains PATH hint for user-local bins if needed
$profilePath = $PROFILE
Log-Step "Ensuring PowerShell profile ($profilePath) contains helpful PATH hint..."
if (-not (Test-Path $profilePath)) { New-Item -ItemType File -Path $profilePath -Force | Out-Null }
$profileContent = Get-Content -Path $profilePath -Raw -ErrorAction SilentlyContinue
$hint = "# Claude Code Local additions - ensure user-local bin is on PATH`n`$env:PATH = \"$env:USERPROFILE\\.local\\bin;\$env:PATH\""
if ($profileContent -notmatch "Claude Code Local additions") {
    Add-Content -Path $profilePath -Value "`n# Claude Code Local additions"
    Add-Content -Path $profilePath -Value "`$env:PATH = \"$env:USERPROFILE\\.local\\bin;`$env:PATH\""
    Add-Content -Path $profilePath -Value "# ANTHROPIC env vars (set in user environment)"
    Add-Content -Path $profilePath -Value "`# ANTHROPIC_API_URL is set for user environment, open a new shell to use it."
    Log-Success "Appended PATH hint to $profilePath"
} else {
    Log-Success "$profilePath already contains Claude Code Local additions."
}

# Final message
Write-Host "`nSetup finished. Next steps:" -ForegroundColor Cyan
Write-Host " - Open a new PowerShell to pick up environment changes." -ForegroundColor Yellow
Write-Host " - Verify Ollama: ollama chat gpt-oss" -ForegroundColor Yellow
Write-Host " - If you installed Claude in WSL: wsl claude --help" -ForegroundColor Yellow
Write-Host " - To launch Claude via Ollama (if you have a compatible model): ollama launch claude" -ForegroundColor Yellow

Write-Host "Happy coding!" -ForegroundColor Green
