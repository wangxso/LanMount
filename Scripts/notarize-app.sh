#!/bin/bash
# notarize-app.sh
# Script to submit the LanMount app to Apple's notarization service
#
# Usage: ./notarize-app.sh [options] <dmg-or-zip-path>
#
# Options:
#   -p, --profile NAME      Keychain profile name for credentials (default: AC_PASSWORD)
#   -w, --wait              Wait for notarization to complete (default: true)
#   -t, --timeout SECONDS   Timeout for waiting (default: 3600)
#   -h, --help              Show this help message
#
# Prerequisites:
#   1. Apple Developer account with Developer ID certificate
#   2. App-specific password generated at appleid.apple.com
#   3. Credentials stored in keychain (see setup instructions below)
#
# Setup (one-time):
#   xcrun notarytool store-credentials "AC_PASSWORD" \
#       --apple-id "your@email.com" \
#       --team-id "YOUR_TEAM_ID" \
#       --password "your-app-specific-password"

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
KEYCHAIN_PROFILE="AC_PASSWORD"
WAIT_FOR_COMPLETION=true
TIMEOUT=3600
INPUT_PATH=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--profile)
            KEYCHAIN_PROFILE="$2"
            shift 2
            ;;
        -w|--wait)
            WAIT_FOR_COMPLETION=true
            shift
            ;;
        --no-wait)
            WAIT_FOR_COMPLETION=false
            shift
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -h|--help)
            head -25 "$0" | tail -20
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
echo "LanMount Notarization Submission"
echo "=========================================="
echo ""

# Check if input path is provided
if [ -z "$INPUT_PATH" ]; then
    echo -e "${RED}Error: No input file specified${NC}"
    echo ""
    echo "Usage: $0 [options] <dmg-or-zip-path>"
    echo ""
    echo "Example:"
    echo "  $0 build/LanMount.dmg"
    echo "  $0 --profile MY_PROFILE build/LanMount.zip"
    exit 1
fi

# Check if input file exists
if [ ! -f "$INPUT_PATH" ]; then
    echo -e "${RED}Error: File not found: $INPUT_PATH${NC}"
    exit 1
fi

echo -e "${BLUE}Input File:${NC} $INPUT_PATH"
echo -e "${BLUE}Keychain Profile:${NC} $KEYCHAIN_PROFILE"
echo -e "${BLUE}Wait for Completion:${NC} $WAIT_FOR_COMPLETION"
echo ""

# Check if credentials are configured
echo "Step 1: Checking credentials..."
echo "--------------------------------"
if ! xcrun notarytool history --keychain-profile "$KEYCHAIN_PROFILE" > /dev/null 2>&1; then
    echo -e "${RED}Error: Keychain profile '$KEYCHAIN_PROFILE' not found${NC}"
    echo ""
    echo "Please set up your credentials first:"
    echo ""
    echo "  xcrun notarytool store-credentials \"$KEYCHAIN_PROFILE\" \\"
    echo "      --apple-id \"your@email.com\" \\"
    echo "      --team-id \"YOUR_TEAM_ID\" \\"
    echo "      --password \"your-app-specific-password\""
    echo ""
    echo "To generate an app-specific password:"
    echo "  1. Go to https://appleid.apple.com"
    echo "  2. Sign in with your Apple ID"
    echo "  3. Go to Security > App-Specific Passwords"
    echo "  4. Generate a new password for 'LanMount Notarization'"
    exit 1
fi
echo -e "${GREEN}✓ Credentials found${NC}"
echo ""

# Verify the file before submission
echo "Step 2: Verifying file..."
echo "--------------------------"
FILE_EXT="${INPUT_PATH##*.}"
if [ "$FILE_EXT" = "dmg" ]; then
    echo "File type: DMG"
    if hdiutil verify "$INPUT_PATH" 2>/dev/null; then
        echo -e "${GREEN}✓ DMG is valid${NC}"
    else
        echo -e "${YELLOW}⚠ DMG verification had warnings${NC}"
    fi
elif [ "$FILE_EXT" = "zip" ]; then
    echo "File type: ZIP"
    if unzip -t "$INPUT_PATH" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ ZIP is valid${NC}"
    else
        echo -e "${RED}✗ ZIP is invalid${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠ Unknown file type: $FILE_EXT${NC}"
    echo "Supported types: .dmg, .zip"
fi
echo ""

# Submit for notarization
echo "Step 3: Submitting for notarization..."
echo "--------------------------------------"
echo "This may take a few minutes..."
echo ""

SUBMISSION_OUTPUT=""
if [ "$WAIT_FOR_COMPLETION" = true ]; then
    SUBMISSION_OUTPUT=$(xcrun notarytool submit "$INPUT_PATH" \
        --keychain-profile "$KEYCHAIN_PROFILE" \
        --wait \
        --timeout "$TIMEOUT" \
        2>&1) || true
else
    SUBMISSION_OUTPUT=$(xcrun notarytool submit "$INPUT_PATH" \
        --keychain-profile "$KEYCHAIN_PROFILE" \
        2>&1) || true
fi

echo "$SUBMISSION_OUTPUT"
echo ""

# Extract submission ID
SUBMISSION_ID=$(echo "$SUBMISSION_OUTPUT" | grep -E "^\s*id:" | head -1 | awk '{print $2}')

if [ -z "$SUBMISSION_ID" ]; then
    echo -e "${RED}Error: Could not extract submission ID${NC}"
    echo "Please check the output above for errors."
    exit 1
fi

echo -e "${BLUE}Submission ID:${NC} $SUBMISSION_ID"
echo ""

# Save submission ID for later reference
SUBMISSION_LOG="build/notarization-submissions.log"
mkdir -p "$(dirname "$SUBMISSION_LOG")"
echo "$(date '+%Y-%m-%d %H:%M:%S') | $SUBMISSION_ID | $INPUT_PATH" >> "$SUBMISSION_LOG"
echo "Submission logged to: $SUBMISSION_LOG"
echo ""

# Check the result
if echo "$SUBMISSION_OUTPUT" | grep -q "status: Accepted"; then
    echo "=========================================="
    echo -e "${GREEN}Notarization Successful!${NC}"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "1. Staple the ticket: ./Scripts/staple-ticket.sh $INPUT_PATH"
    echo "2. Verify notarization: ./Scripts/verify-notarization.sh $INPUT_PATH"
    echo ""
    exit 0
elif echo "$SUBMISSION_OUTPUT" | grep -q "status: Invalid"; then
    echo "=========================================="
    echo -e "${RED}Notarization Failed${NC}"
    echo "=========================================="
    echo ""
    echo "To see the detailed log:"
    echo "  xcrun notarytool log $SUBMISSION_ID --keychain-profile $KEYCHAIN_PROFILE"
    echo ""
    exit 1
elif echo "$SUBMISSION_OUTPUT" | grep -q "status: In Progress"; then
    echo "=========================================="
    echo -e "${YELLOW}Notarization In Progress${NC}"
    echo "=========================================="
    echo ""
    echo "Check status with:"
    echo "  ./Scripts/verify-notarization.sh --submission-id $SUBMISSION_ID"
    echo ""
    exit 0
else
    echo "=========================================="
    echo -e "${YELLOW}Submission Complete${NC}"
    echo "=========================================="
    echo ""
    echo "Check status with:"
    echo "  ./Scripts/verify-notarization.sh --submission-id $SUBMISSION_ID"
    echo ""
    exit 0
fi
