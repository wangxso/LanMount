#!/bin/bash
# build-dmg.sh
# Script to create a DMG installer package for LanMount
#
# Usage: ./build-dmg.sh [options]
#
# Options:
#   -a, --app-path PATH     Path to the signed .app bundle (default: build/Release/LanMount.app)
#   -o, --output PATH       Output DMG path (default: build/LanMount.dmg)
#   -v, --volume-name NAME  Volume name (default: LanMount)
#   -h, --help              Show this help message
#
# Prerequisites:
#   - The app must be built and code signed before creating the DMG
#   - Run verify-codesign.sh to verify the app is properly signed

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
APP_PATH="build/Release/LanMount.app"
OUTPUT_PATH="build/LanMount.dmg"
VOLUME_NAME="LanMount"
TEMP_DIR=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--app-path)
            APP_PATH="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_PATH="$2"
            shift 2
            ;;
        -v|--volume-name)
            VOLUME_NAME="$2"
            shift 2
            ;;
        -h|--help)
            head -20 "$0" | tail -15
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Cleanup function
cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        echo "Cleaning up temporary files..."
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

echo "=========================================="
echo "LanMount DMG Builder"
echo "=========================================="
echo ""

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: App not found at $APP_PATH${NC}"
    echo ""
    echo "Please build the app first:"
    echo "  xcodebuild -project LanMount.xcodeproj -scheme LanMount -configuration Release build"
    exit 1
fi

echo -e "${BLUE}App Path:${NC} $APP_PATH"
echo -e "${BLUE}Output:${NC} $OUTPUT_PATH"
echo -e "${BLUE}Volume Name:${NC} $VOLUME_NAME"
echo ""

# Verify code signature before creating DMG
echo "Step 1: Verifying code signature..."
echo "------------------------------------"
if codesign -v "$APP_PATH" 2>/dev/null; then
    echo -e "${GREEN}✓ Code signature is valid${NC}"
else
    echo -e "${RED}✗ Code signature is invalid or missing${NC}"
    echo "Please sign the app before creating the DMG."
    echo "Run: ./Scripts/verify-codesign.sh $APP_PATH"
    exit 1
fi
echo ""

# Create output directory if needed
OUTPUT_DIR=$(dirname "$OUTPUT_PATH")
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Creating output directory: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
fi

# Remove existing DMG if present
if [ -f "$OUTPUT_PATH" ]; then
    echo "Removing existing DMG..."
    rm -f "$OUTPUT_PATH"
fi

# Create temporary directory for DMG contents
echo "Step 2: Preparing DMG contents..."
echo "----------------------------------"
TEMP_DIR=$(mktemp -d)
DMG_CONTENTS="$TEMP_DIR/dmg_contents"
mkdir -p "$DMG_CONTENTS"

# Copy app to temporary directory
echo "Copying app bundle..."
cp -R "$APP_PATH" "$DMG_CONTENTS/"

# Create Applications symlink for drag-and-drop installation
echo "Creating Applications symlink..."
ln -s /Applications "$DMG_CONTENTS/Applications"

# Create a simple README for the DMG
cat > "$DMG_CONTENTS/README.txt" << 'EOF'
LanMount - macOS SMB Mounter

Installation:
1. Drag LanMount.app to the Applications folder
2. Launch LanMount from Applications
3. Grant necessary permissions when prompted

For more information, visit:
https://github.com/your-repo/lanmount

EOF

echo -e "${GREEN}✓ DMG contents prepared${NC}"
echo ""

# Create the DMG
echo "Step 3: Creating DMG..."
echo "-----------------------"

# First create a temporary read-write DMG
TEMP_DMG="$TEMP_DIR/temp.dmg"
echo "Creating temporary DMG..."
hdiutil create -srcfolder "$DMG_CONTENTS" \
    -volname "$VOLUME_NAME" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    "$TEMP_DMG"

# Mount the temporary DMG to customize it
echo "Mounting temporary DMG for customization..."
MOUNT_POINT=$(hdiutil attach -readwrite -noverify "$TEMP_DMG" | grep "/Volumes/" | awk '{print $3}')

if [ -n "$MOUNT_POINT" ]; then
    echo "Mounted at: $MOUNT_POINT"
    
    # Set custom icon positions (optional - requires additional setup)
    # This creates a basic .DS_Store for icon arrangement
    # For more advanced customization, use a tool like create-dmg
    
    # Unmount with retry
    echo "Unmounting temporary DMG..."
    UNMOUNT_RETRIES=5
    UNMOUNT_SUCCESS=false
    
    for i in $(seq 1 $UNMOUNT_RETRIES); do
        if hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null; then
            UNMOUNT_SUCCESS=true
            break
        fi
        echo "Unmount attempt $i failed, retrying in 2 seconds..."
        sleep 2
    done
    
    if [ "$UNMOUNT_SUCCESS" = false ]; then
        echo -e "${YELLOW}⚠ Warning: Could not unmount cleanly, forcing unmount...${NC}"
        hdiutil detach "$MOUNT_POINT" -force || true
        sleep 2
    fi
fi

# Wait a moment to ensure filesystem is ready
sleep 1

# Convert to compressed read-only DMG with retry
echo "Converting to compressed DMG..."
CONVERT_RETRIES=3
CONVERT_SUCCESS=false

for i in $(seq 1 $CONVERT_RETRIES); do
    if hdiutil convert "$TEMP_DMG" \
        -format UDZO \
        -imagekey zlib-level=9 \
        -o "$OUTPUT_PATH" 2>/dev/null; then
        CONVERT_SUCCESS=true
        break
    fi
    
    if [ $i -lt $CONVERT_RETRIES ]; then
        echo "Conversion attempt $i failed, retrying in 3 seconds..."
        sleep 3
    fi
done

if [ "$CONVERT_SUCCESS" = false ]; then
    echo -e "${RED}✗ DMG conversion failed after $CONVERT_RETRIES attempts${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "1. Check if any DMG is still mounted: hdiutil info"
    echo "2. Force unmount all: hdiutil detach -all -force"
    echo "3. Try again"
    exit 1
fi

echo -e "${GREEN}✓ DMG created successfully${NC}"
echo ""

# Verify the DMG
echo "Step 4: Verifying DMG..."
echo "------------------------"
if hdiutil verify "$OUTPUT_PATH" 2>/dev/null; then
    echo -e "${GREEN}✓ DMG verification passed${NC}"
else
    echo -e "${YELLOW}⚠ DMG verification had warnings${NC}"
fi

# Get DMG info
DMG_SIZE=$(du -h "$OUTPUT_PATH" | cut -f1)
echo ""
echo "=========================================="
echo "DMG Build Complete"
echo "=========================================="
echo ""
echo -e "${GREEN}Output:${NC} $OUTPUT_PATH"
echo -e "${GREEN}Size:${NC} $DMG_SIZE"
echo ""
echo "Next steps:"
echo "1. Test the DMG by mounting and installing the app"
echo "2. Submit for notarization: ./Scripts/notarize-app.sh $OUTPUT_PATH"
echo ""
