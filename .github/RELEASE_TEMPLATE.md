# LanMount v{VERSION}

## 🎉 Release Highlights

{HIGHLIGHTS}

## 📦 Downloads

| Platform | Download |
|----------|----------|
| macOS (Universal) | [LanMount-{VERSION}.dmg](https://github.com/{REPO_OWNER}/{REPO_NAME}/releases/download/v{VERSION}/LanMount-{VERSION}.dmg) |

### System Requirements
- macOS 12.0 (Monterey) or later
- Apple Silicon (M1/M2/M3/M4) or Intel processor

## ✨ What's New

### Added
{ADDED}

### Changed
{CHANGED}

### Fixed
{FIXED}

### Removed
{REMOVED}

## 🔐 Security

This release is:
- ✅ Code signed with Apple Developer ID
- ✅ Notarized by Apple
- ✅ Hardened Runtime enabled

### Verification

You can verify the code signature and notarization:

```bash
# Verify code signature
codesign -v --deep --strict /Applications/LanMount.app

# Verify notarization
spctl -a -v /Applications/LanMount.app
```

## 📝 Installation

### DMG Installation (Recommended)

1. Download `LanMount-{VERSION}.dmg` from the link above
2. Open the downloaded DMG file
3. Drag **LanMount** to your **Applications** folder
4. Eject the DMG
5. Launch LanMount from Applications or Spotlight

### Homebrew (if available)

```bash
brew install --cask lanmount
```

### First Launch

On first launch, macOS may show a security warning. Go to **System Settings** → **Privacy & Security** and click **Open Anyway**.

## 🔄 Upgrade Notes

{UPGRADE_NOTES}

## 📋 Full Changelog

See [CHANGELOG.md](https://github.com/{REPO_OWNER}/{REPO_NAME}/blob/main/LanMount/CHANGELOG.md) for the complete list of changes.

## 🐛 Known Issues

{KNOWN_ISSUES}

## 🙏 Acknowledgments

{ACKNOWLEDGMENTS}

---

**Full Changelog**: https://github.com/{REPO_OWNER}/{REPO_NAME}/compare/v{PREVIOUS_VERSION}...v{VERSION}

---

<details>
<summary>📊 Release Information</summary>

| Property | Value |
|----------|-------|
| Version | {VERSION} |
| Release Date | {RELEASE_DATE} |
| Commit | {COMMIT_SHA} |
| Build Number | {BUILD_NUMBER} |

</details>
