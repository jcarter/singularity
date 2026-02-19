# Singularity

Obsidian-backed AI memory system. Provider hooks auto-save session summaries to your vault, and an MCP server gives your AI assistant search/read access to past sessions.

Works with **Claude Code**, **GitHub Copilot**, **Cursor**, and **Windsurf**.

## How It Works

1. **Session hooks** run when you start/end an AI coding session
2. Session summaries are saved as markdown notes in `Singularity/Sessions/`
3. An **MCP server** (mcp-obsidian) gives your AI assistant read/search access to those notes
4. Periodically **distill** sessions into consolidated learnings and weekly digests
5. Everything syncs to your phone via iCloud/Obsidian Sync — searchable from the Obsidian mobile app

## Prerequisites

- [Obsidian](https://obsidian.md) with an existing vault
- [Local REST API](https://github.com/coddingtonbear/obsidian-local-rest-api) community plugin installed and enabled
- [Node.js](https://nodejs.org) (for `npx` — runs the MCP server)
- `jq` (recommended — auto-configures providers; install with `brew install jq` or `apt install jq`)

## Install

**One command:**

```bash
curl -fsSL https://raw.githubusercontent.com/jcarter/singularity/main/install.sh | bash
```

**Or clone and run:**

```bash
git clone https://github.com/jcarter/singularity && cd singularity && ./install.sh
```

The installer will:
1. Prompt for your Obsidian vault path (auto-detects common locations)
2. Prompt for your Local REST API key
3. Create `~/.singularity/` with env config and hook scripts
4. Create `Singularity/` folder structure in your vault
5. Copy Obsidian templates (if `Templates/` exists in your vault)
6. Detect and configure installed AI providers

## What Gets Installed

```
~/.singularity/
├── .env                    # API key and vault path
├── hooks/
│   ├── session-start.sh    # Distillation reminder check
│   └── session-end.sh      # Saves session summary to vault
└── skills/
    └── distill/            # /distill skill (symlinked into providers)
        └── SKILL.md

<your-vault>/
├── Singularity/
│   ├── Sessions/           # Auto-saved session summaries
│   ├── Learnings/          # Cross-project insights
│   ├── Decisions/          # Architectural decisions
│   ├── Distilled/          # Weekly/monthly digests
│   └── README.md
└── Templates/
    ├── Singularity Session.md
    └── Singularity Learning.md
```

## Provider Support

| Feature | Claude Code | Copilot | Cursor | Windsurf |
|---|---|---|---|---|
| MCP server | Auto | Per-project | Auto | Auto |
| Session start hook | Auto | Auto (shared) | — | Auto |
| Session end hook | Auto | Auto (shared) | — | — |
| Auto-save sessions | ✓ | ✓ | Manual | Partial |

**Claude Code + Copilot:** Both use `~/.claude/settings.json` for hooks and `~/.claude/skills/` for skills. The installer configures them once and they work for both providers.

**Cursor/Windsurf note:** These providers lack full session lifecycle hooks. Use the MCP server's `create_file` tool to manually save sessions — ask your AI to "save this session to Singularity" at the end of a conversation.

### Copilot MCP (Per-Project)

MCP servers in VS Code are per-workspace. Add this to each project's `.vscode/mcp.json`:

```json
{
  "servers": {
    "singularity": {
      "command": "npx",
      "args": ["-y", "mcp-obsidian"],
      "env": {
        "OBSIDIAN_API_KEY": "<your-api-key>",
        "OBSIDIAN_API_URL": "https://127.0.0.1:27124",
        "VAULT_PATH": "Singularity"
      }
    }
  }
}
```

### Using Copilot Without MCP

If your organization has MCP disabled, Singularity still works — session hooks save notes to the filesystem directly, no MCP involved. The only gap is your AI's ability to *read* past sessions and run distillation.

The workaround: add your vault's `Singularity/` folder to your VS Code workspace. Copilot in agent mode has full file access within the workspace, so it can read, search, and write session notes without MCP.

Add it to your `.code-workspace` file:

```json
{
  "folders": [
    { "path": "." },
    { "path": "/path/to/your/vault/Singularity" }
  ]
}
```

Or use **File > Add Folder to Workspace** to add it interactively.

## Privacy

The MCP server is scoped to `Singularity/` inside your vault. Your personal notes are **never** sent to any provider's API. Only files within the Singularity folder are accessible.

## Distillation

After accumulating several sessions, consolidate them into learnings and a weekly digest.

The installer symlinks the `/distill` skill into **Claude Code** and **Copilot** so it's available from any project:

```
/distill 14
```

For other providers, ask your AI to "distill my recent Singularity sessions" — the MCP tools handle the rest.

The session-start hook will remind you when distillation is overdue (>7 days).

## Uninstall

```bash
./uninstall.sh
```

Removes `~/.singularity/`, cleans provider configs, and optionally removes the vault structure (with confirmation).

## Manual Configuration

If `jq` isn't installed, the installer prints what to add manually. Here are the configs for reference:

<details>
<summary>Claude Code + Copilot (~/.claude/settings.json)</summary>

Both providers share this config file.

```json
{
  "mcpServers": {
    "singularity": {
      "command": "npx",
      "args": ["-y", "mcp-obsidian"],
      "env": {
        "OBSIDIAN_API_KEY": "<your-api-key>",
        "OBSIDIAN_API_URL": "https://127.0.0.1:27124",
        "VAULT_PATH": "Singularity"
      }
    }
  },
  "hooks": {
    "SessionStart": [{
      "hooks": [{"type": "command", "command": "SINGULARITY_PROVIDER=claude ~/.singularity/hooks/session-start.sh"}]
    }],
    "SessionEnd": [{
      "hooks": [{"type": "command", "command": "SINGULARITY_PROVIDER=claude ~/.singularity/hooks/session-end.sh"}]
    }]
  }
}
```

</details>

<details>
<summary>Cursor (~/.cursor/mcp.json)</summary>

```json
{
  "mcpServers": {
    "singularity": {
      "command": "npx",
      "args": ["-y", "mcp-obsidian"],
      "env": {
        "OBSIDIAN_API_KEY": "<your-api-key>",
        "OBSIDIAN_API_URL": "https://127.0.0.1:27124",
        "VAULT_PATH": "Singularity"
      }
    }
  }
}
```

</details>

<details>
<summary>Windsurf (~/.windsurf/mcp.json + hooks.json)</summary>

**mcp.json:**
```json
{
  "mcpServers": {
    "singularity": {
      "command": "npx",
      "args": ["-y", "mcp-obsidian"],
      "env": {
        "OBSIDIAN_API_KEY": "<your-api-key>",
        "OBSIDIAN_API_URL": "https://127.0.0.1:27124",
        "VAULT_PATH": "Singularity"
      }
    }
  }
}
```

**hooks.json:**
```json
{
  "hooks": {
    "pre_user_prompt": {
      "command": "SINGULARITY_PROVIDER=windsurf ~/.singularity/hooks/session-start.sh"
    }
  }
}
```

</details>
