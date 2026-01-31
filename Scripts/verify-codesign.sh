#!/bin/bash
# verify-codesign.sh
# Script to verify code signing configuration for LanMount
#
# Usage: ./verify-codesign.sh [path-to-app]
#
# This script verifies:
# 1. Code signature validity
# 2. Hardened runtime is enabled
# 3. Entitlements are correctly applied
# 4. Gatekeeper acceptance (if notarized)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default app path
APP_PATH="${1:-build/Release/LanMount.app}"

echo "=========================================="
echo "LanMount Code Signing Verification"
echo "=========================================="
echo ""

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo -e "${YELLOW}Warning: App not found at $APP_PATH${NC}"
    echo "Please build the app first or provide the correct path."
    echo ""
    echo "To build the app:"
    echo "  xcodebuild -project LanMount.xcodeproj -scheme LanMount -configuration Release build"
    echo ""
    echo "Checking entitlements file instead..."
    echo ""
    
    ENTITLEMENTS_PATH="LanMount/LanMount.entitlements"
    if [ -f "$ENTITLEMENTS_PATH" ]; then
        echo -e "${GREEN}✓ Entitlements file found${NC}"
        echo ""
        echo "Entitlements content:"
        echo "--------------------"
        plutil -p "$ENTITLEMENTS_PATH"
        echo ""
        
        # Verify entitlements file syntax
        if plutil -lint "$ENTITLEMENTS_PATH" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Entitlements file syntax is valid${NC}"
        else
            echo -e "${RED}✗ Entitlements file syntax is invalid${NC}"
            exit 1
        fi
        
        # Check for required entitlements
        echo ""
        echo "Checking required entitlements:"
        echo "-------------------------------"
        
        check_entitlement() {
            local key="$1"
            local description="$2"
            if grep -q "$key" "$ENTITLEMENTS_PATH"; then
                echo -e "${GREEN}✓ $description${NC}"
            else
                echo -e "${RED}✗ $description (missing)${NC}"
            fi
        }
        
        check_entitlement "com.apple.security.network.client" "Network client access"
        check_entitlement "com.apple.security.files.user-selected.read-write" "User-selected file access"
        check_entitlement "keychain-access-groups" "Keychain access groups"
        check_entitlement "com.apple.security.automation.apple-events" "Automation (Apple Events)"
        check_entitlement "com.apple.security.app-sandbox" "App Sandbox"
        
        echo ""
        echo "Checking hardened runtime settings (disabled for security):"
        echo "-----------------------------------------------------------"
        
        check_disabled() {
            local key="$1"
            local description="$2"
            if grep -A1 "$key" "$ENTITLEMENTS_PATH" | grep -q "false"; then
                echo -e "${GREEN}✓ $description (disabled)${NC}"
            elif grep -q "$key" "$ENTITLEMENTS_PATH"; then
                echo -e "${YELLOW}⚠ $description (check value)${NC}"
            else
                echo -e "${GREEN}✓ $description (not present = disabled)${NC}"
            fi
        }
        
        check_disabled "com.apple.security.cs.allow-unsigned-executable-memory" "Unsigned executable memory"
        check_disabled "com.apple.security.cs.allow-dyld-environment-variables" "DYLD environment variables"
        check_disabled "com.apple.security.cs.disable-library-validation" "Library validation bypass"
        
    else
        echo -e "${RED}✗ Entitlements file not found at $ENTITLEMENTS_PATH${NC}"
        exit 1
    fi
    
    exit 0
fi

echo "Verifying: $APP_PATH"
echo ""

# 1. Basic code signature verification
echo "1. Code Signature Verification"
echo "------------------------------"
if codesign -v "$APP_PATH" 2>/dev/null; then
    echo -e "${GREEN}✓ Code signature is valid${NC}"
else
    echo -e "${RED}✗ Code signature is invalid or missing${NC}"
fi
echo ""

# 2. Detailed signature information
echo "2. Signature Details"
echo "--------------------"
codesign -dv --verbose=2 "$APP_PATH" 2>&1 | head -20
echo ""

# 3. Check for hardened runtime
echo "3. Hardened Runtime Check"
echo "-------------------------"
if codesign -dv --verbose=4 "$APP_PATH" 2>&1 | grep -q "flags=0x10000(runtime)"; then
    echo -e "${GREEN}✓ Hardened runtime is enabled${NC}"
else
    echo -e "${YELLOW}⚠ Hardened runtime may not be enabled${NC}"
fi
echo ""

# 4. Display entitlements
echo "4. Applied Entitlements"
echo "-----------------------"
codesign -d --entitlements :- "$APP_PATH" 2>/dev/null || echo "No entitlements found"
echo ""

# 5. Gatekeeper verification
echo "5. Gatekeeper Verification"
echo "--------------------------"
if spctl -a -t exec -vv "$APP_PATH" 2>&1 | grep -q "accepted"; then
    echo -e "${GREEN}✓ App is accepted by Gatekeeper${NC}"
    spctl -a -t exec -vv "$APP_PATH" 2>&1 | grep "source="
else
    echo -e "${YELLOW}⚠ App may not be accepted by Gatekeeper (not notarized)${NC}"
    echo "This is expected for development builds."
fi
echo ""

# 6. Check all nested code
echo "6. Nested Code Verification"
echo "---------------------------"
if codesign --verify --deep --strict "$APP_PATH" 2>/dev/null; then
    echo -e "${GREEN}✓ All nested code is properly signed${NC}"
else
    echo -e "${RED}✗ Some nested code may not be properly signed${NC}"
fi
echo ""

echo "=========================================="
echo "Verification Complete"
echo "=========================================="
