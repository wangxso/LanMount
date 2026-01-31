#!/bin/bash
# prepare-release.sh
# Script to automate the release preparation process for LanMount
#
# Usage: ./prepare-release.sh [options]
#
# Options:
#   -v, --version VERSION   Version number (e.g., 1.0.0) - REQUIRED
#   -n, --notes FILE        Path to release notes file (optional)
#   -s, --skip-build        Skip building the app (use existing build)
#   -t, --skip-tests        Skip running tests
#   --skip-notarize         Skip notarization (for testing)
#   --dry-run               Show what would be done without executing
#   -h, --help              Show this help message
#
# Prerequisites:
#   1. Xcode command line tools installed
#   2. Apple Developer ID certificate in keychain
#   3. Notarization credentials configured (see notarize-app.sh)
#   4. GitHub CLI (gh) installed for creating releases
#
# Example:
#   ./prepare-release.sh -v 1.0.0
#   ./prepare-release.sh -v 1.1.0 -n release-notes.md

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
VERSION=""
RELEASE_NOTES_FILE=""
SKIP_BUILD=false
SKIP_TESTS=false
SKIP_NOTARIZE=false
DRY_RUN=false

# Configuration - Update these for your project
SCHEME="LanMount"
PROJECT_NAME="LanMount.xcodeproj"
APP_NAME="LanMount"
BUNDLE_ID="com.lanmount.app"

# Paths
BUILD_DIR="$PROJECT_ROOT/build"
RELEASE_DIR="$BUILD_DIR/Release"
APP_PATH="$RELEASE_DIR/$APP_NAME.app"
DMG_PATH=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -n|--notes)
            RELEASE_NOTES_FILE="$2"
            shift 2
            ;;
        -s|--skip-build)
            SKIP_BUILD=true
            shift
            ;;
        -t|--skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --skip-notarize)
            SKIP_NOTARIZE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            head -30 "$0" | tail -25
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Validate version
if [ -z "$VERSION" ]; then
    echo -e "${RED}Error: Version is required${NC}"
    echo ""
    echo "Usage: $0 -v VERSION"
    echo "Example: $0 -v 1.0.0"
    exit 1
fi

# Validate version format (semver)
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?$ ]]; then
    echo -e "${RED}Error: Invalid version format: $VERSION${NC}"
    echo "Expected format: X.Y.Z or X.Y.Z-suffix (e.g., 1.0.0, 1.0.0-beta1)"
    exit 1
fi

DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION.dmg"

# Print banner
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                              ║${NC}"
echo -e "${CYAN}║              LanMount Release Preparation                    ║${NC}"
echo -e "${CYAN}║                                                              ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Version:${NC}        $VERSION"
echo -e "${BLUE}Project Root:${NC}   $PROJECT_ROOT"
echo -e "${BLUE}Build Dir:${NC}      $BUILD_DIR"
echo -e "${BLUE}DMG Output:${NC}     $DMG_PATH"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}*** DRY RUN MODE - No changes will be made ***${NC}"
    echo ""
fi

# Function to run or simulate command
run_cmd() {
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY RUN]${NC} $*"
    else
        "$@"
    fi
}

