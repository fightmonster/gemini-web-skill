---
name: gemini-web-skill
version: 1.3.0
description: "Generate AI images, music, and videos via Google Gemini using Chrome DevTools MCP (browser-cdp). Use when the user wants to generate an image, create AI art, generate music, create a song, or generate a video with Gemini. NOT for Gemini API calls, Gemini CLI usage, or non-creative tasks. Supports image (default), music, and video generation modes with automatic Pro mode selection and local file download."
metadata: {"openclaw":{"emoji":"🎨","requires":{"bins":["bash"]},"os":["darwin","linux","win32"]}}
---

# Gemini Web Creator Skill

Generate images, music, and videos via Google Gemini, using Chrome DevTools MCP (browser-cdp) for browser automation.

## Prerequisites

- **Google Chrome** installed
- **Chrome DevTools MCP Server** configured (e.g. `@anthropic-ai/chrome-devtools-mcp`)
- **Python 3 + websockets** (optional, video mode file upload): `pip install websockets`

## How It Works

```
Agent → Chrome DevTools MCP → Chrome Browser (CDP) → Gemini Web UI
```

1. `start_chrome.sh` launches Chrome with remote debugging and persistent profile
2. Agent calls MCP tools (snapshot, click, fill, etc.) to control Chrome
3. Gemini UI generates content, agent clicks download buttons
4. Files saved to `~/Downloads/`

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

## Step 0: Ensure Chrome is Running

1. Call `list_pages` to check if Chrome DevTools is accessible.
2. If connection fails or returns empty, execute:
   ```bash
   bash {baseDir}/scripts/start_chrome.sh
   ```
   Wait 3 seconds, then retry `list_pages`.
3. If still failing, report error to user and stop.

## Step 1: Navigate to Gemini & Login Check

1. Call `list_pages` to get all open pages.
2. Check if any page URL contains `gemini.google.com/app`. If found, call `select_page` with that page's `pageId` — do NOT navigate again.
3. If no existing Gemini page found, call `navigate_page` with `type: "url"`, `url: "https://gemini.google.com/app"` (no trailing slash — causes 404).
4. Wait for page load, then take a snapshot to check login status.

### Login Detection

5. Check the snapshot for one of these conditions:

   **Logged in** — snapshot contains:
   - A `textbox` element (prompt input area like `textbox "为 Gemini 输入提示"` or `textbox "Enter a prompt for Gemini"`)
   - OR a heading like `"与 Gemini 对话"` / `"Conversation with Gemini"`
   - OR a user account button like `button "Google 账号： ..."` / `button "Google Account: ..."`

   **NOT logged in** — snapshot shows:
   - A `button "Sign in"` / `button "登录"` / `link "Sign in"`
   - OR a login form with email/password fields
   - OR no prompt textbox or conversation heading visible

