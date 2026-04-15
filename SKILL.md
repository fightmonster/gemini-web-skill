---
name: gemini-web-skill
version: 1.1.0
description: "Generate AI images, music, and videos via Google Gemini using agent-browser. Use when the user wants to generate an image, create AI art, generate music, create a song, or generate a video with Gemini. NOT for Gemini API calls, Gemini CLI usage, or non-creative tasks. Supports image (default), music, and video generation modes with automatic Pro mode selection and local file download."
metadata: {"openclaw":{"emoji":"🎨","requires":{"bins":["agent-browser"]},"os":["darwin","linux","win32"]}}
---

# Gemini Web Creator Skill

Generate images, music, and videos via Google Gemini, using `agent-browser` for browser automation.

## Prerequisites

- **agent-browser** installed: `npm i -g agent-browser` or `brew install agent-browser`
- **Google Chrome** installed
- Run `agent-browser install` once to download Chrome
- **Python 3 + websockets** (optional, video mode file upload): `pip install websockets`

## Arguments

Parse `$ARGUMENTS`:
- First token is mode: `image`, `music`, or `video`
- If first token is not a recognized mode, treat entire input as an image prompt (default to image mode)
- For `video` mode only: the remaining tokens may contain a file path and/or a text prompt
  - Detect file path: any token starting with `/`, `~/`, or `./`, or ending with `.jpg`, `.png`, `.gif`, `.mp4`, `.mov`, `.webm`, `.mp3`, `.wav`
  - Expand `~` to home directory and resolve to absolute path
  - Everything else (non-path tokens) is the generation prompt text
- For `image` and `music` modes: everything after the first token is the generation prompt

Generate a filesystem-safe output name from the prompt (slugify, max 40 chars).

## Step 1: Connect to Gemini

Connect to a running Chrome instance (aichrome on port 9222) or let agent-browser auto-discover:

```bash
agent-browser --cdp 9222 open https://gemini.google.com/app
```

Or if Chrome is already at gemini.google.com:

```bash
agent-browser --cdp 9222 snapshot -i
```

Wait for page load, then check login status.

### Login Detection

Take a snapshot and check:

**Logged in** — snapshot contains:
- A `textbox` element (like `textbox "为 Gemini 输入提示"` or `textbox "Enter a prompt for Gemini"`)
- OR a heading like `"与 Gemini 对话"` / `"Conversation with Gemini"`
- OR a user account button like `button "Google 账号： ..."` / `button "Google Account: ..."`

**NOT logged in** — snapshot shows:
- A `button "Sign in"` / `button "登录"` / `link "Sign in"`
- OR no prompt textbox visible

**If NOT logged in**, output this message and STOP:

```
🔑 首次使用需要登录 Google 账号

Chrome 浏览器已打开，请按以下步骤操作：

1. 在 Chrome 窗口中找到 Gemini 登录页面
2. 登录你的 Google 账号
3. 登录成功后，你会看到 Gemini 的聊天界面（有输入框）
4. 回到这里告诉我 "准备好了" 或 "登录完成"

注意：登录信息保存在本地 Chrome profile 中，后续使用无需重复登录。
```

Wait for user to confirm, then verify login via `snapshot -i`.

## Step 2: Select Pro Mode

**MANDATORY** before any generation.

```bash
agent-browser --cdp 9222 snapshot -i
```

Find the mode picker button (look for `button "Open mode picker"` / `button "打开模式选择器"`), click it:

```bash
agent-browser --cdp 9222 click @eN
```

Re-snapshot to see the dropdown. Check which `menuitem` has `focused`:
- `"Pro Advanced math and code with 3.1 Pro" focused` → already Pro, skip
- Otherwise → click the `menuitem` containing "Pro"

If "Pro" does not exist in dropdown, fall back to "Fast" / "快速".

## Step 3A: Image Generation

### Submit Prompt

1. Snapshot to find the prompt textbox:
```bash
agent-browser --cdp 9222 snapshot -i
```

2. Fill with `#Generate Image: ` prefix:
```bash
agent-browser --cdp 9222 fill @eN "#Generate Image: <prompt text>"
```

3. Snapshot to find send button (`button "发送"` / `button "Send"`), then click:
```bash
agent-browser --cdp 9222 click @eN
```

If no send button, press Enter:
```bash
agent-browser --cdp 9222 press Enter
```

### Wait for Generation

```bash
agent-browser --cdp 9222 wait --text "下载完整尺寸的图片" --timeout 120000
```

Or for English UI:
```bash
agent-browser --cdp 9222 wait --text "Download full size" --timeout 120000
```

If timeout, take a screenshot to diagnose:
```bash
agent-browser --cdp 9222 screenshot
```

### Download Image

1. Snapshot to find the download button (`button "下载完整尺寸的图片"` / `button "Download full size image"`):
```bash
agent-browser --cdp 9222 snapshot -i
```

2. Click it to trigger browser download:
```bash
agent-browser --cdp 9222 click @eN
```

3. Wait for download and verify:
```bash
ls -lt ~/Downloads/ | head -5
file ~/Downloads/<filename>
```

