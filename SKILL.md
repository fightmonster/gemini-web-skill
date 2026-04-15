---
name: gemini-web-skill
version: 1.0.5
description: "Generate AI images, music, and videos via Google Gemini using browser-cdp skill. Use when the user wants to generate an image, create AI art, generate music, create a song, or generate a video with Gemini. NOT for Gemini API calls, Gemini CLI usage, or non-creative tasks. Supports image (default), music, and video generation modes with automatic Pro mode selection and local file download."
metadata: {"openclaw":{"emoji":"🎨","requires":{"bins":["python3"]},"os":["darwin","linux","win32"]}}
---

# Gemini Web Creator Skill

Generate images, music, and videos via Google Gemini, using the built-in **browser-cdp** skill for browser automation.

## Prerequisites

- **browser-cdp** skill (built-in with OpenClaw)
- **Python 3 + websockets**: `pip install websockets`
- **Google Chrome** installed

## How It Works

```
start_chrome.sh → Chrome (CDP port 9222) → browser-cdp Python SDK → Gemini Web UI
```

1. `start_chrome.sh` launches Chrome with remote debugging and persistent profile (Google login preserved)
2. browser-cdp connects to the running Chrome via CDP, operates Gemini via Python API
3. Files saved to `~/Downloads/`

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

## Step 0: Start Chrome

Run `start_chrome.sh` to launch Chrome with remote debugging and persistent profile:

```bash
bash {baseDir}/scripts/start_chrome.sh
```

This starts Chrome on CDP port 9222 with profile at `~/.gemini-chrome-profile`. The profile preserves Google login state across uses.

Wait 3 seconds after launch for Chrome to be ready.

## Step 0.1: Connect via browser-cdp

Import browser-cdp scripts and connect to the running Chrome:

```python
import sys
sys.path.insert(0, '<browser-cdp-skill-dir>/scripts')

from cdp_client import CDPClient
from page_snapshot import PageSnapshot
from browser_actions import BrowserActions

# Connect to Chrome started by start_chrome.sh (port 9222)
client = CDPClient('ws://localhost:9222/devtools/browser')
client.connect()
snapshot = PageSnapshot(client)
actions = BrowserActions(client, snapshot)
```

**Do NOT call `client.close()` after task** — keep the connection alive for reuse.

## Step 1: Navigate to Gemini & Login Check

1. Check existing tabs first (avoid duplicate):

```python
tabs = client.list_tabs()
gemini_tab = None
for t in tabs:
    if 'gemini.google.com/app' in t['url']:
        gemini_tab = t
        break

if gemini_tab:
    client.attach(gemini_tab['id'])
else:
    tab = client.create_tab('https://gemini.google.com/app')
    client.attach(tab['id'])

actions.wait_for_load()
```

2. Get snapshot and check login status:

```python
tree = snapshot.accessibility_tree()
```

### Login Detection

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

Wait for user to confirm, then re-take snapshot to verify.

## Step 2: Select Pro Mode

**MANDATORY** before any generation.

1. Get snapshot and find mode picker button (look for `button "Open mode picker"` / `button "打开模式选择器"`):

```python
tree = snapshot.accessibility_tree()
# Find the mode picker ref, then click it
actions.click_by_ref('eN')
```

2. Re-snapshot to see the dropdown. Check which `menuitem` has the current mode:
   - If Pro is already active → skip
   - Otherwise → click the `menuitem` containing "Pro"

3. If "Pro" menuitem does NOT exist, fall back to "Fast" / "快速".

4. Re-snapshot after selection to confirm.

## Step 3A: Image Generation Workflow

### Submit Prompt

1. Get snapshot to find the prompt textbox (look for `textbox "Ask Gemini"` / `textbox "问问 Gemini"` / `textbox "为 Gemini 输入提示"` or similar):

```python
tree = snapshot.accessibility_tree()
```

2. Click the textbox, then type with `#Generate Image: ` prefix:

```python
actions.click_by_ref('eN')
actions.type_text('#Generate Image: <prompt text>')
```

3. Find and click the send button (`button "发送"` / `button "Send"`):

```python
tree = snapshot.accessibility_tree()
# Find send button ref
actions.click_by_ref('eN')
```

If no send button found, press Enter:

```python
actions.press_key('Enter')
```

### Wait for Generation

Wait for download button to appear (up to 120 seconds):

```python
import time
deadline = time.time() + 120
while time.time() < deadline:
    tree = snapshot.accessibility_tree()
    if '下载完整尺寸的图片' in tree or 'Download full size' in tree:
        break
    if '答得好' in tree or 'Good response' in tree:
        break
    time.sleep(3)
else:
    actions.screenshot('/tmp/gemini_timeout.png')
    print("Image generation timeout")
```

### Download Image via Gemini UI

