#!/bin/bash
# MediaScrub Installer

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.local/share/MediaScrub"
SERVICES_DIR="$HOME/Library/Services"
SUPPORT_DIR="$HOME/Library/Application Support/MediaScrub"

echo "╔══════════════════════════════════════╗"
echo "║        MediaScrub Installer          ║"
echo "║  Strip metadata. Optimize for web.   ║"
echo "╚══════════════════════════════════════╝"
echo ""

# ─── Check Dependencies ──────────────────────────────────────────────────────

echo "→ Checking dependencies..."
MISSING=""
if command -v ffmpeg &>/dev/null; then
    echo "  ✓ FFmpeg found: $(which ffmpeg)"
else
    echo "  ✗ FFmpeg not found"
    MISSING="ffmpeg"
fi

if command -v exiftool &>/dev/null; then
    echo "  ✓ exiftool found: $(which exiftool)"
else
    echo "  ✗ exiftool not found"
    MISSING="$MISSING exiftool"
fi

if [[ -n "$MISSING" ]]; then
    echo ""
    echo "  Install missing dependencies:"
    echo "    brew install $MISSING"
    echo ""
    echo "  Then re-run this installer."
    exit 1
fi

# ─── Install core script ─────────────────────────────────────────────────────

echo "→ Installing processing engine..."
mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/src/mediascrub.sh" "$INSTALL_DIR/mediascrub.sh"
chmod +x "$INSTALL_DIR/mediascrub.sh"

# ─── CLI symlink ──────────────────────────────────────────────────────────────

echo "→ Installing 'mediascrub' command..."
mkdir -p "$HOME/.local/bin"
ln -sf "$INSTALL_DIR/mediascrub.sh" "$HOME/.local/bin/mediascrub"

if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo ""
    echo "  NOTE: Add ~/.local/bin to your PATH by adding this to your ~/.zshrc:"
    echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
fi

# ─── Create support directory ─────────────────────────────────────────────────

mkdir -p "$SUPPORT_DIR"

# ─── Generate Quick Action workflows ─────────────────────────────────────────

