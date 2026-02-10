# Claude Code — One-line Local Installer (Ollama + Models)

🎯 **Goal**: Provide a single one-line command to install Ollama, pull a code-focused model (default: `claude`) and configure a convenient `claude-code` wrapper that runs the model locally without any API keys.

---

## 🔧 Features

- Cross-platform detection (macOS, Linux; Windows instructions provided)
- Interactive installer with **Recommended** and **Custom** modes
  - **Recommended**: auto-detects GPU/VRAM and sets a sensible context size, pulls `claude`, creates wrapper and environment config
  - **Custom**: choose model name and context size yourself
- Creates `~/.local/bin/claude-code` wrapper which sets `OLLAMA_CONTEXT_LENGTH` and runs the model
- Idempotent (will skip installing Ollama if already present)

---

## ⚡ One-line installer

Paste this into your terminal to install (recommended: process substitution — safer than piping directly):

```bash
# Safer: process substitution (recommended)
bash <(curl -fsSL https://raw.githubusercontent.com/phioranex/Claude-code-local/main/install.sh) -- --yes --model claude --context 32768

# Old style: pipe to bash (still supported)
curl -fsSL https://raw.githubusercontent.com/phioranex/Claude-code-local/main/install.sh | bash
```

This runs interactively by default. For automated installs (CI or scripts) use the non-interactive flags:

```bash
# Non-interactive, recommended defaults (auto-detect context)
curl -fsSL https://raw.githubusercontent.com/phioranex/Claude-code-local/main/install.sh | bash -s -- --yes

# Non-interactive with explicit model and context
curl -fsSL https://raw.githubusercontent.com/phioranex/Claude-code-local/main/install.sh | bash -s -- --yes --model claude --context 32768

# Import a local GGUF model and create an Ollama model (non-interactive)
curl -fsSL https://raw.githubusercontent.com/phioranex/Claude-code-local/main/install.sh | bash -s -- --gguf /path/to/model.gguf --name mylocalmodel --yes
```

Supported flags:
- `--yes`, `--ci`, `--non-interactive`  : Skip prompts and proceed with sensible defaults
- `--model <name>`                       : Pre-select the model to use (default: `claude`)
- `--context <tokens>`                   : Pre-select the context window size
- `--gguf <path>`                        : Import a local GGUF file and automatically create an Ollama model
- `--name <model_name>`                  : Name to assign when creating a model from a GGUF file

> Tip: you can still run the script interactively; flags act as defaults or non-interactive overrides.

---

## ✅ Recommended mode behavior

- Detects available VRAM and chooses a default context:
  - < 24 GB VRAM => 4,096 tokens
  - 24–48 GB VRAM => 32,768 tokens
  - >= 48 GB VRAM => 262,144 tokens
- Pulls `claude` model via Ollama (`ollama pull claude`) and creates `claude-code` wrapper
- Writes `export OLLAMA_CONTEXT_LENGTH=...` into `~/.claudecode_env` and sources it from your shell rc (e.g. `~/.bashrc` / `~/.zshrc`)

---

## 🛠 Custom mode behavior

- You choose the model name as known by Ollama (for example: `claude`, `opencode`, `codex`, or any model listed in `ollama list`)
- You choose the context size
- Optional step to pull the model now

---

## Importing local GGUF models

You can import a local GGUF model file and create an Ollama model from it using the installer:

```bash
# Non-interactively import and create a model named 'mylocal'
curl -fsSL https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/install.sh | bash -s -- --gguf /path/to/model.gguf --name mylocal --yes
```

The installer copies the GGUF to a small working directory, generates a `Modelfile` with `FROM ./<your.gguf>` and runs `ollama create <name> -f Modelfile`.

If you prefer, you can manually create a `Modelfile` and run `ollama create` yourself.

---

## Usage examples

- Run the wrapper (created at `~/.local/bin/claude-code`):

```bash
claude-code "Summarize this repository"
```

- Run Ollama directly with a model (if you prefer):

```bash
OLLAMA_CONTEXT_LENGTH=32768 ollama run claude "Write me a unit test for X"
```

---

## Quickstart — Use Claude Code in your project ⚡

**Start the model**
- After installation, use the wrapper to run quick prompts immediately. Ollama will start the model on demand:

```bash
# Basic quick test
claude-code "Explain what this repo does in one paragraph"

# Override context for a single command
OLLAMA_CONTEXT_LENGTH=65536 claude-code "Open-source project README improvements"
```

**Common project workflows**

- Generate a commit message from staged changes:

```bash
git add -A
git diff --staged > /tmp/staged.diff
claude-code "Write a concise, conventional commit message for the following git diff:" < /tmp/staged.diff
# Copy the output into your commit, or automate via a small script
```

- Create unit tests for a file (example for Python):

```bash
# Pipe the source to the model and ask for pytest tests
cat src/my_module.py | claude-code "Write pytest unit tests for the following Python module:" 
```