1. Find the download button in snapshot (`button "下载完整尺寸的图片"` / `button "Download full size image"`):

```python
tree = snapshot.accessibility_tree()
actions.click_by_ref('eN')
```

2. Wait 5 seconds, then verify:

```python
time.sleep(5)
# Check ~/Downloads/ for the PNG file
```

3. If download button not found or click fails, fall back to `evaluate()`:

```python
# Use JS to find and download the image
actions.evaluate('''
  const images = document.querySelectorAll('img');
  let target = null;
  for (const img of images) {
    if (img.src.startsWith('blob:') && img.naturalWidth > 500) { target = img; break; }
  }
  // ... canvas + blob download logic
''')
```

4. Report the saved file path and size to user.

## Step 3B: Music Generation Workflow

### Submit Prompt

1. Same as image — click textbox, type with `#Generate Music: ` prefix:

```python
actions.click_by_ref('eN')
actions.type_text('#Generate Music: <prompt text>')
```

2. Click send button or press Enter.

### Wait for Generation

Wait for "下载音乐作品" / "Download track" (up to 180 seconds):

```python
deadline = time.time() + 180
while time.time() < deadline:
    tree = snapshot.accessibility_tree()
    if '下载音乐作品' in tree or 'Download track' in tree:
        break
    time.sleep(3)
```

Note: Ignore "Music" or "播放视频" — they appear before generation is complete.

### Download Music via Gemini UI (no ffmpeg needed)

1. The "Download track" / "下载音乐作品" button is a dropdown. Click it:

```python
actions.click_by_ref('eN')
```

2. Re-snapshot to see menu items. Click "纯音频 MP3 音轨" / "Audio only MP3 track" for MP3:

```python
tree = snapshot.accessibility_tree()
actions.click_by_ref('eN')
```

3. To also get MP4 with cover art, click the download button again, then click the cover art option.

4. Verify and report file paths.

## Step 3C: Video Generation Workflow

### Upload Reference File (if provided)

This step only executes if the user provided a file path.

1. Get snapshot, find "Add files" button (`button "Open upload file menu"` / `button "打开文件上传菜单"`), click it:

```python
actions.click_by_ref('eN')
```

2. Find and click "Upload files" / "上传文件" menuitem.

3. Upload via CDP `DOM.setFileInputFiles`:

```python
client.send('DOM.getDocument', {'depth': -1, 'pierce': True})
# Parse result to get root nodeId
# Then:
client.send('DOM.querySelector', {'nodeId': root_id, 'selector': "input[type='file']"})
# Then:
client.send('DOM.setFileInputFiles', {'nodeId': file_input_id, 'files': ['<resolved_path>']})
```

4. Re-snapshot to verify file thumbnail appeared.

### Submit Prompt

1. Click textbox, type with `#Generate Video: ` prefix:

```python
actions.click_by_ref('eN')
actions.type_text('#Generate Video: <prompt text>')
```

2. Click send button or press Enter.

### Wait for Generation

Wait for "下载视频" / "Download video" (up to 300 seconds):

```python
deadline = time.time() + 300
while time.time() < deadline:
    tree = snapshot.accessibility_tree()
    if '下载视频' in tree or 'Download video' in tree:
        break
    time.sleep(5)
```

### Download Video via Gemini UI

1. Find and click download button (`button "下载视频"` / `button "Download video"`):

```python
actions.click_by_ref('eN')
```

2. Wait 5 seconds, verify file in `~/Downloads/`.

3. If download button unavailable, fall back to `evaluate()` for blob fetch.

4. Report the saved file path and size to user.

## Error Handling

| Scenario | Action |
|----------|--------|
| Chrome not running | Run `{baseDir}/scripts/start_chrome.sh` to launch |
| Chrome needs CDP authorization | Show chrome://inspect instructions, wait for user |
| Gemini not logged in | Take screenshot, show login instructions, STOP and wait for user |
| Image generation timeout (120s) | Screenshot, report failure, suggest simpler prompt |
| Music generation timeout (180s) | Screenshot, report failure, suggest simpler prompt |
| Video generation timeout (300s) | Screenshot, report failure, suggest simpler prompt |
| Download button not found | Re-snapshot, check for `busy` state, wait and retry |
| Pro mode unavailable | Fall back to Fast/快速 mode |
| File upload fails | Check file path exists, verify Python websockets installed |
| click_by_ref fails | Follow fallback chain: click_selector → screenshot + click(x,y) |

## Output Convention

Files are saved to `~/Downloads/` by Chrome's built-in download:
- Images: `Gemini_Generated_Image_xxxxx.png` (high-resolution PNG)
- Music MP3: `<Track_Name>.mp3`
- Music MP4: `<Track_Name>.mp4` (with cover art)
- Video MP4: `<Video_Title>.mp4`
