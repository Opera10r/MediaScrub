#!/bin/bash
# MediaScrub — Media Metadata Stripper & Platform Optimizer
# Right-click any image/video → strip metadata, optimize for platforms
# Usage: mediascrub.sh <mode> <file1> [file2] ...
# Modes: strip, tiktok, instagram, youtube, web

set -uo pipefail

# ─── Config ───────────────────────────────────────────────────────────────────

APP_NAME="MediaScrub"
SUPPORT_DIR="$HOME/Library/Application Support/MediaScrub"
USAGE_FILE="$SUPPORT_DIR/usage"
DAILY_LIMIT=1
LICENSE_FILE="$SUPPORT_DIR/license"
LICENSE_KEY_FILE="$SUPPORT_DIR/license_key"
API_URL="https://mediascrub-worker.opera10r.workers.dev"
LOG_FILE="$SUPPORT_DIR/debug.log"

IMAGE_EXTENSIONS="jpg jpeg png webp heic heif tiff tif bmp gif"
VIDEO_EXTENSIONS="mp4 mov m4v avi mkv webm mts m2ts 3gp flv wmv"

# ─── Setup ────────────────────────────────────────────────────────────────────

mkdir -p "$SUPPORT_DIR"

# ─── Find Binaries ────────────────────────────────────────────────────────────

find_binary() {
    local name="$1"
    local paths=(
        "/opt/homebrew/bin/$name"
        "/usr/local/bin/$name"
        "$HOME/.local/share/MediaScrub/$name"
        "$HOME/.local/share/AudioRip/$name"
        "$HOME/.local/share/AudioForge/$name"
    )
    for p in "${paths[@]}"; do
        [[ -x "$p" ]] && { echo "$p"; return 0; }
    done
    command -v "$name" 2>/dev/null && return 0
    return 1
}

FFMPEG=$(find_binary ffmpeg) || FFMPEG=""
FFPROBE=$(find_binary ffprobe) || FFPROBE=""
EXIFTOOL=$(find_binary exiftool) || EXIFTOOL=""

# ─── Logging ──────────────────────────────────────────────────────────────────

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null
}

# ─── Notification ─────────────────────────────────────────────────────────────

notify() {
    local title="$1"
    local body="$2"
    body="${body//\\/\\\\}"
    body="${body//\"/\\\"}"
    osascript -e "display notification \"$body\" with title \"$title\"" 2>/dev/null &
}

# ─── Usage Tracking ──────────────────────────────────────────────────────────

check_usage() {
    if [[ -f "$LICENSE_FILE" ]] && [[ "$(cat "$LICENSE_FILE" 2>/dev/null)" == "active" ]]; then
        return 0
    fi

    local today
    today=$(date +%Y-%m-%d)

    if [[ -f "$USAGE_FILE" ]]; then
        local stored_date stored_count
        stored_date=$(cut -d: -f1 "$USAGE_FILE")
        stored_count=$(cut -d: -f2 "$USAGE_FILE")

        if [[ "$stored_date" == "$today" ]] && (( stored_count >= DAILY_LIMIT )); then
            notify "Daily Free Scrub Used" "Unlimited scrubs for \$1/month."
            exit 0
        fi
    fi
}

increment_usage() {
    if [[ -f "$LICENSE_FILE" ]] && [[ "$(cat "$LICENSE_FILE" 2>/dev/null)" == "active" ]]; then
        return 0
    fi

    local today
    today=$(date +%Y-%m-%d)

    if [[ -f "$USAGE_FILE" ]]; then
        local stored_date stored_count
        stored_date=$(cut -d: -f1 "$USAGE_FILE")
        stored_count=$(cut -d: -f2 "$USAGE_FILE")

        if [[ "$stored_date" == "$today" ]]; then
            echo "${today}:$(( stored_count + 1 ))" > "$USAGE_FILE"
            return
        fi
    fi

    echo "${today}:1" > "$USAGE_FILE"
}

# ─── File Type Detection ─────────────────────────────────────────────────────

