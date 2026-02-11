#!/bin/bash

# Claude Code Local - One-line installer
#
# Usage:
# curl -fsSL https://raw.githubusercontent.com/phioranex/Claude-code-local/main/install.sh | bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Default behaviour: perform native installs (no custom install directory)
# The bootstrap installers will place binaries under user-local locations (e.g. ~/.local/bin)
# Helper functions
log_step() {
    echo -e "\n${BLUE}▶${NC} ${BOLD}$1${NC}"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

check_command() {
    if command -v "$1" &> /dev/null; then
        log_success "$1 found"
        return 0
    else
        log_warning "$1 not found"
        return 1
    fi
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                echo "Install Claude Code Local"
                echo ""
                echo "Usage: install.sh"
                echo ""
                echo "This script installs Ollama, pulls the gpt-oss model, and installs the Claude CLI natively."
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                exit 1
                ;;
        esac
    done
}

install_ollama() {
    log_step "Installing Ollama runtime..."
    if check_command ollama; then
        echo "Ollama is already installed."
        return
    fi
    # Install Ollama (Linux/Mac only)
    curl -fsSL https://ollama.ai/install.sh | bash
    log_success "Ollama installed successfully."
}

configure_ollama() {
    log_step "Configuring Ollama (native install)..."
    # Some ollama versions expose different commands. If 'daemon' is available, start it.
    if ollama --help 2>&1 | grep -q "daemon"; then
        ollama daemon &
        sleep 2
        log_success "Ollama daemon started (native)."
    else
        log_warning "'ollama daemon' command not available; skipping auto-start. Ensure Ollama is running."
    fi
}

ensure_ollama_running() {
    log_step "Checking Ollama server on 127.0.0.1:11434..."
    # Quick health check via curl
    if command -v curl >/dev/null 2>&1 && curl -sS http://127.0.0.1:11434/ >/dev/null 2>&1; then
        log_success "Ollama API is responding on 127.0.0.1:11434"
        return 0
    fi

    # Fallback: check for running process (Ollama app or binary)
    if pgrep -x Ollama >/dev/null 2>&1 || pgrep -f "\bollama\b" >/dev/null 2>&1; then
        log_success "Ollama process detected"
        return 0
    fi

    log_warning "Ollama not running — attempting to start it (background)..."
    # Try to start Ollama serve (native) and keep it detached
    if command -v ollama >/dev/null 2>&1; then
        if ollama --help 2>&1 | grep -q "serve"; then
            nohup ollama serve --port 11434 >/dev/null 2>&1 &
        else
            nohup ollama serve >/dev/null 2>&1 &
        fi
        sleep 3
        if command -v curl >/dev/null 2>&1 && curl -sS http://127.0.0.1:11434/ >/dev/null 2>&1; then
            log_success "Ollama started and is listening on 127.0.0.1:11434"
            return 0
        else
            log_warning "Attempted to start Ollama but it did not respond on port 11434."
            return 1
        fi
    else
        log_error "'ollama' command not available; cannot start Ollama automatically."
        return 1
    fi
}

add_shell_exports() {
    # Determine rc file to modify
    RCFILE="$HOME/.bashrc"
    if [ -n "$SHELL" ] && echo "$SHELL" | grep -q "zsh"; then
        RCFILE="$HOME/.zshrc"
    fi

    log_step "Adding PATH and environment variables to $RCFILE (if missing)..."
    mkdir -p "$(dirname "$RCFILE")"

    add_line_if_missing() {
        local file="$1"; shift
        local line="$*"
        if ! grep -Fxq "$line" "$file" 2>/dev/null; then
            echo "$line" >> "$file"
        fi
    }

    add_line_if_missing "$RCFILE" "# Claude Code Local additions"
    add_line_if_missing "$RCFILE" "export PATH=\"$HOME/.local/bin:\$PATH\""
    add_line_if_missing "$RCFILE" "# Ollama / Claude CLI (Anthropic-compatible) settings"
    add_line_if_missing "$RCFILE" "export ANTHROPIC_API_URL=\"http://127.0.0.1:11434\""
    add_line_if_missing "$RCFILE" "export ANTHROPIC_API_BASE=\"http://127.0.0.1:11434\""
    add_line_if_missing "$RCFILE" "export ANTHROPIC_MODEL=\"gpt-oss\""

    # Export into current session as well
    export PATH="$HOME/.local/bin:$PATH"
    export ANTHROPIC_API_URL="http://127.0.0.1:11434"
    export ANTHROPIC_API_BASE="http://127.0.0.1:11434"
    export ANTHROPIC_MODEL="gpt-oss"

    log_success "Updated $RCFILE — restart your shell or source it to get changes."
}

install_gpt_oss_model() {
    log_step "Downloading GPT-OSS model in Ollama..."
    if ! check_command ollama; then
        log_error "Ollama is not installed. Please install it first."
        exit 1
    fi

    ollama pull gpt-oss
    log_success "GPT-OSS model installed successfully in Ollama."
}

install_claude_cli() {
    log_step "Installing Claude Code CLI..."
    if check_command claude; then
        echo "Claude Code CLI is already installed."
        return
    fi

    log_step "Preparing user-local directories and running Claude bootstrap installer..."

    # Ensure user-local state and bin directories exist
    mkdir -p "$HOME/.local/state" "$HOME/.local/bin" 2>/dev/null || true

    # If the state directory is not writable by the current user, attempt to fix ownership
    if [ ! -w "$HOME/.local/state" ]; then
        log_warning "$HOME/.local/state is not writable by the current user. Attempting to fix ownership with sudo..."
        if command -v sudo >/dev/null 2>&1; then
            sudo chown -R "$(id -u):$(id -g)" "$HOME/.local" || {
                log_error "Failed to chown $HOME/.local. Fix permissions manually and re-run the installer.";
                exit 1
            }
            mkdir -p "$HOME/.local/state" "$HOME/.local/bin" || {
                log_error "Failed to create $HOME/.local/state after fixing ownership."
                exit 1
            }
            log_success "Fixed ownership of $HOME/.local and created required dirs."
        else
            log_error "$HOME/.local/state is not writable and sudo is not available. Fix permissions manually and re-run.";
            exit 1
        fi
    fi

    # Try the bootstrap installer (target: latest). If it fails, fall back to downloading
    # the platform binary and running its installer.
    if ! curl -fsSL https://claude.ai/install.sh | bash -s -- latest; then
        log_warning "Bootstrap installer failed; attempting fallback: download binary and run installer..."

        TMPDIR=$(mktemp -d)
        trap 'rm -rf "$TMPDIR"' EXIT

        # Download the bootstrap to inspect paths and find the correct binary. Reuse the bootstrap's logic
        # by downloading the 'latest' version string and manifest, similar to the official script.
        GCS_BUCKET="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"
        mkdir -p "$TMPDIR/downloads"
        version=$(curl -fsSL "$GCS_BUCKET/latest") || { log_error "Failed to fetch latest version manifest."; exit 1; }
        manifest_json=$(curl -fsSL "$GCS_BUCKET/$version/manifest.json") || { log_error "Failed to fetch manifest.json."; exit 1; }

        # Determine platform (simple heuristic)
        case "$(uname -s)" in
            Darwin) os="darwin" ;;
            Linux) os="linux" ;;
            *) log_error "Unsupported OS for manual install"; exit 1 ;;
        esac
        case "$(uname -m)" in
            x86_64|amd64) arch="x64" ;;
            arm64|aarch64) arch="arm64" ;;
            *) log_error "Unsupported architecture for manual install"; exit 1 ;;
        esac
        if [ "$os" = "linux" ]; then
            platform="linux-${arch}"
        else
            platform="${os}-${arch}"
        fi

        binary_path="$TMPDIR/claude"
        if ! curl -fsSL -o "$binary_path" "$GCS_BUCKET/$version/$platform/claude"; then
            log_error "Failed to download claude binary for $platform"; exit 1
        fi
        chmod +x "$binary_path"

        # Run the binary installer (no custom state dir) for the detected platform
        if ! "$binary_path" install latest; then
            log_error "Manual claude install failed."; exit 1
        fi

        # If claude was installed to ~/.local/bin, ensure current session can find it
        if [ -x "$HOME/.local/bin/claude" ]; then
            export PATH="$HOME/.local/bin:$PATH"
            log_success "Detected claude in ~/.local/bin and added to PATH for this session."
        fi
    fi
    if ! check_command claude; then
        log_warning "Claude CLI not found in PATH; checking common install locations..."
        if [ -x "$HOME/.local/bin/claude" ]; then
            export PATH="$HOME/.local/bin:$PATH"
            log_success "Added ~/.local/bin to PATH for this session. Add it to your shell rc to persist."
        elif [ -x "$HOME/.claude/claude" ]; then
            export PATH="$HOME/.claude:$PATH"
            log_success "Added ~/.claude to PATH for this session. Add it to your shell rc to persist."
        else
            log_error "Claude installation did not produce a usable 'claude' binary."
            exit 1
        fi
    fi

    # Ensure other shells can find 'claude' immediately: create /usr/local/bin/claude if missing
    if [ -x "$HOME/.local/bin/claude" ] && [ ! -e /usr/local/bin/claude ]; then
        log_step "Making 'claude' globally available by linking to /usr/local/bin/claude (may require sudo)..."
        if sudo ln -sf "$HOME/.local/bin/claude" /usr/local/bin/claude 2>/dev/null; then
            log_success "Created /usr/local/bin/claude -> $HOME/.local/bin/claude"
        else
            log_warning "Could not create /usr/local/bin/claude. To make 'claude' available run:\n  sudo ln -s $HOME/.local/bin/claude /usr/local/bin/claude\nor add ~/.local/bin to your PATH."
        fi
    fi

    log_step "Setting default model to gpt-oss (if supported by installed 'claude')..."
    if claude help install 2>&1 | grep -q -- '--model'; then
        claude install --model gpt-oss || log_warning "Failed to set model to gpt-oss (continue)."
    else
        log_warning "'claude install' doesn't accept --model; you may need to configure model manually."
    fi

    log_success "Claude Code CLI installed successfully (native)."
}