create_workflow() {
    local name="$1"
    local mode="$2"
    local workflow_dir="$SERVICES_DIR/MediaScrub — ${name}.workflow"

    rm -rf "$workflow_dir"
    mkdir -p "$workflow_dir/Contents/QuickLook"

    local uuid1 uuid2 uuid3
    uuid1=$(uuidgen)
    uuid2=$(uuidgen)
    uuid3=$(uuidgen)

    cat > "$workflow_dir/Contents/Info.plist" << INFOPLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSServices</key>
	<array>
		<dict>
			<key>NSBackgroundColorName</key>
			<string>background</string>
			<key>NSIconName</key>
			<string>NSActionTemplate</string>
			<key>NSMenuItem</key>
			<dict>
				<key>default</key>
				<string>MediaScrub — ${name}</string>
			</dict>
			<key>NSMessage</key>
			<string>runWorkflowAsService</string>
			<key>NSRequiredContext</key>
			<dict>
				<key>NSApplicationIdentifier</key>
				<string>com.apple.finder</string>
			</dict>
			<key>NSSendFileTypes</key>
			<array>
				<string>public.image</string>
				<string>public.movie</string>
				<string>public.item</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
INFOPLIST

    cat > "$workflow_dir/Contents/document.wflow" << WFLOW
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>AMApplicationBuild</key>
	<string>534</string>
	<key>AMApplicationVersion</key>
	<string>2.10</string>
	<key>AMDocumentVersion</key>
	<string>2</string>
	<key>actions</key>
	<array>
		<dict>
			<key>action</key>
			<dict>
				<key>AMAccepts</key>
				<dict>
					<key>Container</key>
					<string>List</string>
					<key>Optional</key>
					<true/>
					<key>Types</key>
					<array>
						<string>com.apple.cocoa.string</string>
					</array>
				</dict>
				<key>AMActionVersion</key>
				<string>2.0.3</string>
				<key>AMApplication</key>
				<array>
					<string>Automator</string>
				</array>
				<key>AMParameterProperties</key>
				<dict>
					<key>COMMAND_STRING</key>
					<dict/>
					<key>CheckedForUserDefaultShell</key>
					<dict/>
					<key>inputMethod</key>
					<dict/>
					<key>shell</key>
					<dict/>
					<key>source</key>
					<dict/>
				</dict>
				<key>AMProvides</key>
				<dict>
					<key>Container</key>
					<string>List</string>
					<key>Types</key>
					<array>
						<string>com.apple.cocoa.string</string>
					</array>
				</dict>
				<key>ActionBundlePath</key>
				<string>/System/Library/Automator/Run Shell Script.action</string>
				<key>ActionName</key>
				<string>Run Shell Script</string>
				<key>ActionParameters</key>
				<dict>
					<key>COMMAND_STRING</key>
					<string>"$INSTALL_DIR/mediascrub.sh" "$mode" "\$@"</string>
					<key>CheckedForUserDefaultShell</key>
					<true/>
					<key>inputMethod</key>
					<integer>1</integer>
					<key>shell</key>
					<string>/bin/zsh</string>
					<key>source</key>
					<string></string>
				</dict>
				<key>BundleIdentifier</key>
				<string>com.apple.RunShellScript</string>
				<key>CFBundleVersion</key>
				<string>2.0.3</string>
				<key>CanShowSelectedItemsWhenRun</key>
				<false/>
				<key>CanShowWhenRun</key>
				<true/>
				<key>Category</key>
				<array>
					<string>AMCategoryUtilities</string>
				</array>
				<key>Class Name</key>
				<string>RunShellScriptAction</string>
				<key>InputUUID</key>
				<string>${uuid1}</string>
				<key>Keywords</key>
				<array>
					<string>Shell</string>
					<string>Script</string>
					<string>Command</string>
					<string>Run</string>
					<string>Unix</string>
				</array>
				<key>OutputUUID</key>
				<string>${uuid2}</string>
				<key>UUID</key>
				<string>${uuid3}</string>
				<key>UnlocalizedApplications</key>
				<array>
					<string>Automator</string>
				</array>
				<key>arguments</key>
				<dict>
					<key>0</key>
					<dict>
						<key>default value</key>
						<integer>0</integer>
						<key>name</key>
						<string>inputMethod</string>
						<key>required</key>
						<string>0</string>
						<key>type</key>
						<string>0</string>
						<key>uuid</key>
						<string>0</string>
					</dict>
					<key>1</key>
					<dict>
						<key>default value</key>
						<false/>
						<key>name</key>
						<string>CheckedForUserDefaultShell</string>
						<key>required</key>
						<string>0</string>
						<key>type</key>
						<string>0</string>
						<key>uuid</key>
						<string>1</string>
					</dict>
					<key>2</key>
					<dict>
						<key>default value</key>
						<string></string>
						<key>name</key>
						<string>source</string>
						<key>required</key>
						<string>0</string>
						<key>type</key>
						<string>0</string>
						<key>uuid</key>
						<string>2</string>
					</dict>
					<key>3</key>
					<dict>
						<key>default value</key>
						<string></string>
						<key>name</key>
						<string>COMMAND_STRING</string>
						<key>required</key>
						<string>0</string>
						<key>type</key>
						<string>0</string>
						<key>uuid</key>
						<string>3</string>
					</dict>
					<key>4</key>
					<dict>
						<key>default value</key>
						<string>/bin/sh</string>
						<key>name</key>
						<string>shell</string>
						<key>required</key>
						<string>0</string>
						<key>type</key>
						<string>0</string>
						<key>uuid</key>
						<string>4</string>
					</dict>
				</dict>
				<key>conversionLabel</key>
				<integer>0</integer>
				<key>isViewVisible</key>
				<integer>1</integer>
				<key>location</key>
				<string>309.000000:305.000000</string>
				<key>nibPath</key>
				<string>/System/Library/Automator/Run Shell Script.action/Contents/Resources/Base.lproj/main.nib</string>
			</dict>
			<key>isViewVisible</key>
			<integer>1</integer>
		</dict>
	</array>
	<key>connectors</key>
	<dict/>
	<key>workflowMetaData</key>
	<dict>
		<key>applicationBundleID</key>
		<string>com.apple.finder</string>
		<key>applicationBundleIDsByPath</key>
		<dict>
			<key>/System/Library/CoreServices/Finder.app</key>
			<string>com.apple.finder</string>
		</dict>
		<key>applicationPath</key>
		<string>/System/Library/CoreServices/Finder.app</string>
		<key>applicationPaths</key>
		<array>
			<string>/System/Library/CoreServices/Finder.app</string>
		</array>
		<key>inputTypeIdentifier</key>
		<string>com.apple.Automator.fileSystemObject</string>
		<key>outputTypeIdentifier</key>
		<string>com.apple.Automator.nothing</string>
		<key>presentationMode</key>
		<integer>15</integer>
		<key>processesInput</key>
		<false/>
		<key>serviceApplicationBundleID</key>
		<string>com.apple.finder</string>
		<key>serviceApplicationPath</key>
		<string>/System/Library/CoreServices/Finder.app</string>
		<key>serviceInputTypeIdentifier</key>
		<string>com.apple.Automator.fileSystemObject</string>
		<key>serviceOutputTypeIdentifier</key>
		<string>com.apple.Automator.nothing</string>
		<key>serviceProcessesInput</key>
		<false/>
		<key>systemImageName</key>
		<string>NSActionTemplate</string>
		<key>useAutomaticInputType</key>
		<false/>
		<key>workflowTypeIdentifier</key>
		<string>com.apple.Automator.servicesMenu</string>
	</dict>
</dict>
</plist>
WFLOW

    echo "  ✓ MediaScrub — ${name}"
}