- Ask for refactor or improvement suggestions:

```bash
cat src/important_file.go | claude-code "Suggest refactors and show a patch (unified diff) for the following Go file:" 
```

- Generate PR description from changes:

```bash
git diff --name-only HEAD~1 | claude-code "Create a pull request description summarizing the changed files and motivation:" 
```

**Editor & CI integration**

- VS Code: use the existing Ollama/Local LLM extensions (Open WebUI or/extensions that support Ollama) and point them at your local Ollama instance. Also, you can call `claude-code` from tasks or terminal inside the editor.

- Git hooks: create a `scripts/generate-commit-msg.sh` and use it from a `prepare-commit-msg` hook to auto-fill commit messages (keep manual review in the loop):

```bash
# scripts/generate-commit-msg.sh
#!/usr/bin/env bash
git diff --staged > /tmp/staged.diff
msg=$(claude-code "Write a concise commit message for the following staged changes:" < /tmp/staged.diff)
echo "$msg" > .git/COMMIT_EDITMSG
```

- CI / scripted usage: call the installer with `--yes` and then run `claude-code` in scripts. Use `--context` to set a larger context size when needed.

**Tips & troubleshooting**

- To see running models: `ollama ps`
- To list local models: `ollama list`
- If `claude-code` or `ollama` is not available immediately after running the installer, it is likely because your shell hasn't picked up the PATH change written to your shell rc. In your current shell run:

```bash
export PATH="$HOME/.local/bin:$PATH"
source ~/.claudecode_env
# or restart your shell with
exec $SHELL
```

- If a model pull failed with "pull model manifest: file does not exist":

  1. Start the Ollama server in the background:

  ```bash
  nohup ollama serve >/dev/null 2>&1 &
  ```

  2. Check available models and pull a supported one:

  ```bash
  ollama library | sed -n '1,40p'
  ollama pull <model-name>
  ```

  3. The installer now attempts to auto-select a fallback model from the library if your chosen model is not available. If you prefer a specific model, set `CLAUDE_MODEL` before running `claude-code`, e.g.:

  ```bash
  export CLAUDE_MODEL="gemma3"
  claude-code "Summarize my project"
  ```

  You can also override per-invocation:

  ```bash
  claude-code --model gemma3 "Write unit tests for file X"
  ```

- If a model fails to run or uses too much VRAM, reduce `OLLAMA_CONTEXT_LENGTH` or use a smaller model

---

---

## Notes & Troubleshooting ⚠️

- macOS: Homebrew is used when available and writable; if Homebrew is not writable (common on macOS with `/opt/homebrew` permissions), the installer will automatically download the Ollama darwin bundle and install the `ollama` binary into `~/.local/bin` (no sudo required). This avoids manual permission fixes and makes the installer fire-and-forget for most users.
- Linux: uses the official installer: `curl -fsSL https://ollama.com/install.sh | sh` (this is the safe, supported install path).
- Windows: the script will generate `install-windows.ps1` (PowerShell helper) and instruct you to run it as Administrator: `Set-ExecutionPolicy Bypass -Scope Process -Force; .\install-windows.ps1`. Alternatively, install from https://ollama.com/download or run the installer from WSL.
- If a model name fails to pull, check `ollama list` and `ollama library` or visit https://ollama.com/library for model names.
- The installer performs basic verification: it confirms the `ollama` binary is callable and checks `ollama list` to detect pulled/created models. If verification fails, follow the manual install instructions from https://ollama.com/download.

---

## Uninstall

If you need to remove the installed wrapper and environment:

```bash
# Interactive uninstall (asks whether to remove pulled models)
curl -fsSL https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/install.sh | bash -s -- --uninstall

# Non-interactive uninstall and also remove the named model
curl -fsSL https://raw.githubusercontent.com/phioranex/Claude-code-local/main/install.sh | bash -s -- --uninstall --remove-model --model claude
```

The uninstall command removes `~/.local/bin/claude-code`, `~/.claudecode_env`, shell rc references, and temporary GGUF working directories. If `--remove-model` is provided, the script will also attempt `ollama rm <model>` to remove the model from your local Ollama store.

---

Repository: https://github.com/phioranex/Claude-code-local

---

## Contributing & License

- PRs welcome — add support for more OS/package managers or models
- Include clear testing steps for each platform

License: MIT (add LICENSE if you want one explicitly)

---

If you'd like, I can:

1) Add automated end-to-end test scripts (CI) to validate installs and wrapper creation across platforms
2) Add a silent Windows installer path (improved PowerShell with checksum verification and unattended install)
3) Add conveniences like `--yes --gguf-remote <url>` to auto-download a GGUF, verify checksum, and create a model
4) Help publish a release and update the one-liner to point to the final `YOUR_USER/YOUR_REPO`

Pick an item and I'll implement it next. ✅
