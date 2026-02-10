#!/usr/bin/env bash
set -euo pipefail

# Simple cross-platform installer for "Claude Code" via Ollama
# Supports macOS, Linux, and provides instructions for Windows.
# Interactive Recommended/Custom modes, with non-interactive (--yes/--ci) support.
# Usage: curl -fsSL https://raw.githubusercontent.com/<user>/<repo>/main/install.sh | bash
# Non-interactive usage example:
#   curl -fsSL https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/install.sh | bash -s -- --yes --model claude --context 32768

REPO_URL="https://github.com/YOUR_USER/YOUR_REPO"
LOCAL_BIN="$HOME/.local/bin"
ENV_FILE="$HOME/.claudecode_env"

# Flags / defaults
NON_INTERACTIVE=0
UNINSTALL=0            # If set, perform uninstall actions and exit
REMOVE_MODEL=0         # If set (or --remove-model), also remove the pulled/created Ollama model
MODE_OVERRIDE=""
MODEL_FLAG=""
CTX_FLAG=""
GGUF_PATH=""
GGUF_NAME=""

command_exists() { command -v "$1" >/dev/null 2>&1; }

print_help() {
  cat <<'EOF'
Usage: install.sh [options]

Options:
  --yes, --ci, --non-interactive   Run with defaults (Recommended mode) and skip prompts
  --model <name>                   Pre-select a model (e.g., 'claude' or a created model name)
  --context <tokens>               Pre-select context size (e.g., 4096, 32768)
  --gguf <path>                    Import a local GGUF model and create an Ollama model from it
  --name <model_name>              Name to use when creating a model from a GGUF file
  --uninstall                      Remove installed wrapper and env; optionally remove model with --remove-model
  --remove-model                   When used with --uninstall, also remove the pulled/created Ollama model(s)
  --help                           Show this help message
EOF
} 

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|--ci|--non-interactive|-y) NON_INTERACTIVE=1; shift ;;
    --model) MODEL_FLAG="$2"; shift 2 ;;
    --context) CTX_FLAG="$2"; shift 2 ;;
    --gguf) GGUF_PATH="$2"; shift 2 ;;
    --name) GGUF_NAME="$2"; shift 2 ;;
    --uninstall) UNINSTALL=1; shift ;;
    --remove-model) REMOVE_MODEL=1; shift ;;
    --help) print_help; exit 0 ;;
    *) echo "Unknown argument: $1"; print_help; exit 1 ;;
  esac
done

# Respect environment CI variable (common in CI systems)
if [ "${CI:-}" = "true" ] || [ "${CI:-}" = "1" ]; then
  NON_INTERACTIVE=1
fi


detect_os() {
  UNAME=$(uname -s)
  case "$UNAME" in
    Darwin) echo "macos" ;;
    Linux) echo "linux" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *) echo "unknown" ;;
  esac
}

install_ollama_macos() {
  if command_exists brew; then
    echo "Installing Ollama with Homebrew..."
    brew install ollama || true
  else
    echo "Homebrew not found. Downloading Ollama release..."
    TMPDIR=$(mktemp -d)
    curl -L -o "$TMPDIR/ollama-darwin.tgz" "https://github.com/ollama/ollama/releases/latest/download/ollama-darwin.tgz"
    tar -xzf "$TMPDIR/ollama-darwin.tgz" -C "$TMPDIR"
    sudo mv "$TMPDIR/ollama" /usr/local/bin/ollama || sudo mv "$TMPDIR/ollama" /opt/homebrew/bin/ollama || true
    rm -rf "$TMPDIR"
  fi
}

install_ollama_linux() {
  echo "Running Ollama official installer (requires sudo for system install)..."
  curl -fsSL https://ollama.com/install.sh | sh
}

install_ollama_windows() {
  local psfile="$PWD/install-windows.ps1"
  cat > "$psfile" <<'PS'
# PowerShell script to download and run Ollama installer
$installer = "$env:TEMP\\OllamaSetup.exe"
Invoke-WebRequest -Uri "https://ollama.com/download/OllamaSetup.exe" -OutFile $installer
Start-Process -FilePath $installer -Wait -Verb RunAs
PS
  echo "Windows helper created: $psfile"
  echo "Run in an elevated PowerShell: Set-ExecutionPolicy Bypass -Scope Process -Force; .\install-windows.ps1"
}

suggest_context_by_vram() {
  # Try to detect GPU VRAM (nvidia-smi friendly). Fallback to default.
  local vram_gb=0
  if command_exists nvidia-smi; then
    vram_gb=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n1)
    vram_gb=$(( (vram_gb + 1023) / 1024 ))
  elif [ "$(uname -s)" = "Darwin" ]; then
    # macOS: try system_profiler
    vram_gb=$(system_profiler SPDisplaysDataType 2>/dev/null | awk '/VRAM/ {print $NF; exit}' | tr -d 'G') || true
  fi
  if [ -z "$vram_gb" ] || [ "$vram_gb" -lt 1 ]; then
    echo 4096
  elif [ "$vram_gb" -lt 24 ]; then
    echo 4096
  elif [ "$vram_gb" -lt 48 ]; then
    echo 32768
  else
    echo 262144
  fi
}

