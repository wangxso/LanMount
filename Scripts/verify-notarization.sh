#!/bin/bash
# verify-notarization.sh
# Script to verify notarization status for LanMount
#
# Usage: ./verify-notarization.sh [options] [dmg-or-app-path]
#
# Options:
#   -s, --submission-id ID  Check status of a specific submission
#   -p, --profile NAME      Keychain profile name (default: AC_PASSWORD)
#   -l, --log               Show detailed notarization log
#   -h, --help              Show this help message
#
# Examples:
#   ./verify-notarization.sh build/LanMount.dmg
#   ./verify-notarization.sh --submission-id abc-123-def
#   ./verify-notarization.sh -l --submission-id abc-123-def

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
KEYCHAIN_PROFILE="AC_PASSWORD"
SUBMISSION_ID=""
SHOW_LOG=false
INPUT_PATH=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--submission-id)
            SUBMISSION_ID="$2"
            shift 2
            ;;
        -p|--profile)
            KEYCHAIN_PROFILE="$2"
            shift 2
            ;;
        -l|--log)
            SHOW_LOG=true
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
echo "LanMount Notarization Verification"
echo "=========================================="
echo ""

# If submission ID is provided, check that specific submission
if [ -n "$SUBMISSION_ID" ]; then
    echo -e "${BLUE}Submission ID:${NC} $SUBMISSION_ID"
    echo ""
    
    echo "Checking submission status..."
    echo "-----------------------------"
    xcrun notarytool info "$SUBMISSION_ID" \
        --keychain-profile "$KEYCHAIN_PROFILE" || {
        echo -e "${RED}Error: Could not retrieve submission info${NC}"
        echo "Make sure the submission ID is correct and credentials are valid."
        exit 1
    }
    echo ""
    
    if [ "$SHOW_LOG" = true ]; then
        echo "Detailed notarization log:"
        echo "--------------------------"
        xcrun notarytool log "$SUBMISSION_ID" \
            --keychain-profile "$KEYCHAIN_PROFILE" || {
            echo -e "${YELLOW}⚠ Could not retrieve log${NC}"
        }
        echo ""
    fi
    
    exit 0
fi