6. **If user is NOT logged in**, this is a first-time setup. You MUST:
   - Take a screenshot to show the current page state.
   - Output the following message to the user (adapt language to user's locale):

   ```
   🔑 首次使用需要登录 Google 账号

   Chrome 浏览器已打开，请按以下步骤操作：

   1. 在 Chrome 窗口中找到 Gemini 登录页面
   2. 登录你的 Google 账号
   3. 登录成功后，你会看到 Gemini 的聊天界面（有输入框）
   4. 回到这里告诉我 "准备好了" 或 "登录完成"

   注意：登录信息保存在本地 Chrome profile 中，后续使用无需重复登录。
   ```

   - Then STOP and wait for the user to reply. Do NOT proceed with any generation.
   - When user confirms they are logged in, take a snapshot to verify, then continue to Step 2.

   **If user IS logged in**, proceed directly to Step 2.

## Step 2: Select Pro Mode

**MANDATORY** — Before submitting any prompt in ANY mode (image, music, video), always ensure Pro mode is selected:

1. Find the mode picker button (look for `button "Open mode picker"` / `button "打开模式选择器"`) and click it.
2. The dropdown shows 3 menuitems. Check which one has `focused` attribute:
   - `menuitem "Fast Answers quickly" focusable focused` → currently Fast
   - `menuitem "Thinking Solves complex problems" focusable focused` → currently Thinking
   - `menuitem "Pro Advanced math and code with 3.1 Pro" focusable focused` → currently Pro
3. If "Pro" is NOT focused, click the `menuitem` containing "Pro".
4. If "Pro" menuitem does NOT exist, fall back to "Fast" / "快速".
5. Close the dropdown (usually closes automatically after selection).

## Step 3A: Image Generation Workflow

### Submit Prompt

1. Find the prompt `textbox` element from snapshot (look for `textbox "Ask Gemini"` / `textbox "问问 Gemini"` / `textbox "为 Gemini 输入提示"` / `textbox "Enter a prompt for Gemini"` or similar).
2. Prepend `#Generate Image: ` to the prompt text (e.g. `#Generate Image: a sunset over the ocean`).
3. Call `fill` on the textbox with the prefixed prompt text.
4. After filling, take a snapshot to check if a `button "发送"` / `button "Send"` appeared. If it exists, **click it** — do NOT rely on `press_key Enter` alone (it may not work in Pro mode). If no send button visible, fall back to `press_key` with `key: "Enter"`.

### Wait for Generation

5. Call `wait_for` with `text: ["下载完整尺寸的图片", "Download full size", "答得好", "Good response"]`, `timeout: 120000`.
   If timeout, take a screenshot to diagnose and report error.

### Download Image via Gemini UI

6. Find the `button "Download full size image"` / `button "下载完整尺寸的图片"` in the snapshot. The image must be fully generated (container must NOT have `busy` attribute). If `busy`, wait a few seconds and re-take snapshot.
7. Click the download button. If `click` fails, wait 3 seconds and retry.
8. Wait 5 seconds for the download, then verify:
   - Check `ls -lt ~/Downloads/ | head -5` for the new PNG file.
   - Use `file` command to confirm format.

9. If the UI download button is not available, fall back to `evaluate_script`:

```javascript
async () => {
  const images = document.querySelectorAll('img');
  let targetImg = null;
  for (const img of images) {
    if (img.src.startsWith('blob:') && img.naturalWidth > 500) {
      targetImg = img;
      break;
    }
  }
  if (!targetImg) return { error: 'No blob image found with width > 500' };
  const canvas = document.createElement('canvas');
  canvas.width = targetImg.naturalWidth;
  canvas.height = targetImg.naturalHeight;
  canvas.getContext('2d').drawImage(targetImg, 0, 0);
  const dataUrl = canvas.toDataURL('image/jpeg', 0.95);
  const base64 = dataUrl.split(',')[1];
  const byteChars = atob(base64);
  const sliceSize = 8192;
  const byteArrays = [];
  for (let offset = 0; offset < byteChars.length; offset += sliceSize) {
    const slice = byteChars.slice(offset, offset + sliceSize);
    const byteNumbers = new Array(slice.length);
    for (let i = 0; i < slice.length; i++) {
      byteNumbers[i] = slice.charCodeAt(i);
    }
    byteArrays.push(new Uint8Array(byteNumbers));
  }
  const blob = new Blob(byteArrays, { type: 'image/jpeg' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'gemini_<slugified_name>.jpg';
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
  return { success: true, size: byteChars.length, width: canvas.width, height: canvas.height };
}
```

10. If blob extraction fails (tainted canvas), fall back to `take_screenshot` of the image element.

11. Report the saved file path and size to user.

## Step 3B: Music Generation Workflow

### Submit Prompt

1. Find the prompt `textbox` element from snapshot.
2. Prepend `#Generate Music: ` to the prompt text.
3. Call `fill` on the textbox with the prefixed prompt text.
4. After filling, take a snapshot to check if a `button "发送"` / `button "Send"` appeared. If it exists, **click it**. If no send button visible, fall back to `press_key` with `key: "Enter"`.

### Wait for Generation

5. Call `wait_for` with `text: ["下载音乐作品", "Download track"]`, `timeout: 180000`.
   Note: do NOT wait for "Music", "播放视频" or "Play video" — they appear before generation is complete. Only "下载音乐作品" / "Download track" indicates the music is fully generated.

### Download Music via Gemini UI (no ffmpeg needed)

6. The "Download track" / "下载音乐作品" button is a dropdown menu. Click it to open.
7. The menu offers: "Audio only MP3 track" / "纯音频 MP3 音轨" (MP3) and "Video Audio with cover art" / "视频 音频和封面图片" (MP4 with cover).
8. To download MP3, click the MP3 menuitem. If `click` fails, use `evaluate_script`:

```javascript
() => {
  const items = document.querySelectorAll('[role="menuitem"]');
  for (const item of items) {
    if (item.textContent.includes('MP3')) {
      item.click();
      return { clicked: item.textContent.trim() };
    }
  }
  return { error: 'MP3 menuitem not found' };
}
```

9. To also get MP4 with cover art, click the download button again, then click the cover art menuitem.
10. Wait 3 seconds, then verify:
    - Check `ls -lt ~/Downloads/ | head -5` for the new file.
11. Report the saved file path(s) and size(s) to user.

## Step 3C: Video Generation Workflow

### Upload Reference File (if provided)

This step only executes if the user provided a file path.

1. Click "Add files" button in snapshot (`button "Open upload file menu"` / `button "打开文件上传菜单"`).
2. Click "Upload files" / "上传文件" menuitem.
3. Upload via CDP using Python:

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
    pages = json.loads(urllib.request.urlopen("http://localhost:9222/json").read())
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

4. Take a snapshot to verify the file thumbnail appeared.

### Submit Prompt

5. Find the prompt `textbox` element from snapshot.
6. Prepend `#Generate Video: ` to the prompt text. If no text prompt was provided (only file), use `#Generate Video: generate a video based on this image`.
7. Call `fill` on the textbox with the prefixed prompt text.
8. After filling, take a snapshot to check for `button "发送"` / `button "Send"`. If it exists, **click it**. If no send button, fall back to `press_key` with `key: "Enter"`.

### Wait for Generation

9. Call `wait_for` with `text: ["下载视频", "Download video", "分享视频", "Share video"]`, `timeout: 300000` (up to 5 minutes).
   Note: Only "下载视频" / "Download video" indicates completion. Ignore "播放视频" / "Play video".

### Download Video via Gemini UI

10. Find the `button "Download video"` / `button "下载视频"` and click it.
11. Wait 5 seconds, then verify:
    - Check `ls -lt ~/Downloads/ | head -5` for the new MP4 file.

12. If download button unavailable, fall back to `evaluate_script`:

```javascript
async () => {
  const video = document.querySelector('video');
  if (!video || !video.src) return { error: 'No video element with src found' };
  const response = await fetch(video.src, { mode: 'cors', credentials: 'include' });
  if (!response.ok) return { error: `Fetch failed: ${response.status}` };
  const blob = await response.blob();
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'gemini_<slugified_name>.mp4';
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
  return { success: true, size: blob.size, type: blob.type };
}
```

13. Report the saved file path and size to user.

## Error Handling

| Scenario | Action |
|----------|--------|
| Chrome not running | Auto-start via `{baseDir}/scripts/start_chrome.sh`, retry once |
| Gemini not logged in | Take screenshot, show login instructions, STOP and wait for user |
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
