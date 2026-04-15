#!/bin/bash
# Download Gemini-generated music and extract MP3
#
# Usage: download_music.sh <media_url> <cookies_string> <output_name>
# Example: download_music.sh "https://contribution.usercontent.google.com/download?c=..." "SID=xxx; HSID=xxx" "rock_driving_song"

set -e

URL="$1"
COOKIES="$2"
OUTPUT_NAME="$3"
DOWNLOADS_DIR="$HOME/Downloads"

if [ -z "$URL" ] || [ -z "$COOKIES" ] || [ -z "$OUTPUT_NAME" ]; then
    echo "Usage: $0 <media_url> <cookies_string> <output_name>"
    exit 1
fi

MP4_PATH="${DOWNLOADS_DIR}/gemini_${OUTPUT_NAME}.mp4"
MP3_PATH="${DOWNLOADS_DIR}/gemini_${OUTPUT_NAME}.mp3"

echo "Downloading MP4..."
curl -L -o "$MP4_PATH" \
  -H "Cookie: $COOKIES" \
  -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36" \
  -H "Referer: https://gemini.google.com/" \
  -H "Origin: https://gemini.google.com" \
  -H "sec-fetch-dest: video" \
  -H "sec-fetch-mode: cors" \
  -H "sec-fetch-site: same-site" \
  "$URL" 2>/dev/null

# Verify download
if [ ! -f "$MP4_PATH" ] || [ "$(file -b "$MP4_PATH" | head -c 4)" = "HTML" ]; then
    echo "Error: Downloaded file is not a valid media file (possibly HTML error page)" >&2
    rm -f "$MP4_PATH"
    exit 1
fi

MP4_SIZE=$(du -h "$MP4_PATH" | cut -f1)
echo "MP4 downloaded: $MP4_PATH ($MP4_SIZE)"

# Extract MP3 audio with ffmpeg
if command -v ffmpeg &>/dev/null; then
    echo "Extracting MP3 with ffmpeg..."
    ffmpeg -i "$MP4_PATH" -vn -acodec libmp3lame -q:a 2 "$MP3_PATH" -y 2>/dev/null

    if [ -f "$MP3_PATH" ]; then
        MP3_SIZE=$(du -h "$MP3_PATH" | cut -f1)
        echo "MP3 saved: $MP3_PATH ($MP3_SIZE)"
    else
        echo "Warning: MP3 extraction failed, MP4 is still available at $MP4_PATH" >&2
    fi
else
    echo "ffmpeg not found. Only MP4 is saved: $MP4_PATH"
fi

echo "Done!"
