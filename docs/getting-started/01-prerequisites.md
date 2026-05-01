---
title: "Prerequisites"
last-updated: 2026-04-08
related-files: [CLAUDE.md, .claude/settings.local.json]
---

# Prerequisites

## Required Software

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| **Claude Code CLI** | Latest (installed via `winget install Anthropic.ClaudeCode`) | Core runtime — all agents run through this |
| **Git** | 2.40+ | Version control, Git Bash shell on Windows |
| **Git Bash** | Bundled with Git for Windows | Shell environment for hooks and scripts |
| **Node.js** | 18+ | Required by Claude Code CLI |
| **jq** | 1.6+ | JSON parsing in hook scripts |

## Platform

Morpheus is developed and tested on **Windows 11 with Git Bash**. The hook scripts use bash syntax (`set -euo pipefail`, `sed`, `grep`). macOS and Linux should work with minimal changes, but Windows + Git Bash is the primary target.

## API Access

You need an **Anthropic API key** with access to:
- `claude-sonnet` — used by gatherer, builder, documenter agents
- `claude-opus` — used by planner, verifier, sme-assessor agents

Set the key in your environment:

```bash
export ANTHROPIC_API_KEY="your-key-here"
```

Or configure it through `claude auth` in the Claude Code CLI.

## Environment Variables

| Variable | Required | Purpose |
|----------|----------|---------|
| `ANTHROPIC_API_KEY` | Yes | API authentication |
| `CLAUDE_CODE_GIT_BASH_PATH` | Windows only | Path to Git Bash executable (e.g., `C:\Users\YOU\AppData\Local\Programs\Git\bin\bash.exe`) |
| `NODE_EXTRA_CA_CERTS` | Corporate environments | Path to corporate CA certificate if behind a proxy |

## Verify Your Setup

```bash
# Check Claude Code
claude --version

# Check Git Bash
bash --version

# Check Node
node --version

# Check jq
jq --version

# Verify API key is set
echo $ANTHROPIC_API_KEY | head -c 10
```

All commands should return version numbers without errors. If `claude` is not found, ensure the WinGet package path is in your system `PATH`.
