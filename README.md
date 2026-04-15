# Gemini Web Creator Skill

Generate AI images, music, and videos via Google Gemini using OpenClaw's built-in **browser-cdp** skill.

Works with **OpenClaw**.

## Install

```bash
# Install this skill (OpenClaw)
npx skills add https://github.com/fightmonster/gemini-web-skill

# Ensure browser-cdp dependencies are installed
pip install websockets
```

## Usage

### Image

Supports aspect ratios, photography styles, lighting, and composition cues.

```bash
# Basic
/gemini-web-skill image a sunset over the ocean with golden reflections

# Aspect ratio + cinematic style
/gemini-web-skill image 16:9 雨夜东京街头，霓虹灯倒影，赛博朋克风格，电影级构图

# Portrait photography
/gemini-web-skill image 9:16 a Korean girl in a vintage café, soft natural lighting, shallow depth of field, 85mm portrait lens

# Product photography
/gemini-web-skill image 1:1 a glass perfume bottle on marble surface, studio lighting, minimalist composition, luxury aesthetic

# Concept art
/gemini-web-skill image a futuristic floating city above clouds, concept art style, matte painting, epic wide angle
```

Tip: Include photography terms like `golden hour`, `bokeh`, `tilt-shift`, `dramatic lighting`, `film grain` for more professional results.

### Music

Describe genre, era, mood, instruments, and tempo in Chinese or English.

```bash
/gemini-web-skill music 80年代粤语流行曲风，合成器前奏，轻快节奏，关于夏天的海边回忆

/gemini-web-skill music 90s alternative grunge rock, heavy bassline, angst-filled lyrics about teenage rebellion

/gemini-web-skill music 中国风古筝配电子节拍，悠扬婉转，适合做短视频背景音乐

/gemini-web-skill music lo-fi hip hop with jazz piano samples, vinyl crackle, mellow late night vibe, 85 BPM

/gemini-web-skill music 70年代放克迪斯科，铜管乐器，四拍底鼓，适合派对舞曲
```

Tip: Mention specific decades, instruments, and BPM for better control. Outputs MP3 + MP4 (with cover art).

### Video

Describe **multiple sequential actions** for smooth results. Each sentence = one scene transition.

```bash
# Multiple actions
/gemini-web-skill video 一个女孩在海边散步，风吹起她的长发，她转身望向远方的落日，镜头缓缓拉远

/gemini-web-skill video a cat jumps onto a piano, walks across the keys creating random notes, then curls up and falls asleep on the warm piano lid

# With reference image
/gemini-web-skill video /path/to/your/image.jpg 这只猫伸了个懒腰，跳下沙发，慢慢走向镜头

# Cinematic style
/gemini-web-skill video 雨夜城市天际线延时摄影，乌云翻涌，闪电划过夜空，最后雨停露出星空

/gemini-web-skill video a samurai stands in a field of tall grass, wind blows cherry blossom petals across the scene, he slowly draws his katana, camera orbits around him
```

Tip: Describe 3-5 distinct actions for best results. Use cinematography terms like `镜头拉近` (zoom in), `慢动作` (slow motion), `延时摄影` (time-lapse), `环绕镜头` (orbit shot).

## First Time

On first use, browser-cdp launches Chrome with your real profile. If Gemini shows a login page, the skill detects this and shows instructions. After logging into your Google account, subsequent uses are automatic.

## How It Works

```
start_chrome.sh → Chrome (CDP) → browser-cdp (Python SDK) → Gemini Web UI
```

1. `start_chrome.sh` launches Chrome with persistent profile (Google login preserved)
2. browser-cdp connects to the running Chrome via CDP, operates Gemini via Python API
3. Selects Pro mode, submits generation prompt
4. Waits for completion, clicks Gemini UI download buttons
5. Files saved to `~/Downloads/` by Chrome

## Prerequisites

| Dependency | Required? | Notes |
|---|---|---|
| browser-cdp skill | Yes | Built-in with OpenClaw |
| Google Chrome | Yes | Browser |
| Python 3 + websockets | Yes | CDP communication |

No ffmpeg needed. Gemini UI provides direct MP3/MP4/PNG download.

## Version

**1.0.5** — Use OpenClaw built-in browser-cdp skill

- browser-cdp Python SDK for browser automation (not MCP or CLI)
- Reuses user Chrome profile with login state
- Image generation with UI download
- Music generation with MP3/MP4 download
- Video generation with reference file upload support
- First-time login detection with guided setup
- Chinese and English UI support
