# Homebrew Cask formula for LanMount
# 
# Installation:
#   brew tap your-username/lanmount
#   brew install --cask lanmount
#
# Or install directly:
#   brew install --cask your-username/lanmount/lanmount
#
# To update this formula after a new release:
#   1. Update the version number
#   2. Download the new DMG and calculate SHA256:
#      shasum -a 256 LanMount-X.Y.Z.dmg
#   3. Update the sha256 value
#   4. Submit PR to homebrew-cask or your tap repository
#
# For official Homebrew Cask submission:
#   https://github.com/Homebrew/homebrew-cask/blob/master/CONTRIBUTING.md

cask "lanmount" do
  # ============================================================================
  # IMPORTANT: Update these values for each release
  # ============================================================================
  version "1.0.0"
  sha256 "REPLACE_WITH_ACTUAL_SHA256_HASH_OF_DMG_FILE"
  
  # ============================================================================
  # Download URL - Update {REPO_OWNER} and {REPO_NAME} with your GitHub info
  # ============================================================================
  url "https://github.com/{REPO_OWNER}/{REPO_NAME}/releases/download/v#{version}/LanMount-#{version}.dmg"
  
  # Application name (must match the .app name in the DMG)
  name "LanMount"
  
  # Description shown in `brew info --cask lanmount`
  desc "Native macOS application for managing SMB network shares"
  
  # Homepage URL
  homepage "https://github.com/{REPO_OWNER}/{REPO_NAME}"

  # ============================================================================
  # Installation
  # ============================================================================
  
  # The app to install (copies to /Applications)
  app "LanMount.app"

  # ============================================================================
  # System Requirements
  # ============================================================================
  
  # Minimum macOS version required
  depends_on macos: ">= :monterey"

  # ============================================================================
  # Uninstallation
  # ============================================================================
  
  # Files and directories to remove on uninstall
  zap trash: [
    # Application support files
    "~/Library/Application Support/SMBMounter",
    
    # Preferences
    "~/Library/Preferences/com.lanmount.app.plist",
    
    # Caches
    "~/Library/Caches/com.lanmount.app",
    
    # Logs
    "~/Library/Logs/SMBMounter",
    
    # Saved application state
    "~/Library/Saved Application State/com.lanmount.app.savedState",
  ]

  # ============================================================================
  # Caveats (shown after installation)
  # ============================================================================
  
  caveats <<~EOS
    LanMount has been installed!

    To get started:
    1. Launch LanMount from Applications or Spotlight
    2. Grant necessary permissions when prompted
    3. Click the menu bar icon to scan for network shares

    For more information, visit:
    https://github.com/{REPO_OWNER}/{REPO_NAME}

    Note: On first launch, you may need to allow the app in:
    System Settings → Privacy & Security
  EOS

  # ============================================================================
  # Livecheck (for automatic version detection)
  # ============================================================================
  
  livecheck do
    url :url
    strategy :github_latest
  end
end

# ============================================================================
# RELEASE CHECKLIST
# ============================================================================
#
# Before submitting a new version:
#
# [ ] 1. Build and notarize the new DMG
#        ./Scripts/prepare-release.sh -v X.Y.Z
#
# [ ] 2. Calculate the SHA256 hash:
#        shasum -a 256 build/LanMount-X.Y.Z.dmg
#
# [ ] 3. Update the 'version' field above
#
# [ ] 4. Update the 'sha256' field with the new hash
#
# [ ] 5. Test the formula locally:
#        brew install --cask ./Casks/lanmount.rb
#
# [ ] 6. Verify installation:
#        - App launches correctly
#        - Menu bar icon appears
#        - Basic functionality works
#
# [ ] 7. Test uninstallation:
#        brew uninstall --cask lanmount
#        brew uninstall --cask --zap lanmount
#
# [ ] 8. Submit PR to your tap repository or homebrew-cask
#
# ============================================================================
# CREATING YOUR OWN TAP
# ============================================================================
#
# To create a Homebrew tap for LanMount:
#
# 1. Create a new GitHub repository named 'homebrew-lanmount'
#
# 2. Add this file as 'Casks/lanmount.rb' in that repository
#
# 3. Users can then install with:
#    brew tap your-username/lanmount
#    brew install --cask lanmount
#
# Or directly:
#    brew install --cask your-username/lanmount/lanmount
#
# ============================================================================
