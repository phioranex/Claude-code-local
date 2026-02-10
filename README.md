# Claude Code Local

Easily set up local development tools for coding with an AI assistant. This script handles the installation of:

- [Ollama](https://ollama.ai) (runtime + models)
- GPT-OSS model (via Ollama)
- Claude Code CLI

## Install

Run this one-liner to install everything (adjust `--install-dir` if needed):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/phioranex/Claude-code-local/main/install.sh)
```

If you want to install on diffrent directory use following command:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/phioranex/Claude-code-local/main/install.sh) --install-dir /path/to/external/drive
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

### Custom Directory

If you wish to install GPT-OSS and Claude Code CLI to a custom location (e.g., external drive):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/phioranex/Claude-code-local/main/install.sh) --install-dir /Volumes/SSD/LLM
```

This will configure both tools to use the specified directory.

## Troubleshooting

1. **Dependencies not found:** Verify Docker, Node.js, and Python are installed.
2. **Model pull fails:** Ensure system resources (disk, RAM) are sufficient.
3. **Ollama error `unknown command "daemon"`:** Most likely a versioning issue. Run:
   ```bash
   ollama reset --storage /path/to/external/drive
   ```

## License

This project is open-source under the [MIT License](./LICENSE).

## Author
[Phioranex](https://phioranex.com)