# Function to print step header
print_step() {
    local step_num=$1
    local step_name=$2
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Step $step_num: $step_name${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Step 1: Pre-flight checks
print_step 1 "Pre-flight Checks"

echo "Checking required tools..."

# Check Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}✗ xcodebuild not found. Please install Xcode.${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} xcodebuild found"

# Check codesign
if ! command -v codesign &> /dev/null; then
    echo -e "${RED}✗ codesign not found.${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} codesign found"

# Check notarytool
if ! command -v xcrun &> /dev/null; then
    echo -e "${RED}✗ xcrun not found.${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} xcrun found"

# Check GitHub CLI (optional)
if command -v gh &> /dev/null; then
    echo -e "${GREEN}✓${NC} GitHub CLI (gh) found"
    GH_AVAILABLE=true
else
    echo -e "${YELLOW}⚠${NC} GitHub CLI (gh) not found - GitHub release will be skipped"
    GH_AVAILABLE=false
fi

# Check project exists
if [ ! -d "$PROJECT_ROOT/$PROJECT_NAME" ]; then
    echo -e "${RED}✗ Project not found: $PROJECT_ROOT/$PROJECT_NAME${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} Project found"

# Step 2: Run tests
if [ "$SKIP_TESTS" = false ]; then
    print_step 2 "Running Tests"
    
    cd "$PROJECT_ROOT"
    run_cmd xcodebuild test \
        -project "$PROJECT_NAME" \
        -scheme "$SCHEME" \
        -destination 'platform=macOS' \
        -quiet \
        || { echo -e "${RED}✗ Tests failed${NC}"; exit 1; }
    
    echo -e "${GREEN}✓ All tests passed${NC}"
else
    print_step 2 "Running Tests (SKIPPED)"
    echo -e "${YELLOW}⚠ Tests skipped by user request${NC}"
fi

# Step 3: Update version in project
print_step 3 "Updating Version"

echo "Setting version to $VERSION..."

# Update Info.plist version (if using Info.plist)
# For SwiftUI apps, version is typically in project settings
if [ "$DRY_RUN" = false ]; then
    cd "$PROJECT_ROOT"
    
    # Update marketing version
    xcrun agvtool new-marketing-version "$VERSION" 2>/dev/null || true
    
    # Update build number (use timestamp)
    BUILD_NUMBER=$(date +%Y%m%d%H%M)
    xcrun agvtool new-version -all "$BUILD_NUMBER" 2>/dev/null || true
    
    echo -e "${GREEN}✓${NC} Version updated to $VERSION (build $BUILD_NUMBER)"
else
    echo -e "${YELLOW}[DRY RUN]${NC} Would update version to $VERSION"
fi

# Step 4: Build the app
if [ "$SKIP_BUILD" = false ]; then
    print_step 4 "Building Release"
    
    # Clean build directory
    echo "Cleaning build directory..."
    run_cmd rm -rf "$BUILD_DIR"
    run_cmd mkdir -p "$BUILD_DIR"
    
    # Build
    echo "Building $SCHEME in Release configuration..."
    cd "$PROJECT_ROOT"
    
    if [ "$DRY_RUN" = false ]; then
        xcodebuild \
            -project "$PROJECT_NAME" \
            -scheme "$SCHEME" \
            -configuration Release \
            -derivedDataPath "$BUILD_DIR/DerivedData" \
            CONFIGURATION_BUILD_DIR="$RELEASE_DIR" \
            CODE_SIGN_IDENTITY="Developer ID Application" \
            OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime" \
            clean build \
            | xcpretty || xcodebuild \
                -project "$PROJECT_NAME" \
                -scheme "$SCHEME" \
                -configuration Release \
                -derivedDataPath "$BUILD_DIR/DerivedData" \
                CONFIGURATION_BUILD_DIR="$RELEASE_DIR" \
                CODE_SIGN_IDENTITY="Developer ID Application" \
                OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime" \
                clean build
    fi
    
    # Verify build output
    if [ "$DRY_RUN" = false ] && [ ! -d "$APP_PATH" ]; then
        echo -e "${RED}✗ Build failed - app not found at $APP_PATH${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Build completed successfully${NC}"
else
    print_step 4 "Building Release (SKIPPED)"
    echo -e "${YELLOW}⚠ Build skipped by user request${NC}"
    
    if [ ! -d "$APP_PATH" ]; then
        echo -e "${RED}✗ App not found at $APP_PATH${NC}"
        echo "Please build the app first or remove --skip-build flag"
        exit 1
    fi
fi

# Step 5: Verify code signature
print_step 5 "Verifying Code Signature"

if [ "$DRY_RUN" = false ]; then
    if "$SCRIPT_DIR/verify-codesign.sh" "$APP_PATH"; then
        echo -e "${GREEN}✓ Code signature verified${NC}"
    else
        echo -e "${RED}✗ Code signature verification failed${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}[DRY RUN]${NC} Would verify code signature"
fi

# Step 6: Create DMG
print_step 6 "Creating DMG"

if [ "$DRY_RUN" = false ]; then
    "$SCRIPT_DIR/build-dmg.sh" \
        --app-path "$APP_PATH" \
        --output "$DMG_PATH" \
        --volume-name "$APP_NAME"
    
    echo -e "${GREEN}✓ DMG created: $DMG_PATH${NC}"
else
    echo -e "${YELLOW}[DRY RUN]${NC} Would create DMG at $DMG_PATH"
fi

# Step 7: Notarize
if [ "$SKIP_NOTARIZE" = false ]; then
    print_step 7 "Notarizing"
    
    if [ "$DRY_RUN" = false ]; then
        "$SCRIPT_DIR/notarize-app.sh" "$DMG_PATH"
        
        # Staple the ticket
        echo "Stapling notarization ticket..."
        "$SCRIPT_DIR/staple-ticket.sh" "$DMG_PATH"
        
        echo -e "${GREEN}✓ Notarization complete${NC}"
    else
        echo -e "${YELLOW}[DRY RUN]${NC} Would notarize $DMG_PATH"
    fi
else
    print_step 7 "Notarizing (SKIPPED)"
    echo -e "${YELLOW}⚠ Notarization skipped by user request${NC}"
fi

# Step 8: Verify final DMG
print_step 8 "Final Verification"

if [ "$DRY_RUN" = false ]; then
    echo "Verifying DMG..."
    if hdiutil verify "$DMG_PATH" 2>/dev/null; then
        echo -e "${GREEN}✓ DMG verification passed${NC}"
    else
        echo -e "${YELLOW}⚠ DMG verification had warnings${NC}"
    fi
    
    # Verify notarization (if not skipped)
    if [ "$SKIP_NOTARIZE" = false ]; then
        echo "Verifying notarization..."
        "$SCRIPT_DIR/verify-notarization.sh" "$DMG_PATH" || true
    fi
else
    echo -e "${YELLOW}[DRY RUN]${NC} Would verify final DMG"
fi

# Step 9: Create GitHub Release (if gh is available)
print_step 9 "Creating GitHub Release"

if [ "$GH_AVAILABLE" = true ]; then
    echo "Preparing GitHub release..."
    
    # Generate release notes
    RELEASE_NOTES=""
    if [ -n "$RELEASE_NOTES_FILE" ] && [ -f "$RELEASE_NOTES_FILE" ]; then
        RELEASE_NOTES=$(cat "$RELEASE_NOTES_FILE")
    else
        # Generate from template
        TEMPLATE_FILE="$PROJECT_ROOT/.github/RELEASE_TEMPLATE.md"
        if [ -f "$TEMPLATE_FILE" ]; then
            RELEASE_NOTES=$(cat "$TEMPLATE_FILE")
            # Replace placeholders
            RELEASE_NOTES="${RELEASE_NOTES//\{VERSION\}/$VERSION}"
            RELEASE_NOTES="${RELEASE_NOTES//\{RELEASE_DATE\}/$(date +%Y-%m-%d)}"
            RELEASE_NOTES="${RELEASE_NOTES//\{COMMIT_SHA\}/$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')}"
            RELEASE_NOTES="${RELEASE_NOTES//\{BUILD_NUMBER\}/$BUILD_NUMBER}"
        else
            RELEASE_NOTES="## LanMount v$VERSION

Release date: $(date +%Y-%m-%d)

### Downloads
- [LanMount-$VERSION.dmg](./LanMount-$VERSION.dmg)

### Changes
See CHANGELOG.md for details.
"
        fi
    fi
    
    if [ "$DRY_RUN" = false ]; then
        # Check if we're in a git repo
        if git rev-parse --git-dir > /dev/null 2>&1; then
            # Create tag
            echo "Creating git tag v$VERSION..."
            git tag -a "v$VERSION" -m "Release v$VERSION" 2>/dev/null || echo "Tag already exists"
            
            # Push tag
            echo "Pushing tag..."
            git push origin "v$VERSION" 2>/dev/null || echo "Could not push tag"
            
            # Create release
            echo "Creating GitHub release..."
            echo "$RELEASE_NOTES" | gh release create "v$VERSION" \
                "$DMG_PATH" \
                --title "LanMount v$VERSION" \
                --notes-file - \
                || echo -e "${YELLOW}⚠ Could not create GitHub release${NC}"
            
            echo -e "${GREEN}✓ GitHub release created${NC}"
        else
            echo -e "${YELLOW}⚠ Not a git repository - skipping GitHub release${NC}"
        fi
    else
        echo -e "${YELLOW}[DRY RUN]${NC} Would create GitHub release v$VERSION"
    fi
else
    echo -e "${YELLOW}⚠ GitHub CLI not available - skipping GitHub release${NC}"
    echo ""
    echo "To create a GitHub release manually:"
    echo "1. Go to https://github.com/YOUR_REPO/releases/new"
    echo "2. Create tag: v$VERSION"
    echo "3. Upload: $DMG_PATH"
    echo "4. Copy release notes from .github/RELEASE_TEMPLATE.md"
fi

# Step 10: Summary
print_step 10 "Release Summary"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                  Release Preparation Complete                ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Version:${NC}     $VERSION"
echo -e "${BLUE}DMG:${NC}         $DMG_PATH"

if [ "$DRY_RUN" = false ]; then
    DMG_SIZE=$(du -h "$DMG_PATH" 2>/dev/null | cut -f1 || echo "N/A")
    echo -e "${BLUE}Size:${NC}        $DMG_SIZE"
fi

echo ""
echo "Artifacts:"
echo "  • $DMG_PATH"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}This was a dry run. No changes were made.${NC}"
    echo "Run without --dry-run to perform the actual release."
else
    echo "Next steps:"
    echo "  1. Test the DMG by installing on a clean system"
    echo "  2. Verify the GitHub release page"
    echo "  3. Update Homebrew Cask formula (if applicable)"
    echo "  4. Announce the release"
fi

echo ""
echo -e "${GREEN}Done!${NC}"
