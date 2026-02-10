# Claude Code Local

Easily set up local development tools for coding with an AI assistant. This script handles the installation of:

- [Ollama](https://ollama.ai) (runtime + models)
- GPT-OSS model (via Ollama)
- Claude Code CLI

## Install

Run this one-liner to install everything:

```bash
curl -fsSL https://raw.githubusercontent.com/phioranex/Claude-code-local/main/install.sh | bash
```

### Prerequisites

Ensure the following are installed on your system:

- **Docker:** Install from [Docker Docs](https://docs.docker.com/get-docker/)
- **Node.js:** Install from [Node.js download](https://nodejs.org/)
- **Python 3:** Install from [Python Downloads](https://www.python.org/downloads/)

The installer will verify these dependencies before proceeding.

## Tools Setup

### Ollama
- **What it does:** Enables local AI models runtime
- **Installed by:** This script
- **Model:** GPT-OSS (used by Claude Code CLI)

Commands:
- Test Ollama runtime:
  ```bash
  ollama chat gpt-oss
  ```

### Claude Code CLI
- **What it does:** Provides a coding assistant interface
- **Installed by:** pip

Command:
- Test CLI with GPT-OSS:
  ```bash
  claude-cli --model=gpt-oss 'Write a Python loop that iterates over a list.'
  ```

## Troubleshooting

If you run into issues:
1. **Dependencies not found:** Verify Docker, Node.js, and Python are installed.
2. **Model pull fails:** Ensure system resources (disk, RAM) are sufficient.

## License

This project is open-source under the [MIT License](./LICENSE).

## Author
[Phioranex](https://phioranex.com)