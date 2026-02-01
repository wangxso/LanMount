# Quick Start Guide | 快速开始指南

[English](#english) | [中文](#中文)

---

## English

### Prerequisites

- macOS 12.0 (Monterey) or later
- Xcode 15.0 or later
- Apple Developer account (for code signing and notarization)

### Quick Build

#### 1. Install Dependencies

```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Fastlane
brew install fastlane
```

#### 2. Configure Environment

```bash
cd LanMount

# Copy environment template
cp .env.example .env

# Edit .env file with your credentials
nano .env
```

Required environment variables:
- `APPLE_ID` - Your Apple ID email
- `TEAM_ID` - Your 10-character Team ID
- `APP_SPECIFIC_PASSWORD` - App-specific password from appleid.apple.com

#### 3. Build and Test

```bash
# Test build (without notarization)
fastlane test_build version:1.0.0

# The DMG will be created at: build/LanMount-1.0.0.dmg
```

#### 4. Full Release (with Notarization)

```bash
# Complete release with notarization
fastlane release version:1.0.0
```

### Quick Commands

| Command | Description |
|---------|-------------|
| `fastlane test_build version:X.X.X` | Build without notarization |
| `fastlane release version:X.X.X` | Full release with notarization |
| `fastlane clean` | Clean build files |
| `fastlane validate` | Validate configuration |

### Troubleshooting

**Build fails?**
- Check Xcode version: `xcodebuild -version`
- Clean build: `fastlane clean`

**Notarization fails?**
- Verify Team ID is 10 characters (not your name)
- Check App-specific password is valid

**Certificate issues?**
- Verify certificate in Keychain Access
- Run: `security find-identity -v -p codesigning`

### Next Steps

- [Fastlane Guide](FASTLANE_GUIDE.md) - Detailed Fastlane usage
- [GitHub Actions Setup](../.github/GITHUB_ACTIONS_SETUP.md) - Automated releases
- [Code Signing Guide](CODE_SIGNING.md) - Certificate setup

---

## 中文

### 前提条件

- macOS 12.0 (Monterey) 或更高版本
- Xcode 15.0 或更高版本
- Apple Developer 账号（用于代码签名和公证）

### 快速构建

#### 1. 安装依赖

```bash
# 安装 Homebrew（如果未安装）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 安装 Fastlane
brew install fastlane
```

#### 2. 配置环境

```bash
cd LanMount

# 复制环境变量模板
cp .env.example .env

# 编辑 .env 文件，填入你的凭证
nano .env
```

必需的环境变量：
- `APPLE_ID` - 你的 Apple ID 邮箱
- `TEAM_ID` - 你的 10 位 Team ID
- `APP_SPECIFIC_PASSWORD` - 从 appleid.apple.com 生成的 App 专用密码

#### 3. 构建和测试

```bash
# 测试构建（不公证）
fastlane test_build version:1.0.0

# DMG 将创建在：build/LanMount-1.0.0.dmg
```

#### 4. 完整发布（包含公证）

```bash
# 完整发布流程，包括公证
fastlane release version:1.0.0
```

### 常用命令

| 命令 | 说明 |
|------|------|
| `fastlane test_build version:X.X.X` | 不公证的测试构建 |
| `fastlane release version:X.X.X` | 包含公证的完整发布 |
| `fastlane clean` | 清理构建文件 |
| `fastlane validate` | 验证配置 |

### 故障排除

**构建失败？**
- 检查 Xcode 版本：`xcodebuild -version`
- 清理构建：`fastlane clean`

**公证失败？**
- 确认 Team ID 是 10 位字符（不是你的名字）
- 检查 App 专用密码是否有效

**证书问题？**
- 在钥匙串访问中验证证书
- 运行：`security find-identity -v -p codesigning`

### 下一步

- [Fastlane 指南](FASTLANE_GUIDE.md) - 详细的 Fastlane 使用说明
- [GitHub Actions 配置](../.github/GITHUB_ACTIONS_SETUP.md) - 自动化发布
- [代码签名指南](CODE_SIGNING.md) - 证书配置

---

**提示 | Tip:** 首次构建建议使用 `test_build` 跳过公证，快速验证配置是否正确。