ensure_local_bin() {
  mkdir -p "$LOCAL_BIN"
  case ":$PATH:" in
    *":$LOCAL_BIN:"*) ;;
    *)
      echo "Adding $LOCAL_BIN to your PATH in shell rc..."
      if [ -n "${ZSH_VERSION-}" ]; then
        echo "export PATH=\"$LOCAL_BIN:\$PATH\"" >> "$HOME/.zshrc"
      elif [ -n "${BASH_VERSION-}" ]; then
        echo "export PATH=\"$LOCAL_BIN:\$PATH\"" >> "$HOME/.bashrc"
      else
        echo "export PATH=\"$LOCAL_BIN:\$PATH\"" >> "$HOME/.profile"
      fi
      export PATH="$LOCAL_BIN:$PATH"
      ;;
  esac
}

create_wrapper() {
  local model="$1"
  local ctx="$2"
  cat > "$LOCAL_BIN/claude-code" <<EOF
#!/usr/bin/env bash
# Wrapper to run chosen model with configured OLLAMA_CONTEXT_LENGTH
export OLLAMA_CONTEXT_LENGTH=$ctx
exec ollama run $model "\$@"
EOF
  chmod +x "$LOCAL_BIN/claude-code"
  echo "Created wrapper: $LOCAL_BIN/claude-code -> runs model '$model' with context=$ctx"
}

save_env() {
  local ctx="$1"
  cat > "$ENV_FILE" <<EOF
# claude-code local environment
export OLLAMA_CONTEXT_LENGTH=$ctx
EOF
  # source into current shell when possible
  if [ -n "${ZSH_VERSION-}" ]; then
    SHELL_RC="$HOME/.zshrc"
  elif [ -n "${BASH_VERSION-}" ]; then
    SHELL_RC="$HOME/.bashrc"
  else
    SHELL_RC="$HOME/.profile"
  fi
  if ! grep -q "source $ENV_FILE" "$SHELL_RC" 2>/dev/null; then
    echo "source $ENV_FILE" >> "$SHELL_RC"
    echo "Appended 'source $ENV_FILE' to $SHELL_RC"
  fi
}

pull_model() {
  local model="$1"
  echo "Pulling model: $model"
  ollama pull "$model" || true
}

# Remove a specific line (pattern) from a file safely
remove_line_from_file() {
  local file="$1" pattern="$2"
  if [ ! -f "$file" ]; then
    return 0
  fi
  local tmp
  tmp=$(mktemp)
  grep -v "$pattern" "$file" > "$tmp" || true
  mv "$tmp" "$file"
  echo "Cleaned up $file"
}

# Uninstall routine: removes wrapper, env, rc entries and optional model(s)
uninstall() {
  echo "Starting uninstall..."
  if [ -f "$LOCAL_BIN/claude-code" ]; then
    rm -f "$LOCAL_BIN/claude-code"
    echo "Removed wrapper: $LOCAL_BIN/claude-code"
  else
    echo "Wrapper not found: $LOCAL_BIN/claude-code"
  fi

  if [ -f "$ENV_FILE" ]; then
    rm -f "$ENV_FILE"
    echo "Removed environment file: $ENV_FILE"
  fi

  # Remove references from shell RC files
  for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
    remove_line_from_file "$rc" "source $ENV_FILE"
    remove_line_from_file "$rc" "export PATH=\"$LOCAL_BIN:\\$PATH\""
  done

  # Remove the GGUF working directory (if present)
  if [ -d "$PWD/claude-code-gguf" ]; then
    rm -rf "$PWD/claude-code-gguf"
    echo "Removed temporary GGUF working directory: $PWD/claude-code-gguf"
  fi

  # Optionally remove the model(s) via Ollama
  if [ "$REMOVE_MODEL" -eq 1 ]; then
    if command_exists ollama; then
      echo "Removing model(s) via 'ollama rm'..."
      if [ -n "$MODEL_FLAG" ]; then
        ollama rm "$MODEL_FLAG" || true
        echo "Requested removal of model: $MODEL_FLAG"
      else
        # Ask which model to remove
        echo "Models on this machine:"
        ollama list || true
        read -rp "Type the model name you want to remove (or leave blank to skip): " toremove
        if [ -n "$toremove" ]; then
          ollama rm "$toremove" || true
          echo "Removed model: $toremove"
        else
          echo "No model selected for removal."
        fi
      fi
    else
      echo "ollama not found; cannot remove model via ollama." >&2
    fi
  fi

  echo "Uninstall complete."
}

