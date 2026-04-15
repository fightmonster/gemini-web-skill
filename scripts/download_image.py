#!/usr/bin/env python3
"""Save base64 image data (from stdin) to a file.

Usage:
    echo "<base64_data>" | python3 download_image.py --output ~/Downloads/gemini_image.jpg
"""
import sys
import base64
import argparse
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description='Save base64 image data to a file')
    parser.add_argument('--output', required=True, help='Output file path')
    args = parser.parse_args()

    if sys.stdin.isatty():
        print("Error: Pipe base64 data via stdin", file=sys.stderr)
        sys.exit(1)

    b64_data = sys.stdin.read().strip()

    try:
        img_data = base64.b64decode(b64_data)
    except Exception as e:
        print(f"Error decoding base64: {e}", file=sys.stderr)
        sys.exit(1)

    output_path = Path(args.output).expanduser()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(img_data)

    size_kb = len(img_data) / 1024
    print(f"Saved: {output_path} ({size_kb:.1f} KB)")


if __name__ == '__main__':
    main()