echo ""
echo "→ Installing Quick Actions..."

create_workflow "Strip Metadata"         "strip"
create_workflow "Optimize for TikTok"    "tiktok"
create_workflow "Optimize for Instagram" "instagram"
create_workflow "Optimize for YouTube"   "youtube"
create_workflow "Optimize for Web"       "web"

# ─── Refresh & Enable ────────────────────────────────────────────────────────

echo ""
echo "→ Refreshing Finder services..."
/System/Library/CoreServices/pbs -flush 2>/dev/null || true
killall Finder 2>/dev/null || true

echo ""
echo "╔══════════════════════════════════════╗"
echo "║         Almost there!               ║"
echo "╠══════════════════════════════════════╣"
echo "║                                     ║"
echo "║  macOS requires you to enable the   ║"
echo "║  Quick Actions manually.            ║"
echo "║                                     ║"
echo "║  Opening System Settings now...     ║"
echo "║                                     ║"
echo "║  1. Click 'Finder Extensions'       ║"
echo "║  2. Toggle ON all MediaScrub items  ║"
echo "║  3. Close System Settings           ║"
echo "║                                     ║"
echo "╚══════════════════════════════════════╝"
echo ""

open "x-apple.systempreferences:com.apple.ExtensionsPreferences" 2>/dev/null || true

read -p "Press Enter after enabling the extensions... "

echo ""
echo "╔══════════════════════════════════════╗"
echo "║       Installation Complete!         ║"
echo "╠══════════════════════════════════════╣"
echo "║                                     ║"
echo "║  Right-click any image or video in   ║"
echo "║  Finder → Quick Actions → MediaScrub║"
echo "║                                     ║"
echo "║  Modes:                             ║"
echo "║    Strip Metadata — Privacy clean    ║"
echo "║    TikTok/IG/YT   — Platform ready  ║"
echo "║    Web             — Generic web     ║"
echo "║                                     ║"
echo "║  Free: 1 scrub/day                  ║"
echo "║  Unlimited: \$1/month                ║"
echo "║                                     ║"
echo "╚══════════════════════════════════════╝"
