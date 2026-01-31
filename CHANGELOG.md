# Changelog

All notable changes to LanMount will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-01-15

### 🎉 Initial Release

This is the first public release of LanMount, a native macOS application for managing SMB network shares.

### Added

#### Core Features
- **SMB Mount Management**
  - Mount and unmount SMB shares using macOS native NetFS framework
  - Support for authenticated and guest connections
  - Custom mount point selection
  - Progress indicators during mount operations
  - Detailed error messages for failed operations

- **Network Discovery**
  - Automatic SMB server discovery using Bonjour/mDNS
  - Real-time service discovery with live updates
  - 30-second scan timeout for efficient discovery
  - Display of server name, IP address, and available shares

- **Credential Management**
  - Secure credential storage using macOS Keychain
  - Per-share credential isolation
  - Support for username/password authentication
  - Optional domain authentication for Windows servers
  - Credential update and deletion support

- **Auto-Mount**
  - Automatic mounting of configured shares at login
  - Launch at login support via SMAppService
  - Resilient auto-mount (failures don't block other mounts)
  - Background mounting without blocking UI

- **Volume Monitoring**
  - Real-time monitoring of mounted volumes
  - Automatic detection of disconnections
  - Optional auto-reconnect on network availability
  - 30-second health check interval

- **File Synchronization**
  - Real-time file change detection using FSEvents
  - Bidirectional sync support
  - Conflict detection and resolution
  - Exclusion of system files (.DS_Store, .Spotlight-V100, .Trashes)
  - Background sync without blocking file access

#### User Interface
- **Menu Bar Application**
  - Persistent menu bar icon with status indication
  - Quick access to all mounted shares
  - One-click mount/unmount operations
  - Status indicators (connected, connecting, error)

- **Configuration Windows**
  - SwiftUI-based mount configuration dialog
  - Network scanner view with real-time results
  - Preferences window for app settings
  - Form validation with error display

- **Finder Integration**
  - Mounted shares appear in Finder sidebar
  - Custom volume icons for SMB shares
  - Native file operation support
  - Right-click eject support

#### System Integration
- **Notifications**
  - Mount success/failure notifications
  - Disconnection alerts
  - Sync completion notifications
  - Conflict resolution prompts

- **Logging**
  - Comprehensive logging system
  - Log levels: Debug, Info, Warning, Error
  - Automatic log rotation (10MB max, 5 files)
  - Log file location: ~/Library/Logs/SMBMounter/

- **Error Handling**
  - User-friendly error messages
  - Automatic retry with exponential backoff
  - Detailed error logging for troubleshooting

#### Internationalization
- English language support
- Simplified Chinese (简体中文) language support
- Localized date and number formats

#### Accessibility
- VoiceOver support for all UI elements
- Keyboard navigation support
- WCAG-compliant color contrast

#### Performance
- Memory usage under 50MB during normal operation
- CPU usage under 1% when idle
- Startup time under 5 seconds
- Support for 10+ simultaneous mounts

### System Requirements
- macOS 12.0 (Monterey) or later
- Apple Silicon (M1/M2/M3/M4) or Intel processor
- Network access for SMB connections

### Security
- Code signed with Apple Developer ID
- Notarized by Apple
- Hardened Runtime enabled
- Keychain-based credential storage
- No sensitive data in logs

### Known Limitations
- SMB protocol only (NFS, AFP not supported in v1.0)
- Sync feature requires manual conflict resolution
- Network scan limited to local subnet
- No cloud storage integration yet
- No AppleScript/Shortcuts support yet

### Technical Details
- Built with Swift 5.9+
- SwiftUI + AppKit hybrid UI
- Native macOS frameworks: NetFS, Network, Security, ServiceManagement
- Async/await for all network operations
- Protocol-oriented architecture for testability

---

## Future Roadmap

### Planned for v1.1
- [ ] Improved sync performance
- [ ] Bandwidth limiting for sync
- [ ] More detailed sync progress

### Planned for v1.2
- [ ] NFS protocol support
- [ ] AFP protocol support
- [ ] Selective sync (folder-level)

### Planned for v2.0
- [ ] Cloud storage integration (iCloud, Dropbox)
- [ ] AppleScript support
- [ ] Shortcuts integration
- [ ] Team/Enterprise features

---

[1.0.0]: https://github.com/yourusername/LanMount/releases/tag/v1.0.0
