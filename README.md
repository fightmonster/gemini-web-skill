# Gemini Web Creator Skill

Generate AI images, music, and videos via Google Gemini using `agent-browser`.

Works with **OpenClaw** and **Claude Code**.

## Install

```bash
# Install agent-browser (skip if already installed)
npm i -g agent-browser
agent-browser install

# Install this skill (OpenClaw)
npx skills add https://github.com/fightmonster/gemini-web-skill
```

## Usage

```
# Generate image
/gemini-web-skill image a sunset over the ocean
/gemini-web-skill 落日余晖下的海边

# Generate music
/gemini-web-skill music an upbeat rock song about driving

# Generate video
/gemini-web-skill video a woman dancing gracefully

# Generate video with reference image
/gemini-web-skill video ~/photos/cat.png a cat playing piano
```

## First Time

On first use, Chrome opens with a fresh profile (no login). The skill detects this and shows login instructions. After logging into your Google account, subsequent uses are automatic.

## How It Works

```
Agent → agent-browser CLI → Chrome (CDP) → Gemini Web UI
```

1. Connects to Chrome via CDP (port 9222)
2. Navigates to Gemini, selects Pro mode
3. Submits generation prompt via `fill` + `click`
4. Waits for completion via `wait --text`
5. Clicks Gemini UI download buttons
6. Files saved to `~/Downloads/` by Chrome

## Prerequisites

| Dependency | Required? | Notes |
|---|---|---|
| agent-browser | Yes | Browser automation CLI |
| Google Chrome | Yes | Browser |
| Chrome running with `--remote-debugging-port=9222` | Yes | Or use `agent-browser open` to auto-launch |
| Python 3 + websockets | Optional | Only for video mode file upload |

No ffmpeg needed. Gemini UI provides direct MP3/MP4/PNG download.

## Version

**1.1.0** — Use `agent-browser` instead of raw Chrome DevTools MCP

- Removed all scripts (zero-code skill)
- Image generation with UI download
- Music generation with MP3/MP4 download
- Video generation with reference file upload support
- First-time login detection with guided setup
- Chinese and English UI support
