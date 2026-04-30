# LanMount

<p align="center">
  <img src="imgs/icon-128.png" alt="LanMount Icon" width="128" height="128">
</p>

<p align="center">
  <strong>A native macOS application for seamless SMB network share management</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#configuration">Configuration</a> •
  <a href="#keyboard-shortcuts">Shortcuts</a> •
  <a href="#troubleshooting">Troubleshooting</a>
</p>

---

## Overview

LanMount is a powerful yet simple macOS menu bar application that makes connecting to SMB (Server Message Block) network shares as easy as using a local drive. Built with native macOS technologies, it provides automatic network discovery, secure credential management, and seamless Finder integration.

Whether you're connecting to a NAS device, a Windows file server, or another Mac's shared folders, LanMount streamlines the entire process with features like auto-mount at login, real-time status monitoring, and optional file synchronization.

## Features

### 🔍 Network Discovery
- **Automatic SMB Discovery**: Uses Bonjour/mDNS to automatically find SMB servers on your local network
- **Real-time Updates**: Discovered servers appear instantly as they're found
- **One-Click Connection**: Select a discovered server and connect with a single click

### 📁 SMB Mount Management
- **Easy Mounting**: Mount SMB shares with a simple, intuitive interface
- **Quick Unmount**: Safely unmount shares from the menu bar or Finder
- **Multiple Shares**: Connect to multiple SMB shares simultaneously (up to 10+)
- **Custom Mount Points**: Choose where shares appear in your filesystem

### 🔐 Secure Credential Management
- **Keychain Integration**: Credentials are securely stored in macOS Keychain
- **Per-Share Credentials**: Different credentials for different servers
- **Remember Me**: Option to save credentials for quick reconnection

### 🚀 Auto-Mount
- **Login Items**: Automatically start LanMount when you log in
- **Auto-Connect**: Automatically mount your favorite shares at startup
- **Smart Reconnection**: Automatically reconnect when network becomes available

### 🔄 File Synchronization
- **Real-time Sync**: Keep local copies synchronized with remote shares
- **Bidirectional Sync**: Changes sync both ways
- **Conflict Resolution**: Smart handling of simultaneous edits
- **Selective Sync**: Choose which folders to synchronize

### 📊 Status Monitoring
- **Menu Bar Status**: See connection status at a glance
- **Real-time Notifications**: Get notified of connection changes
- **Volume Monitoring**: Automatic detection of disconnections
- **Connection Health**: Monitor the health of your connections

### 🖥️ Finder Integration
- **Sidebar Display**: Mounted shares appear in Finder's sidebar
- **Native Experience**: Works just like local drives
- **Custom Icons**: Easy identification of network shares
- **Right-Click Eject**: Unmount directly from Finder

## Screenshots

### Overview - 概览
<p align="center">
  <img src="docs/images/mainmenu.png" alt="Overview" width="100%">
</p>

一目了然的连接状态总览，显示所有已挂载磁盘和快速操作面板。

### Disk Configuration - 磁盘配置
<p align="center">
  <img src="docs/images/diskconfig.png" alt="Disk Configuration" width="100%">
</p>

管理所有 SMB 连接配置，支持自动挂载和自定义设置。

### Disk Info - 磁盘信息
<p align="center">
  <img src="docs/images/diskinfo.png" alt="Disk Info" width="100%">
</p>

实时监控存储使用情况，包括容量、使用率和 I/O 监控图表。

### System Configuration - 系统配置
<p align="center">
  <img src="docs/images/config.png" alt="System Configuration" width="100%">
</p>

自定义应用设置，包括语言、启动选项、通知偏好和数据管理。

### Menu Bar - 菜单栏
<p align="center">
  <img src="docs/images/topbar.png" alt="Menu Bar" width="60%">
</p>

菜单栏图标实时显示挂载状态，点击可快速访问所有功能。

## System Requirements

| Requirement | Specification |
|-------------|---------------|
| **Operating System** | macOS 12.0 (Monterey) or later |
| **Processor** | Apple Silicon (M1/M2/M3/M4) or Intel |
| **Memory** | 50 MB available RAM |
| **Disk Space** | 20 MB for installation |
| **Network** | Local network access for SMB connections |

## Installation

### Download DMG (Recommended)

