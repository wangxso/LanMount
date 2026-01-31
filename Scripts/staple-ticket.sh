#!/bin/bash
# staple-ticket.sh
# Script to staple the notarization ticket to the LanMount DMG or app
#
# Usage: ./staple-ticket.sh [options] <dmg-or-app-path>
#
# Options:
#   -v, --verify    Verify stapling after completion
#   -h, --help      Show this help message
#
# Prerequisites:
#   - The app/DMG must have been successfully notarized
#   - Run notarize-app.sh first and wait for approval
#
# What is stapling?
#   Stapling attaches the notarization ticket directly to your app or DMG.
#   This allows Gatekeeper to verify the app even when offline.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
VERIFY_AFTER=true
INPUT_PATH=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verify)
            VERIFY_AFTER=true
            shift
            ;;
        --no-verify)
            VERIFY_AFTER=false
            shift
            ;;
        -h|--help)
            head -18 "$0" | tail -14
            exit 0
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
        *)
            INPUT_PATH="$1"
            shift
            ;;
    esac
done

echo "=========================================="
echo "LanMount Ticket Stapling"
echo "=========================================="
echo ""

# Check if input path is provided
if [ -z "$INPUT_PATH" ]; then
    echo -e "${RED}Error: No input file specified${NC}"
    echo ""
    echo "Usage: $0 [options] <dmg-or-app-path>"
    echo ""
    echo "Example:"
    echo "  $0 build/LanMount.dmg"
    echo "  $0 build/Release/LanMount.app"
    exit 1
fi

# Check if input exists
if [ ! -e "$INPUT_PATH" ]; then
    echo -e "${RED}Error: File not found: $INPUT_PATH${NC}"
    exit 1
fi

echo -e "${BLUE}Input:${NC} $INPUT_PATH"
echo ""

# Determine file type
if [ -d "$INPUT_PATH" ]; then
    FILE_TYPE="app"
    echo "File type: Application bundle"
elif [[ "$INPUT_PATH" == *.dmg ]]; then
    FILE_TYPE="dmg"
    echo "File type: Disk image (DMG)"
elif [[ "$INPUT_PATH" == *.pkg ]]; then
    FILE_TYPE="pkg"
    echo "File type: Installer package"
elif [[ "$INPUT_PATH" == *.zip ]]; then
    echo -e "${RED}Error: Cannot staple to ZIP files${NC}"
    echo ""
    echo "ZIP files cannot be stapled. Options:"
    echo "1. Staple the .app before creating the ZIP"
    echo "2. Use a DMG instead of ZIP for distribution"
    exit 1
else
    echo -e "${YELLOW}⚠ Unknown file type, attempting to staple anyway${NC}"
    FILE_TYPE="unknown"
fi
echo ""

# Staple the ticket
echo "Step 1: Stapling notarization ticket..."
echo "---------------------------------------"

if xcrun stapler staple "$INPUT_PATH"; then
    echo ""
    echo -e "${GREEN}✓ Ticket stapled successfully${NC}"
else
    echo ""
    echo -e "${RED}✗ Failed to staple ticket${NC}"
    echo ""
    echo "Possible reasons:"
    echo "1. The app/DMG has not been notarized yet"
    echo "2. Notarization is still in progress"
    echo "3. Notarization was rejected"
    echo ""
    echo "Check notarization status:"
    echo "  ./Scripts/verify-notarization.sh $INPUT_PATH"
    exit 1
fi
echo ""

# If it's a DMG, also staple the app inside
if [ "$FILE_TYPE" = "dmg" ]; then
    echo "Step 2: Stapling app inside DMG..."
    echo "----------------------------------"
    echo "Note: The app inside the DMG should already have the ticket"
    echo "from the notarization process. This step is optional."
    echo ""
    
    # Mount DMG
    MOUNT_POINT=$(hdiutil attach -readonly -nobrowse "$INPUT_PATH" 2>/dev/null | grep "/Volumes/" | awk '{print $3}')
    
    if [ -n "$MOUNT_POINT" ]; then
        APP_PATH=$(find "$MOUNT_POINT" -name "*.app" -maxdepth 1 | head -1)
        
        if [ -n "$APP_PATH" ]; then
            echo "Found app: $APP_PATH"
            
            # Check if app has ticket
            if xcrun stapler validate "$APP_PATH" 2>/dev/null; then
                echo -e "${GREEN}✓ App inside DMG already has stapled ticket${NC}"
            else
                echo -e "${YELLOW}⚠ App inside DMG does not have stapled ticket${NC}"
                echo "This is normal for read-only DMGs."
            fi
        fi
        
        # Unmount
        hdiutil detach "$MOUNT_POINT" -quiet
    fi
    echo ""
fi

# Verify stapling
if [ "$VERIFY_AFTER" = true ]; then
    echo "Step 3: Verifying stapled ticket..."
    echo "-----------------------------------"
    
    if xcrun stapler validate "$INPUT_PATH"; then
        echo ""
        echo -e "${GREEN}✓ Stapled ticket is valid${NC}"
    else
        echo ""
        echo -e "${RED}✗ Stapled ticket validation failed${NC}"
        exit 1
    fi
    echo ""
fi

# Final verification with Gatekeeper
echo "Step 4: Gatekeeper verification..."
echo "----------------------------------"

if [ "$FILE_TYPE" = "dmg" ]; then
    # Mount and check the app
    MOUNT_POINT=$(hdiutil attach -readonly -nobrowse "$INPUT_PATH" 2>/dev/null | grep "/Volumes/" | awk '{print $3}')
    
    if [ -n "$MOUNT_POINT" ]; then
        APP_PATH=$(find "$MOUNT_POINT" -name "*.app" -maxdepth 1 | head -1)
        
        if [ -n "$APP_PATH" ]; then
            SPCTL_OUTPUT=$(spctl -a -t exec -vv "$APP_PATH" 2>&1) || true
            
            if echo "$SPCTL_OUTPUT" | grep -q "accepted"; then
                echo -e "${GREEN}✓ App is accepted by Gatekeeper${NC}"
                
                if echo "$SPCTL_OUTPUT" | grep -q "Notarized Developer ID"; then
                    echo -e "${GREEN}✓ Notarization confirmed${NC}"
                fi
            else
                echo -e "${YELLOW}⚠ Gatekeeper check inconclusive${NC}"
            fi
        fi
        
        hdiutil detach "$MOUNT_POINT" -quiet
    fi
elif [ "$FILE_TYPE" = "app" ]; then
    SPCTL_OUTPUT=$(spctl -a -t exec -vv "$INPUT_PATH" 2>&1) || true
    
    if echo "$SPCTL_OUTPUT" | grep -q "accepted"; then
        echo -e "${GREEN}✓ App is accepted by Gatekeeper${NC}"
        
        if echo "$SPCTL_OUTPUT" | grep -q "Notarized Developer ID"; then
            echo -e "${GREEN}✓ Notarization confirmed${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Gatekeeper check inconclusive${NC}"
    fi
fi

echo ""
echo "=========================================="
echo "Stapling Complete"
echo "=========================================="
echo ""
echo "The notarization ticket has been stapled to: $INPUT_PATH"
echo ""
echo "Your app is now ready for distribution!"
echo ""
echo "Users can verify the notarization by running:"
echo "  spctl -a -v /path/to/LanMount.app"
echo ""