main() {
  OS=$(detect_os)
  echo "Detected OS: $OS"

  # If uninstall flag was provided, run uninstall and exit
  if [ "$UNINSTALL" -eq 1 ]; then
    uninstall
    exit 0
  fi

  if [ "$OS" = "windows" ]; then
    install_ollama_windows
    echo "Please run the generated PowerShell script in an elevated session to install Ollama, then re-run this installer (or run this script from WSL)."
    exit 0
  fi

  if ! command_exists ollama; then
    echo "Ollama not found, installing..."
    if [ "$OS" = "macos" ]; then
      install_ollama_macos
    elif [ "$OS" = "linux" ]; then
      install_ollama_linux
    else
      echo "Unsupported OS: $OS" >&2; exit 1
    fi

    if ! verify_ollama_installed; then
      echo "Ollama installation failed. Please install manually: https://ollama.com/download" >&2
      exit 1
    fi
  else
    echo "Ollama already installed: $(ollama --version 2>/dev/null || true)"
  fi

  # If GGUF import requested, handle it (creates an Ollama model locally)
  if [ -n "$GGUF_PATH" ]; then
    CREATED_MODEL=$(handle_gguf_import "$GGUF_PATH" "$GGUF_NAME") || { echo 'GGUF import failed.'; exit 1; }
    MODEL="$CREATED_MODEL"
  fi

  # Non-interactive flow
  if [ "$NON_INTERACTIVE" -eq 1 ]; then
    MODE=1
    if [ -n "$MODEL_FLAG" ]; then
      MODEL="$MODEL_FLAG"
    else
      MODEL=${MODEL:-claude}
    fi
    CTX=${CTX_FLAG:-$(suggest_context_by_vram)}
    echo "Non-interactive: model=$MODEL context=$CTX"
    echo "Proceeding with recommended automated install..."
    if [ -z "$GGUF_PATH" ]; then
      pull_model "$MODEL"
    fi
    ensure_local_bin
    create_wrapper "$MODEL" "$CTX"
    save_env "$CTX"

  else
    echo
    echo "Choose installation mode:"
    echo "  1) Recommended (auto-detect best context, install 'claude' and create wrapper)"
    echo "  2) Custom (choose model and context)"
    read -rp "Type 1 or 2 (default 1): " MODE
    MODE=${MODE:-1}

    if [ "$MODE" = "1" ]; then
      MODEL=${MODEL_FLAG:-claude}
      CTX=${CTX_FLAG:-$(suggest_context_by_vram)}
      echo "Recommended: model=$MODEL context=$CTX"
      read -rp "Proceed? [Y/n] " proceed
      proceed=${proceed:-Y}
      if [[ "$proceed" =~ ^[Yy] ]]; then
        echo "Pulling and setting up recommended configuration..."
        if [ -z "$GGUF_PATH" ]; then
          pull_model "$MODEL"
        fi
        ensure_local_bin
        create_wrapper "$MODEL" "$CTX"
        save_env "$CTX"
        echo "Ready! Use 'claude-code' to run the model (it will set the context for you)."
      else
        echo "Aborted by user."; exit 0
      fi
    else
      read -rp "Model name (as understood by Ollama, e.g. 'claude' or 'opencode') [${MODEL_FLAG:-claude}]: " MODEL
      MODEL=${MODEL:-${MODEL_FLAG:-claude}}
      read -rp "Context size in tokens (e.g. 4096, 32768) [auto]: " CTX
      if [ -z "$CTX" ]; then
        CTX=${CTX_FLAG:-$(suggest_context_by_vram)}
        echo "Auto-detected context: $CTX"
      fi
      read -rp "Pull the model now? [Y/n]: " pullnow
      pullnow=${pullnow:-Y}
      if [[ "$pullnow" =~ ^[Yy] ]]; then
        pull_model "$MODEL"
      fi
      ensure_local_bin
      create_wrapper "$MODEL" "$CTX"
      save_env "$CTX"
      echo "Custom install complete. Use 'claude-code' to run $MODEL with context=$CTX"
    fi
  fi

  # Verify model is available
  if ! verify_model_exists "${MODEL}"; then
    echo "Warning: model '${MODEL}' not present in 'ollama list'. It may still be creating/processing; check 'ollama list' or 'ollama show ${MODEL}'." >&2
  fi

  echo
  echo "Notes:"
  echo " - The installer created: $LOCAL_BIN/claude-code"
  echo " - OLLAMA_CONTEXT_LENGTH is set in: $ENV_FILE and will be sourced in your shell rc"
  echo " - To run examples: claude-code 'Summarize this file'"
  echo " - Non-interactive usage: curl ... | bash -s -- --yes --model claude --context 32768"
}

main "$@"