# If input path is provided, verify the file
if [ -n "$INPUT_PATH" ]; then
    if [ ! -e "$INPUT_PATH" ]; then
        echo -e "${RED}Error: File not found: $INPUT_PATH${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Verifying:${NC} $INPUT_PATH"
    echo ""
    
    # Determine file type
    if [ -d "$INPUT_PATH" ]; then
        FILE_TYPE="app"
        APP_PATH="$INPUT_PATH"
    elif [[ "$INPUT_PATH" == *.dmg ]]; then
        FILE_TYPE="dmg"
    elif [[ "$INPUT_PATH" == *.zip ]]; then
        FILE_TYPE="zip"
    else
        echo -e "${YELLOW}⚠ Unknown file type${NC}"
        FILE_TYPE="unknown"
    fi
    
    echo "Step 1: Checking code signature..."
    echo "-----------------------------------"
    
    if [ "$FILE_TYPE" = "dmg" ]; then
        # Mount DMG to check the app inside
        echo "Mounting DMG..."
        MOUNT_POINT=$(hdiutil attach -readonly -nobrowse "$INPUT_PATH" 2>/dev/null | grep "/Volumes/" | awk '{print $3}')
        
        if [ -z "$MOUNT_POINT" ]; then
            echo -e "${RED}Error: Could not mount DMG${NC}"
            exit 1
        fi
        
        APP_PATH=$(find "$MOUNT_POINT" -name "*.app" -maxdepth 1 | head -1)
        
        if [ -z "$APP_PATH" ]; then
            echo -e "${RED}Error: No .app found in DMG${NC}"
            hdiutil detach "$MOUNT_POINT" -quiet
            exit 1
        fi
        
        echo "Found app: $APP_PATH"
        
        # Verify code signature
        if codesign -v "$APP_PATH" 2>/dev/null; then
            echo -e "${GREEN}✓ Code signature is valid${NC}"
        else
            echo -e "${RED}✗ Code signature is invalid${NC}"
        fi
        
        # Check Gatekeeper
        echo ""
        echo "Step 2: Checking Gatekeeper acceptance..."
        echo "-----------------------------------------"
        SPCTL_OUTPUT=$(spctl -a -t exec -vv "$APP_PATH" 2>&1) || true
        echo "$SPCTL_OUTPUT"
        
        if echo "$SPCTL_OUTPUT" | grep -q "accepted"; then
            echo ""
            echo -e "${GREEN}✓ App is accepted by Gatekeeper${NC}"
            
            if echo "$SPCTL_OUTPUT" | grep -q "Notarized Developer ID"; then
                echo -e "${GREEN}✓ App is notarized${NC}"
            elif echo "$SPCTL_OUTPUT" | grep -q "Developer ID"; then
                echo -e "${YELLOW}⚠ App is signed but may not be notarized${NC}"
            fi
        else
            echo ""
            echo -e "${RED}✗ App is not accepted by Gatekeeper${NC}"
        fi
        
        # Check stapler
        echo ""
        echo "Step 3: Checking stapled ticket..."
        echo "----------------------------------"
        if xcrun stapler validate "$APP_PATH" 2>/dev/null; then
            echo -e "${GREEN}✓ Notarization ticket is stapled${NC}"
        else
            echo -e "${YELLOW}⚠ No stapled ticket found${NC}"
            echo "Run: ./Scripts/staple-ticket.sh $INPUT_PATH"
        fi
        
        # Unmount DMG
        hdiutil detach "$MOUNT_POINT" -quiet
        
        # Also check the DMG itself
        echo ""
        echo "Step 4: Checking DMG stapled ticket..."
        echo "--------------------------------------"
        if xcrun stapler validate "$INPUT_PATH" 2>/dev/null; then
            echo -e "${GREEN}✓ DMG has stapled ticket${NC}"
        else
            echo -e "${YELLOW}⚠ DMG does not have stapled ticket${NC}"
            echo "Run: ./Scripts/staple-ticket.sh $INPUT_PATH"
        fi
        
    elif [ "$FILE_TYPE" = "app" ]; then
        # Verify code signature
        if codesign -v "$APP_PATH" 2>/dev/null; then
            echo -e "${GREEN}✓ Code signature is valid${NC}"
        else
            echo -e "${RED}✗ Code signature is invalid${NC}"
        fi
        
        # Check Gatekeeper
        echo ""
        echo "Step 2: Checking Gatekeeper acceptance..."
        echo "-----------------------------------------"
        SPCTL_OUTPUT=$(spctl -a -t exec -vv "$APP_PATH" 2>&1) || true
        echo "$SPCTL_OUTPUT"
        
        if echo "$SPCTL_OUTPUT" | grep -q "accepted"; then
            echo ""
            echo -e "${GREEN}✓ App is accepted by Gatekeeper${NC}"
        else
            echo ""
            echo -e "${RED}✗ App is not accepted by Gatekeeper${NC}"
        fi
        
        # Check stapler
        echo ""
        echo "Step 3: Checking stapled ticket..."
        echo "----------------------------------"
        if xcrun stapler validate "$APP_PATH" 2>/dev/null; then
            echo -e "${GREEN}✓ Notarization ticket is stapled${NC}"
        else
            echo -e "${YELLOW}⚠ No stapled ticket found${NC}"
        fi
    fi
    
    echo ""
    echo "=========================================="
    echo "Verification Complete"
    echo "=========================================="
    exit 0
fi

# If no arguments, show recent submissions
echo "No file or submission ID specified."
echo ""
echo "Showing recent notarization submissions..."
echo "------------------------------------------"
xcrun notarytool history \
    --keychain-profile "$KEYCHAIN_PROFILE" 2>/dev/null || {
    echo -e "${YELLOW}⚠ Could not retrieve submission history${NC}"
    echo ""
    echo "Make sure credentials are configured:"
    echo "  xcrun notarytool store-credentials \"$KEYCHAIN_PROFILE\" \\"
    echo "      --apple-id \"your@email.com\" \\"
    echo "      --team-id \"YOUR_TEAM_ID\" \\"
    echo "      --password \"your-app-specific-password\""
}

echo ""
echo "Usage:"
echo "  $0 <dmg-or-app-path>           Verify a file"
echo "  $0 --submission-id <id>        Check submission status"
echo "  $0 --submission-id <id> --log  Show detailed log"
echo ""