get_file_type() {
    local ext="${1##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    if echo "$IMAGE_EXTENSIONS" | grep -qw "$ext"; then
        echo "image"
    elif echo "$VIDEO_EXTENSIONS" | grep -qw "$ext"; then
        echo "video"
    else
        echo "unknown"
    fi
}

# ─── Strip Image Metadata ────────────────────────────────────────────────────

strip_image() {
    local input="$1"
    local base="${input%.*}"
    local ext="${input##*.}"
    local output="${base}_clean.${ext}"

    # Handle name collision
    if [[ -f "$output" ]]; then
        local counter=2
        while [[ -f "${base}_clean_${counter}.${ext}" ]]; do
            (( counter++ ))
        done
        output="${base}_clean_${counter}.${ext}"
    fi

    if [[ -z "$EXIFTOOL" ]]; then
        notify "MediaScrub Error" "exiftool not found. Install with: brew install exiftool"
        return 1
    fi

    # Copy file first, then strip metadata from the copy
    cp "$input" "$output" || { notify "MediaScrub Error" "Failed to copy file."; return 1; }

    # Strip ALL metadata
    "$EXIFTOOL" -all= -overwrite_original "$output" 2>/dev/null

    if [[ $? -ne 0 ]]; then
        rm -f "$output"
        notify "MediaScrub Error" "Failed to strip metadata."
        return 1
    fi

    local original_size=$(stat -f%z "$input" 2>/dev/null || echo 0)
    local clean_size=$(stat -f%z "$output" 2>/dev/null || echo 0)
    local saved=$(( original_size - clean_size ))
    local saved_kb=$(( saved / 1024 ))

    log "Image stripped: $input → $output (saved ${saved_kb}KB)"
    echo "$output"
    return 0
}

# ─── Strip/Optimize Video ────────────────────────────────────────────────────

process_video() {
    local input="$1"
    local mode="$2"
    local base="${input%.*}"
    local output="${base}_clean.mp4"

    # Handle name collision
    if [[ -f "$output" ]]; then
        local counter=2
        while [[ -f "${base}_clean_${counter}.mp4" ]]; do
            (( counter++ ))
        done
        output="${base}_clean_${counter}.mp4"
    fi

    if [[ -z "$FFMPEG" ]]; then
        notify "MediaScrub Error" "FFmpeg not found. Install with: brew install ffmpeg"
        return 1
    fi

    local video_args=()
    local audio_args=()

    case "$mode" in
        strip)
            # Strip metadata only, copy streams
            video_args=(-c:v copy)
            audio_args=(-c:a copy)
            ;;
        tiktok)
            # TikTok: H.264, 30fps, yuv420p, AAC stereo, max 1080p
            video_args=(-c:v libx264 -preset medium -crf 23 -pix_fmt yuv420p
                        -r 30 -vf "scale='min(1080,iw)':'min(1920,ih)':force_original_aspect_ratio=decrease,pad=ceil(iw/2)*2:ceil(ih/2)*2")
            audio_args=(-c:a aac -b:a 128k -ar 44100 -ac 2)
            ;;
        instagram)
            # Instagram: H.264, 30fps, yuv420p, AAC stereo, max 1080p
            video_args=(-c:v libx264 -preset medium -crf 22 -pix_fmt yuv420p
                        -r 30 -vf "scale='min(1080,iw)':'min(1080,ih)':force_original_aspect_ratio=decrease,pad=ceil(iw/2)*2:ceil(ih/2)*2")
            audio_args=(-c:a aac -b:a 128k -ar 44100 -ac 2)
            ;;
        youtube)
            # YouTube: H.264 High, 60fps preserved, yuv420p, AAC stereo
            video_args=(-c:v libx264 -preset medium -crf 20 -profile:v high -pix_fmt yuv420p
                        -vf "scale='min(3840,iw)':'min(2160,ih)':force_original_aspect_ratio=decrease,pad=ceil(iw/2)*2:ceil(ih/2)*2")
            audio_args=(-c:a aac -b:a 192k -ar 48000 -ac 2)
            ;;
        web)
            # Generic web: H.264 Main, 30fps, yuv420p, AAC stereo, max 1080p
            video_args=(-c:v libx264 -preset medium -crf 23 -profile:v main -pix_fmt yuv420p
                        -r 30 -vf "scale='min(1920,iw)':'min(1080,ih)':force_original_aspect_ratio=decrease,pad=ceil(iw/2)*2:ceil(ih/2)*2")
            audio_args=(-c:a aac -b:a 128k -ar 44100 -ac 2)
            ;;
    esac

    log "CMD: $FFMPEG -y -i $input -map_metadata -1 ${video_args[*]} ${audio_args[*]} $output"

    "$FFMPEG" -y \
        -i "$input" \
        -map_metadata -1 \
        -map_chapters -1 \
        "${video_args[@]}" \
        "${audio_args[@]}" \
        "$output" 2>/dev/null

    if [[ $? -ne 0 ]]; then
        rm -f "$output"
        log "FFmpeg error processing: $input"
        notify "MediaScrub Error" "Failed to process video."
        return 1
    fi

    if [[ ! -f "$output" ]] || [[ $(stat -f%z "$output" 2>/dev/null || echo 0) -eq 0 ]]; then
        rm -f "$output"
        notify "MediaScrub Error" "Output file is empty."
        return 1
    fi

    local original_size=$(stat -f%z "$input" 2>/dev/null || echo 0)
    local clean_size=$(stat -f%z "$output" 2>/dev/null || echo 0)
    local orig_mb=$(python3 -c "print(f'{$original_size/1048576:.1f}')" 2>/dev/null || echo "?")
    local clean_mb=$(python3 -c "print(f'{$clean_size/1048576:.1f}')" 2>/dev/null || echo "?")

    log "Video processed: $input → $output (${orig_mb}MB → ${clean_mb}MB)"
    echo "$output"
    return 0
}

