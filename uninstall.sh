#!/bin/bash
set -euo pipefail
echo "Uninstalling MediaScrub..."
rm -rf "$HOME/Library/Services/MediaScrub —"*.workflow 2>/dev/null || true
rm -rf "$HOME/.local/share/MediaScrub" 2>/dev/null || true
rm -f "$HOME/.local/bin/mediascrub" 2>/dev/null || true
rm -rf "$HOME/Library/Application Support/MediaScrub" 2>/dev/null || true
/System/Library/CoreServices/pbs -flush 2>/dev/null || true
echo "MediaScrub uninstalled. FFmpeg and exiftool were NOT removed."