1. Download the latest `LanMount.dmg` from the [Releases](https://github.com/yourusername/LanMount/releases) page
2. Open the downloaded DMG file
3. Drag **LanMount** to your **Applications** folder
4. Eject the DMG
5. Launch LanMount from Applications or Spotlight

### Homebrew (Coming Soon)

```bash
brew install --cask lanmount
```

### First Launch

On first launch, macOS may show a security warning because the app is downloaded from the internet:

1. Go to **System Settings** → **Privacy & Security**
2. Scroll down to find the message about LanMount
3. Click **Open Anyway**
4. Enter your password if prompted

> **Note**: LanMount is notarized by Apple, ensuring it's free from known malware.

## Quick Start

### 1. Launch the App

After installation, launch LanMount. You'll see a new icon in your menu bar:

<p align="center">
  <img src="docs/images/topbar.png" alt="Menu Bar" width="60%">
</p>

### 2. Scan for Network Shares

1. Click the LanMount menu bar icon
2. Select **Scan Network...**
3. Wait for the scan to complete (up to 30 seconds)
4. Available SMB servers will appear in the list

### 3. Connect to a Share

**From Network Scan:**
1. Click on a discovered server
2. Select the share you want to mount
3. Enter credentials if required
4. Click **Mount**

**Manual Connection:**
1. Click the menu bar icon
2. Select **Add New Mount...**
3. Enter the server address (e.g., `192.168.1.100` or `server.local`)
4. Enter the share name
5. Provide credentials
6. Click **Mount**

### 4. Access Your Files

Once mounted, your share will appear:
- In Finder's sidebar under **Locations**
- In `/Volumes/ShareName`
- In the LanMount menu with a green status indicator

## Configuration

### Mount Configuration

When adding a new mount, you can configure:

| Option | Description |
|--------|-------------|
| **Server Address** | IP address or hostname of the SMB server |
| **Share Name** | Name of the shared folder |
| **Username** | Your username for authentication |
| **Password** | Your password (stored securely in Keychain) |
| **Mount Point** | Where to mount (default: `/Volumes/ShareName`) |
| **Auto-Mount** | Automatically mount at login |
| **Remember Credentials** | Save credentials to Keychain |
| **Enable Sync** | Enable file synchronization |

### Application Preferences

Access preferences from the menu bar: **LanMount** → **Preferences...**

#### General
- **Launch at Login**: Start LanMount automatically when you log in
- **Auto-Reconnect**: Automatically reconnect when a share becomes available
- **Show Notifications**: Display system notifications for events

#### Sync Settings
- **Sync Interval**: How often to check for changes
- **Exclude Files**: Patterns for files to ignore during sync

#### Advanced
- **Log Level**: Set logging verbosity (Debug, Info, Warning, Error)
- **View Logs**: Open the log file location

### Configuration File Location

LanMount stores its configuration in:
```
~/Library/Application Support/SMBMounter/config.json
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘ + N` | Add new mount |
| `⌘ + R` | Refresh/Scan network |
| `⌘ + ,` | Open Preferences |
| `⌘ + Q` | Quit LanMount |

## Menu Bar Icons

The menu bar icon indicates the current status:

| Icon | Status |
|------|--------|
| `externaldrive.connected.to.line.below` | All shares connected |
| `externaldrive.badge.timemachine` | Connecting to a share |
| `externaldrive.badge.xmark` | One or more shares disconnected |

## SMB URL Format

LanMount supports standard SMB URL formats:

```
smb://server/share
smb://username@server/share
smb://username:password@server/share
smb://DOMAIN;username@server/share
```

## Log Files

Logs are stored in:
```
~/Library/Logs/SMBMounter/
```

Log files are automatically rotated:
- Maximum file size: 10 MB
- Maximum files kept: 5
- Older logs are compressed

## Privacy & Security

### Data Storage
- **Credentials**: Stored in macOS Keychain with highest security level
- **Configuration**: Stored locally with user-only permissions (0600)
- **Logs**: No passwords or sensitive data are logged

### Permissions Required
- **Network Access**: To connect to SMB servers
- **File System Access**: To mount shares and sync files
- **Keychain Access**: To securely store credentials
- **Notifications**: To alert you of connection changes (optional)

### Sandboxing
LanMount follows macOS security best practices and requests only the minimum permissions necessary for operation.

## Troubleshooting

For common issues and solutions, see the [Troubleshooting Guide](docs/TROUBLESHOOTING.md).

Quick fixes for common problems:

1. **Can't find server**: Ensure you're on the same network
2. **Authentication failed**: Double-check username and password
3. **Mount fails**: Check if the share name is correct
4. **Disconnections**: Enable auto-reconnect in preferences

## Contributing

We welcome contributions! Feel free to open issues or submit pull requests on GitHub.

## License

LanMount is released under the MIT License.

## Acknowledgments

- Built with Swift and SwiftUI
- Uses macOS native frameworks: NetFS, Network, Security, ServiceManagement
- Icon design inspired by macOS design guidelines

## Support

- **Issues**: [GitHub Issues](https://github.com/wangxso/LanMount/issues)
- **Discussions**: [GitHub Discussions](https://github.com/wangxso/LanMount/discussions)
- **Email**: wangxso@hotmail.com

---

<p align="center">
  Made with ❤️ for the macOS community
</p>


## 🚀 发布流程

LanMount 支持两种发布方式：

### 自动发布（GitHub Actions）

推送 tag 即可自动构建、签名、公证并发布：

```bash
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions 会自动：
- ✅ 构建应用
- ✅ 代码签名
- ✅ 创建 DMG
- ✅ Apple 公证
- ✅ 创建 GitHub Release
- ✅ 上传 DMG

详见 [GitHub Actions 配置指南](.github/GITHUB_ACTIONS_SETUP.md)

### 本地发布（Fastlane）

使用 Fastlane 在本地构建和发布：

```bash
cd LanMount

# 测试构建（不公证）
fastlane test_build version:1.0.0

# 完整发布（包括公证）
fastlane release version:1.0.0
```

详见 [Fastlane 指南](docs/FASTLANE_GUIDE.md)

## 📚 开发文档

- [快速开始](docs/QUICK_START.md) - 快速构建和发布指南
- [Fastlane 指南](docs/FASTLANE_GUIDE.md) - 使用 Fastlane 自动化发布
- [GitHub Actions 配置](.github/GITHUB_ACTIONS_SETUP.md) - 配置自动发布
- [代码签名指南](docs/CODE_SIGNING.md) - 代码签名和公证
- [发布指南](docs/RELEASE_GUIDE.md) - 详细发布流程
- [故障排除](docs/TROUBLESHOOTING.md) - 常见问题解决
