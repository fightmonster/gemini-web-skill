# Gemini Creator Skill

Generate AI images, music, and videos via Google Gemini using Chrome DevTools MCP.

Works with **OpenClaw** and **Claude Code**.

## Install

### OpenClaw

```bash
# Option 1: From GitHub
openclaw skills install https://github.com/luojun/gemini-skill

# Option 2: Copy manually
cp -r gemini-skill ~/.openclaw/skills/gemini
```

### Claude Code

```bash
# Copy to your project's .claude/skills/
cp -r gemini-skill .claude/skills/gemini
chmod +x .claude/skills/gemini/scripts/*.sh
```

### MCP Server Setup

Add Chrome DevTools MCP to `.mcp.json` or `~/.claude/.mcp.json`:

```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/chrome-devtools-mcp@latest"]
    }
  }
}
```

## Usage

```
# Generate image
/gemini image a sunset over the ocean
/gemini 落日余晖下的海边

# Generate music
/gemini music an upbeat rock song about driving

# Generate video
/gemini video a woman dancing gracefully

# Generate video with reference image
/gemini video ~/photos/cat.png a cat playing piano
```

## First Time

On first use, a new Chrome instance opens with a fresh profile (no login). The skill will detect this and show login instructions. After logging into your Google account, subsequent uses are automatic.

## How It Works

```
Agent → Chrome DevTools MCP → Chrome Browser → Gemini Web UI
```

1. Launches an isolated Chrome instance with remote debugging
2. Navigates to Gemini, selects Pro mode
3. Submits generation prompt
4. Waits for completion, downloads via Gemini UI buttons
5. Files saved to `~/Downloads/`

## Prerequisites

| Dependency | Required? | Notes |
|---|---|---|
| Google Chrome / Chromium | Yes | Browser |
| Chrome DevTools MCP Server | Yes | MCP plugin |
| Python 3 | Optional | Only for video file upload |
| websockets (pip) | Optional | Only for video file upload |

No ffmpeg needed. Gemini UI provides direct MP3/MP4/PNG download.

## Version

**1.0.0** — Initial release

- Image generation with UI download
- Music generation with MP3/MP4 download
- Video generation with reference file upload support
- Cross-platform Chrome launcher (macOS/Linux/Windows)
- First-time login detection with guided setup
- Chinese and English UI support
