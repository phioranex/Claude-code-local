# Claude Code Local

[![YouTube](https://img.shields.io/badge/YouTube-@rvorine-red?style=for-the-badge&logo=youtube)](https://youtube.com/@rvorine)
[![Instagram](https://img.shields.io/badge/Instagram-lacopydepastel-E4405F?style=for-the-badge&logo=instagram)](https://instagram.com/lacopydepastel)

Easily set up local development tools for coding with an AI assistant. This script handles the installation of:

- [Ollama](https://ollama.ai) (runtime + models)
- GPT-OSS model (via Ollama)
- Claude Code CLI

## Install (macOS / Linux)

Run the installer (native installs):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/phioranex/Claude-code-local/main/install.sh)
```
## Install (Windows)

Use the PowerShell helper which downloads and runs the Ollama installer and attempts a WSL-based Claude install when possible:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; .\install-windows.ps1
```

Note: the official Claude bootstrap currently supports macOS/Linux; the Windows script will attempt a WSL install if WSL is present.

The script will:
- install Ollama if missing
- start or ensure Ollama is serving on `127.0.0.1:11434`
- pull `gpt-oss` into Ollama (this is a large download and may take time)
- install the `claude` CLI and add `~/.local/bin` to your shell rc (or create `/usr/local/bin/claude` via sudo)


## Prerequisites

- Node.js and Python 3 are recommended but not strictly required. The installer will warn if they're missing, but will continue.
- No Docker dependency is required for Ollama to operate in this workflow.

## Quick verification & common commands

- Verify Ollama is running and chat with the model:

```bash
ollama chat gpt-oss
```

- Check installed models:

```bash
ollama list
ollama show gpt-oss
```

- Verify `claude` CLI:

```bash
claude --help
```

- Launch Claude via Ollama (if the integration is available):

```bash
ollama launch claude
```

## Notes & Troubleshooting

- Model download size: `gpt-oss` is large (~13 GB). If the pull is interrupted, rerun the installer or run `ollama pull gpt-oss` and wait — the script now waits for the model to finish installing.
- If the installer reports the Ollama app started but `ollama` is not in your PATH, try opening a new shell or run:

```bash
# macOS: start the app bundle
open -a Ollama --args hidden
# or run the binary directly (if present)
/Applications/Ollama.app/Contents/Resources/ollama --help
```

- If `~/.local` is owned by root the script will attempt to fix ownership with `sudo`; if that fails you can fix manually:

```bash
sudo chown -R $(id -u):$(id -g) $HOME/.local
```

- On macOS the script will try to create a global symlink `/usr/local/bin/claude` (requires sudo) so `claude` is available to new shells immediately. If that fails, add `~/.local/bin` to your shell rc (e.g. `~/.zshrc`).

## Windows notes

- Windows native Claude install is not available in the official bootstrap. For a full native experience install WSL and rerun the installer inside WSL, or use the provided `install-windows.ps1` which attempts a WSL-based installation.

## License

This project is open-source under the MIT License.

## Author
[Phioranex](https://phioranex.com)