# ─── Process Single File ─────────────────────────────────────────────────────

process_file() {
    local filepath="$1"
    local mode="$2"
    local file_type

    file_type=$(get_file_type "$filepath")

    case "$file_type" in
        image)
            if [[ "$mode" == "strip" ]]; then
                strip_image "$filepath"
            else
                # For platform modes, strip metadata from images too
                strip_image "$filepath"
            fi
            ;;
        video)
            process_video "$filepath" "$mode"
            ;;
        *)
            notify "MediaScrub Error" "Unsupported file type: $(basename "$filepath")"
            log "Unsupported: $filepath"
            return 1
            ;;
    esac
}

# ─── License Activation ───────────────────────────────────────────────────────

activate_license() {
    local key="$1"

    if [[ -z "$key" ]]; then
        echo "Usage: mediascrub activate <license_key>"
        exit 1
    fi

    if [[ ! "$key" == ms_* ]]; then
        echo "Error: License keys start with ms_"
        exit 1
    fi

    echo "Validating license key..."

    local response
    response=$(curl -s -X POST "$API_URL/validate-license" \
        -H "Content-Type: application/json" \
        -d "{\"license_key\": \"$key\"}" 2>/dev/null)

    if [[ -z "$response" ]]; then
        echo "Error: Could not reach license server."
        exit 1
    fi

    local valid
    valid=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('valid', False))" 2>/dev/null)

    if [[ "$valid" == "True" ]]; then
        echo "$key" > "$LICENSE_KEY_FILE"
        echo "active" > "$LICENSE_FILE"
        echo "License activated! Unlimited scrubs unlocked."
    else
        echo "Error: Invalid or expired license key."
        exit 1
    fi
}

deactivate_license() {
    rm -f "$LICENSE_FILE" "$LICENSE_KEY_FILE"
    echo "License deactivated. Back to free tier (1 scrub/day)."
}