# Main setup
parse_arguments "$@"

log_step "Starting installation for Claude Code Local (native installs)."

# Install prerequisites
log_step "Ensuring required dependencies (Docker, Node.js, Python)..."
if ! check_command docker; then
    log_error "Docker is required but not installed. Install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! check_command node; then
    log_error "Node.js is required but not installed. Install Node.js: https://nodejs.org/"
    exit 1
fi

if ! check_command python3; then
    log_error "Python 3 is required but not installed. Install Python: https://www.python.org/downloads/"
    exit 1
fi

log_success "All dependencies are installed."

# Install components
install_ollama
configure_ollama
ensure_ollama_running || log_warning "Ollama check/start failed — continuing but model pull may fail."
install_gpt_oss_model
install_claude_cli

# Add PATH and ANTHROPIC environment exports to user's shell rc
add_shell_exports

log_step "Setup completed."
echo -e "\n${GREEN}🎉 All tools installed successfully! 🎉${NC}"

echo -e "${BOLD}Tools installed:${NC}"
echo -e "  - ${CYAN}Ollama${NC}"
echo -e "      ↳ Includes GPT-OSS model for Claude Code CLI."
echo -e "  - ${CYAN}Claude Code CLI${NC}"

echo -e "\n${BOLD}Next steps:${NC}"
echo -e "  1. Test Ollama:         ${CYAN}ollama chat gpt-oss${NC}"
echo -e "  2. Test Claude CLI:     ${CYAN}claude --model=gpt-oss 'Write a Python loop that iterates over a list.'${NC}"
echo -e "  3. Launch Claude via Ollama: ${CYAN}ollama launch claude${NC}"
echo -e "\n💡 If 'claude' is not found, ensure ~/.local/bin is on your PATH (add to ~/.zshrc):"
echo -e "  - ${CYAN}export PATH=\"$HOME/.local/bin:\$PATH\"${NC}"

echo -e "\n${YELLOW}Happy coding! 🚀${NC}"
