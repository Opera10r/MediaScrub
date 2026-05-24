# MediaScrub

**Right-click any image or video in macOS Finder. Strip all metadata. Optimize for any platform.**

Privacy-clean your media in one right-click. No uploads. 100% local.

## The Problem

Every photo and video embeds hidden metadata: GPS coordinates, camera serial numbers, timestamps, device info. When you share files, that data goes with them. MediaScrub strips it all — and optionally optimizes your video for TikTok, Instagram, YouTube, or web.

## Modes

| Mode | What It Does |
|------|-------------|
| Strip Metadata | Remove all EXIF/XMP/IPTC data, keep original quality |
| TikTok | Strip metadata + H.264, 30fps, 1080p, AAC stereo |
| Instagram | Strip metadata + H.264, 30fps, 1080p square-safe |
| YouTube | Strip metadata + H.264 High, up to 4K, AAC 192k |
| Web | Strip metadata + H.264 Main, 30fps, 1080p, small file |

## Install

```bash
# Install dependencies
brew install ffmpeg exiftool

# Install MediaScrub
git clone https://github.com/opera10r/MediaScrub.git
cd MediaScrub
./install.sh
```

The installer opens **System Settings** automatically. Toggle ON all 5 MediaScrub actions under **Finder Extensions**, then press Enter.

Right-click any image or video → **Quick Actions** → pick a MediaScrub mode.

## How It Works

- **Images**: Strips all EXIF, XMP, IPTC metadata (GPS, camera info, timestamps)
- **Videos**: Strips metadata containers + optionally re-encodes to platform specs
- **Output**: Creates a `_clean` copy next to the original. Originals are never modified.
- **Batch**: Select multiple files, right-click, process all at once.

## Supported Formats

**Images**: JPG, PNG, WebP, HEIC, TIFF, BMP, GIF
**Videos**: MP4, MOV, M4V, AVI, MKV, WebM, MTS, 3GP, FLV, WMV

## Pricing

- **Free**: 1 scrub per day
- **Unlimited**: $1/month

```bash
mediascrub activate <your_license_key>
mediascrub status
```

## Requirements

- macOS 13+
- FFmpeg (`brew install ffmpeg`)
- exiftool (`brew install exiftool`)

## License

MIT

---

Built by Raven's Gate Publishers LLC