show_status() {
    echo "MediaScrub v1.0.0"
    echo ""
    if [[ -f "$LICENSE_FILE" ]] && [[ "$(cat "$LICENSE_FILE")" == "active" ]]; then
        local key
        key=$(cat "$LICENSE_KEY_FILE" 2>/dev/null || echo "unknown")
        echo "License: Active (${key:0:10}...)"
        echo "Scrubs:  Unlimited"
    else
        local today count remaining
        today=$(date +%Y-%m-%d)
        if [[ -f "$USAGE_FILE" ]]; then
            local stored_date stored_count
            stored_date=$(cut -d: -f1 "$USAGE_FILE")
            stored_count=$(cut -d: -f2 "$USAGE_FILE")
            if [[ "$stored_date" == "$today" ]]; then
                count=$stored_count
            else
                count=0
            fi
        else
            count=0
        fi
        remaining=$(( DAILY_LIMIT - count ))
        if (( remaining < 0 )); then remaining=0; fi
        echo "License: Free tier"
        echo "Today:   $count/$DAILY_LIMIT scrubs used ($remaining remaining)"
    fi
    echo ""
    echo "FFmpeg:   ${FFMPEG:-not found}"
    echo "Exiftool: ${EXIFTOOL:-not found}"
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: mediascrub <mode> <file1> [file2] ..."
        echo "       mediascrub activate <license_key>"
        echo "       mediascrub deactivate"
        echo "       mediascrub status"
        echo ""
        echo "Modes:"
        echo "  strip     — Strip all metadata, keep original quality"
        echo "  tiktok    — Strip metadata + optimize for TikTok"
        echo "  instagram — Strip metadata + optimize for Instagram"
        echo "  youtube   — Strip metadata + optimize for YouTube"
        echo "  web       — Strip metadata + optimize for generic web"
        exit 1
    fi

    case "$1" in
        activate)   activate_license "${2:-}"; exit 0 ;;
        deactivate) deactivate_license; exit 0 ;;
        status)     show_status; exit 0 ;;
    esac

    if [[ $# -lt 2 ]]; then
        echo "Usage: mediascrub <mode> <file1> [file2] ..."
        exit 1
    fi

    local mode="$1"
    shift
    local files=("$@")

    case "$mode" in
        strip|tiktok|instagram|youtube|web) ;;
        *)
            echo "Unknown mode: $mode"
            echo "Use: strip, tiktok, instagram, youtube, or web"
            exit 1
            ;;
    esac

    check_usage

    local success_count=0
    local fail_count=0
    local total=${#files[@]}
    local total_orig=0
    local total_clean=0

    for filepath in "${files[@]}"; do
        if (( total > 1 )); then
            notify "MediaScrub" "Processing $(( success_count + fail_count + 1 )) of $total..."
        fi

        local output
        if output=$(process_file "$filepath" "$mode"); then
            (( success_count++ ))
            if [[ -f "$filepath" ]] && [[ -f "$output" ]]; then
                local os cs
                os=$(stat -f%z "$filepath" 2>/dev/null || echo 0)
                cs=$(stat -f%z "$output" 2>/dev/null || echo 0)
                total_orig=$(( total_orig + os ))
                total_clean=$(( total_clean + cs ))
            fi
        else
            (( fail_count++ ))
        fi
    done

    # Final notification
    if (( total == 1 )) && (( success_count == 1 )); then
        local orig_mb=$(python3 -c "print(f'{$total_orig/1048576:.1f}')" 2>/dev/null || echo "?")
        local clean_mb=$(python3 -c "print(f'{$total_clean/1048576:.1f}')" 2>/dev/null || echo "?")
        if [[ "$mode" == "strip" ]]; then
            notify "Metadata Stripped" "$(basename "${files[0]}") · ${orig_mb}MB → ${clean_mb}MB"
        else
            notify "Optimized for ${mode}" "$(basename "${files[0]}") · ${orig_mb}MB → ${clean_mb}MB"
        fi
    elif (( total > 1 )); then
        local orig_mb=$(python3 -c "print(f'{$total_orig/1048576:.1f}')" 2>/dev/null || echo "?")
        local clean_mb=$(python3 -c "print(f'{$total_clean/1048576:.1f}')" 2>/dev/null || echo "?")
        notify "Batch Complete" "$success_count of $total files cleaned · ${orig_mb}MB → ${clean_mb}MB"
    fi

    increment_usage
}

main "$@"
