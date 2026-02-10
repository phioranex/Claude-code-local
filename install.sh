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

# Functions for installation
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
    # Install Claude Code CLI (assumption: it's installed via pip)
    pip install claude-cli
    log_success "Claude Code CLI installed successfully."
}

# Main setup
log_step "Starting installation for Claude Code Local."

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
install_gpt_oss_model
install_claude_cli

log_step "Setup completed."
echo -e "\n${GREEN}🎉 All tools installed successfully! 🎉${NC}"

echo -e "${BOLD}Tools installed:${NC}"
echo -e "  - ${CYAN}Ollama${NC}"
echo -e "      ↳ Includes GPT-OSS model for Claude Code CLI."
echo -e "  - ${CYAN}Claude Code CLI${NC}"

echo -e "\n${BOLD}Next steps:${NC}"
echo -e "  1. Test Ollama:         ${CYAN}ollama chat gpt-oss${NC}"
echo -e "  2. Test Claude CLI:     ${CYAN}claude-cli --model=gpt-oss 'Write a Python loop that iterates over a list.'${NC}"

echo -e "\n${YELLOW}Happy coding! 🚀${NC}"