Report the saved file path and size to user.

## Step 3B: Music Generation

### Submit Prompt

1. Fill textbox with `#Generate Music: ` prefix:
```bash
agent-browser --cdp 9222 fill @eN "#Generate Music: <prompt text>"
```

2. Click send button or press Enter (same as image).

### Wait for Generation

```bash
agent-browser --cdp 9222 wait --text "下载音乐作品" --timeout 180000
```

Note: do NOT wait for "Music" or "播放视频" — they appear before generation is complete. Only "下载音乐作品" / "Download track" means the music is ready.

### Download Music (no ffmpeg needed)

1. The "Download track" / "下载音乐作品" button is a dropdown. Click it:
```bash
agent-browser --cdp 9222 snapshot -i
agent-browser --cdp 9222 click @eN
```

2. Re-snapshot to see menu items. Click "纯音频 MP3 音轨" / "Audio only MP3 track" for MP3:
```bash
agent-browser --cdp 9222 snapshot -i
agent-browser --cdp 9222 click @eN
```

3. To also get MP4 with cover art, click the download button again, then click the cover art option.

4. Verify:
```bash
ls -lt ~/Downloads/ | head -5
file ~/Downloads/<filename>
```

Report the saved file path(s) and size(s) to user.

## Step 3C: Video Generation

### Upload Reference File (if provided)

This step only executes if the user provided a file path argument.

1. Snapshot to find "Add files" button (`button "Open upload file menu"` / `button "打开文件上传菜单"`):
```bash
agent-browser --cdp 9222 snapshot -i
```

2. Click it, then click "Upload files" / "上传文件" menuitem.

3. Upload the file via CDP `DOM.setFileInputFiles` using Python (agent-browser does not natively support file upload):

```bash
cat << 'PYEOF' | python3 -
import asyncio, json, websockets

async def cdp(ws, mid, method, params=None):
    p = {"id": mid, "method": method}
    if params: p["params"] = params
    await ws.send(json.dumps(p))
    while True:
        r = json.loads(await ws.recv())
        if r.get("id") == mid: return r

async def main():
    import urllib.request
    cdp_url = "http://localhost:9222/json"
    pages = json.loads(urllib.request.urlopen(cdp_url).read())
    ws_url = next((p["webSocketDebuggerUrl"] for p in pages if "gemini" in p.get("url","")), None)
    if not ws_url: print("ERROR: No Gemini page found"); return
    async with websockets.connect(ws_url, max_size=50*1024*1024) as ws:
        r = await cdp(ws, 1, "DOM.getDocument", {"depth": -1, "pierce": True})
        root = r.get("result", {}).get("root", {})
        r = await cdp(ws, 2, "DOM.querySelector", {"nodeId": root.get("nodeId", 1), "selector": "input[type='file']"})
        nid = r.get("result", {}).get("nodeId", 0)
        if nid == 0: print("ERROR: file input not found"); return
        await cdp(ws, 3, "DOM.setFileInputFiles", {"nodeId": nid, "files": ["FILE_PATH_HERE"]})
        print("Upload done")

asyncio.run(main())
PYEOF
```

Replace `FILE_PATH_HERE` with the resolved absolute path.

4. Wait and verify file thumbnail appeared:
```bash
agent-browser --cdp 9222 snapshot -i
```

### Submit Prompt

1. Fill textbox with `#Generate Video: ` prefix (or generic prompt if only file provided):
```bash
agent-browser --cdp 9222 fill @eN "#Generate Video: <prompt text>"
```

2. Click send button or press Enter.

### Wait for Generation

```bash
agent-browser --cdp 9222 wait --text "下载视频" --timeout 300000
```

Video generation may take up to 5 minutes.

### Download Video

1. Snapshot to find download button (`button "下载视频"` / `button "Download video"`):
```bash
agent-browser --cdp 9222 snapshot -i
```

2. Click to trigger browser download:
```bash
agent-browser --cdp 9222 click @eN
```

3. Verify:
```bash
ls -lt ~/Downloads/ | head -5
file ~/Downloads/<filename>.mp4
```

Report the saved file path and size to user.

## Error Handling

| Scenario | Action |
|----------|--------|
| Chrome not running | Tell user to start Chrome with `--remote-debugging-port=9222` |
| Gemini not logged in | Show login instructions, STOP and wait for user |
| Image generation timeout (120s) | Screenshot, report failure, suggest simpler prompt |
| Music generation timeout (180s) | Screenshot, report failure, suggest simpler prompt |
| Video generation timeout (300s) | Screenshot, report failure, suggest simpler prompt |
| Download button not found | Re-snapshot, check for `busy` state, wait and retry |
| Pro mode unavailable | Fall back to Fast/快速 mode |
| File upload fails | Check file path exists, verify Python websockets installed |

## Output Convention

Files are saved to `~/Downloads/` by Chrome's built-in download:
- Images: `Gemini_Generated_Image_xxxxx.png` (high-resolution PNG)
- Music MP3: `<Track_Name>.mp3`
- Music MP4: `<Track_Name>.mp4` (with cover art)
- Video MP4: `<Video_Title>.mp4`
