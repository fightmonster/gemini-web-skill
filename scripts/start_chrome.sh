#!/bin/bash
# Portable Chrome launcher with remote debugging for Gemini skill
# Detects OS and Chrome installation automatically
#
# Usage: start_chrome.sh [port] [profile_dir]
#   port        - Debugging port (default: 9222)
#   profile_dir - Chrome user data directory (default: ~/.gemini-chrome-profile)

set -e

PORT="${1:-9222}"
PROFILE_DIR="${2:-$HOME/.gemini-chrome-profile}"

# Detect Chrome binary based on OS
detect_chrome() {
    local chrome=""

    case "$(uname -s)" in
        Darwin)
            # macOS - check common locations
            for path in \
                "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
                "/Applications/Chromium.app/Contents/MacOS/Chromium" \
                "$HOME/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
                "$HOME/Applications/Chromium.app/Contents/MacOS/Chromium"; do
                if [ -x "$path" ]; then
                    chrome="$path"
                    break
                fi
            done
            ;;
        Linux)
            # Linux - check common locations
            for cmd in \
                "google-chrome-stable" \
                "google-chrome" \
                "chromium-browser" \
                "chromium"; do
                if command -v "$cmd" &>/dev/null; then
                    chrome="$(command -v "$cmd")"
                    break
                fi
            done
            # Also check flatpak
            if [ -z "$chrome" ] && command -v flatpak &>/dev/null; then
                if flatpak list | grep -q "com.google.Chrome"; then
                    chrome="flatpak run com.google.Chrome"
                elif flatpak list | grep -q "org.chromium.Chromium"; then
                    chrome="flatpak run org.chromium.Chromium"
                fi
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*)
            # Windows (Git Bash / MSYS2)
            for path in \
                "/c/Program Files/Google/Chrome/Application/chrome.exe" \
                "/c/Program Files (x86)/Google/Chrome/Application/chrome.exe" \
                "$LOCALAPPDATA/Google/Chrome/Application/chrome.exe"; do
                if [ -x "$path" ]; then
                    chrome="$path"
                    break
                fi
            done
            ;;
    esac

    if [ -z "$chrome" ]; then
        echo "ERROR: Chrome/Chromium not found. Please install Google Chrome or Chromium." >&2
        echo "       Alternatively, set CHROME_PATH environment variable." >&2
        exit 1
    fi

    echo "$chrome"
}

# Allow override via environment variable
if [ -n "$CHROME_PATH" ] && [ -x "$CHROME_PATH" ]; then
    CHROME_BIN="$CHROME_PATH"
else
    CHROME_BIN="$(detect_chrome)"
fi

echo "Chrome binary: $CHROME_BIN"
echo "Debug port: $PORT"
echo "Profile dir: $PROFILE_DIR"

# Check if already running
RUNNING_PID=$(pgrep -f "remote-debugging-port=$PORT.*user-data-dir=$PROFILE_DIR" 2>/dev/null || true)

if [ -n "$RUNNING_PID" ]; then
    echo "Chrome already running (PID: $RUNNING_PID)"
    echo "Debug URL: http://localhost:$PORT"
    exit 0
fi

# Check for port conflicts
CONFLICT=$(lsof -i :"$PORT" 2>/dev/null | grep LISTEN || true)
if [ -n "$CONFLICT" ]; then
    echo "WARNING: Port $PORT is in use:"
    echo "$CONFLICT"
    echo ""
    echo "Attempting to start anyway..."
fi

# Clean up stale lock files
rm -rf "$PROFILE_DIR/SingletonLock" "$PROFILE_DIR/SingletonCookie" 2>/dev/null || true
mkdir -p "$PROFILE_DIR"

# Launch Chrome
echo "Starting Chrome with remote debugging..."
"$CHROME_BIN" \
    --remote-debugging-port="$PORT" \
    --user-data-dir="$PROFILE_DIR" \
    --no-first-run \
    --no-default-browser-check \
    &

CHROME_PID=$!
echo "Chrome started (PID: $CHROME_PID)"
echo "Debug URL: http://localhost:$PORT"
echo ""
echo "Note: First launch requires manual login to Google account at gemini.google.com"
