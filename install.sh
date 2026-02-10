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

# Default installation directory
INSTALL_DIR="/usr/local/claude-code-local"
STATE_DIR="$INSTALL_DIR/state"
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
            --install-dir)
                INSTALL_DIR="$2"
                STATE_DIR="$INSTALL_DIR/state"
                shift 2
                ;;
            --help|-h)
                echo "Install Claude Code Local"
                echo ""
                echo "Usage: install.sh [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --install-dir DIR   Specify custom installation directory (default: /usr/local/claude-code-local)"
                echo "  --help, -h          Show this help message"
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
    log_step "Configuring Ollama to use custom directory..."
    mkdir -p "$INSTALL_DIR/ollama"

    # Some ollama versions expose different commands. Check if 'daemon' is supported.
    if ollama --help 2>&1 | grep -q "daemon"; then
        ollama daemon --storage "$INSTALL_DIR/ollama" &
        sleep 2
        log_success "Ollama configured to use $INSTALL_DIR/ollama for model storage."
    else
        log_warning "'ollama daemon' command not available; skipping auto-start. Ensure Ollama is running and using $INSTALL_DIR/ollama as storage if required."
    fi
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

    log_step "Preparing installation directory and state dir..."
    mkdir -p "$INSTALL_DIR/claude-cli"
    mkdir -p "$STATE_DIR"

    log_step "Running official Claude Code bootstrap installer (no extra flags)..."
    # Ensure the installer uses our desired state directory by setting XDG_STATE_HOME.
    export XDG_STATE_HOME="$STATE_DIR"
    mkdir -p "$STATE_DIR"

    # Try the bootstrap installer (target: latest). If it fails due to permission errors,
    # we'll fall back to downloading the binary directly and invoking it with flags.
    if ! XDG_STATE_HOME="$STATE_DIR" curl -fsSL https://claude.ai/install.sh | bash -s -- latest; then
        log_warning "Bootstrap installer failed; attempting fallback: download binary and run with explicit flags..."

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

        # Run the binary install with explicit state dir and model
        if ! "$binary_path" install --state-dir "$STATE_DIR" --model gpt-oss; then
            log_error "Manual claude install failed."; exit 1
        fi

        # Provide installed binary into our install dir if available
        if [ -x "$HOME/.claude/claude" ]; then
            ln -sf "$HOME/.claude/claude" "$INSTALL_DIR/claude-cli/claude"
            export PATH="$INSTALL_DIR/claude-cli:$PATH"
            log_success "Linked claude binary into $INSTALL_DIR/claude-cli and updated PATH."
        fi
    fi

    if ! check_command claude; then
        log_warning "Claude CLI not found in PATH; checking common install locations..."
        if [ -x "$HOME/.local/bin/claude" ]; then
            ln -sf "$HOME/.local/bin/claude" "$INSTALL_DIR/claude-cli/claude"
            export PATH="$INSTALL_DIR/claude-cli:$PATH"
            log_success "Linked claude binary from ~/.local/bin into $INSTALL_DIR/claude-cli and updated PATH."
        elif [ -x "$HOME/.claude/claude" ]; then
            ln -sf "$HOME/.claude/claude" "$INSTALL_DIR/claude-cli/claude"
            export PATH="$INSTALL_DIR/claude-cli:$PATH"
            log_success "Linked claude binary from ~/.claude into $INSTALL_DIR/claude-cli and updated PATH."
        else
            log_error "Claude installation did not produce a usable 'claude' binary."
            exit 1
        fi
    fi

    log_step "Setting default model to gpt-oss (if supported by installed 'claude')..."
    if claude help install 2>&1 | grep -q -- '--model'; then
        claude install --model gpt-oss || log_warning "Failed to set model to gpt-oss (continue)."
    else
        log_warning "'claude install' doesn't accept --model; you may need to configure model manually."
    fi

    log_success "Claude Code CLI installed successfully in $INSTALL_DIR/claude-cli."
}

# Main setup
parse_arguments "$@"

# Ensure installation directory exists and is writable (try sudo if necessary)
if [ ! -d "$INSTALL_DIR" ]; then
    if ! mkdir -p "$INSTALL_DIR" 2>/dev/null; then
        log_warning "Cannot create $INSTALL_DIR as current user; attempting with sudo..."
        sudo mkdir -p "$INSTALL_DIR"
    fi
fi

# Recompute state dir in case --install-dir was provided
STATE_DIR="$INSTALL_DIR/state"

log_step "Starting installation for Claude Code Local."
log_step "Using installation directory: $INSTALL_DIR"

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
install_gpt_oss_model
install_claude_cli

log_step "Setup completed."
echo -e "\n${GREEN}🎉 All tools installed successfully! 🎉${NC}"

echo -e "${BOLD}Tools installed:${NC}"
echo -e "  - ${CYAN}Ollama${NC}"
echo -e "      ↳ Includes GPT-OSS model for Claude Code CLI."
echo -e "  - ${CYAN}Claude Code CLI${NC}"

echo -e "\n${BOLD}Custom installation directory:${NC} $INSTALL_DIR"

echo -e "\n${BOLD}Next steps:${NC}"
echo -e "  1. Test Ollama:         ${CYAN}ollama chat gpt-oss${NC}"
echo -e "  2. Test Claude CLI:     ${CYAN}claude --model=gpt-oss 'Write a Python loop that iterates over a list.'${NC}"
echo -e "\n💡 If 'claude' is not found, add one of these to your shell rc (e.g. ~/.zshrc):"
echo -e "  - ${CYAN}export PATH=\"$HOME/.local/bin:\$PATH\"${NC}  # if installed to ~/.local/bin"
echo -e "  - ${CYAN}export PATH=\"$INSTALL_DIR/claude-cli:\$PATH\"${NC}  # if linked into install dir"

echo -e "\n${YELLOW}Happy coding! 🚀${NC}"
