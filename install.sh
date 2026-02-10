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
    ollama daemon --storage "$INSTALL_DIR/ollama" &
    sleep 2
    log_success "Ollama configured to use $INSTALL_DIR/ollama for model storage."
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
    if check_command claude-cli; then
        echo "Claude Code CLI is already installed."
        return
    fi

    log_step "Installing Claude Code CLI in $INSTALL_DIR/claude-cli..."
    # mkdir -p "$INSTALL_DIR/claude-cli"
    # python3 -m venv "$INSTALL_DIR/claude-cli/venv"
    # source "$INSTALL_DIR/claude-cli/venv/bin/activate"
    # pip install claude-cli
    curl -fsSL https://claude.ai/install.sh | bash
    # deactivate

    log_success "Claude Code CLI installed successfully in $INSTALL_DIR/claude-cli."
}

# Main setup
parse_arguments "$@"

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
echo -e "  2. Test Claude CLI:     ${CYAN}source $INSTALL_DIR/claude-cli/venv/bin/activate && claude-cli --model=gpt-oss 'Write a Python loop that iterates over a list.'${NC}"

echo -e "\n${YELLOW}Happy coding! 🚀${NC}"
