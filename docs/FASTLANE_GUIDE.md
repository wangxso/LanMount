# Fastlane Guide | Fastlane 使用指南

[English](#english) | [中文](#中文)

---

## English

### Overview

Fastlane automates the entire release process for LanMount, including building, code signing, DMG creation, and notarization.

### Installation

#### Prerequisites

- macOS 12.0 or later
- Xcode 15.0 or later
- Ruby 2.6 or later (included with macOS)
- Homebrew (recommended)

#### Install Fastlane

```bash
# Using Homebrew (recommended)
brew install fastlane

# Or using RubyGems
sudo gem install fastlane

# Verify installation
fastlane --version
```

#### Install Dependencies

```bash
cd LanMount

# Install Ruby gems
bundle install
```

### Configuration

#### 1. Environment Variables

Create `.env` file from template:

```bash
cp .env.example .env
nano .env
```

Required variables:

```bash
# Apple Developer Account
APPLE_ID=your@email.com
TEAM_ID=ABCDE12345
APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx

# Code Signing
CODE_SIGN_IDENTITY=Developer ID Application

# Build Configuration
CONFIGURATION=Release
SCHEME=LanMount
```

**Important:**
- `TEAM_ID` must be your 10-character Team ID from developer.apple.com
- `APP_SPECIFIC_PASSWORD` is generated at appleid.apple.com
- Never commit `.env` file to Git (already in .gitignore)

#### 2. Verify Configuration

```bash
fastlane validate
```

This checks:
- ✅ Environment variables are set
- ✅ Code signing certificate exists
- ✅ Project files are present

### Available Lanes

#### 1. release - Complete Release Process

Full release with building, signing, DMG creation, and notarization.

```bash
# Basic usage
fastlane release version:1.0.0

# Skip tests
fastlane release version:1.0.0 skip_tests:true

# Skip notarization (for testing)
fastlane release version:1.0.0 skip_notarize:true

# Skip version bump
fastlane release version:1.0.0 skip_version_bump:true
```

**Process:**
1. Run tests (optional)
2. Update version and build number
3. Build application
4. Create DMG
5. Submit for notarization
6. Staple notarization ticket
7. Verify notarization

**Time:** 15-45 minutes (depending on Apple's notarization queue)

#### 2. test_build - Quick Test Build

Build without notarization for quick testing.

```bash
fastlane test_build version:1.0.0-test
```

**Process:**
1. Build application
2. Create DMG
3. Skip notarization

**Time:** 2-5 minutes

#### 3. build_app_release - Build Only

Build the application without creating DMG.

```bash
fastlane build_app_release
```

**Output:** `build/Release/LanMount.app`

#### 4. create_dmg - Create DMG Only

Create DMG from existing app bundle.

```bash
fastlane create_dmg version:1.0.0
```

**Input:** `build/Release/LanMount.app`  
**Output:** `build/LanMount-1.0.0.dmg`

#### 5. notarize_dmg - Notarize Existing DMG

Notarize an already created DMG.

```bash
fastlane notarize_only dmg:build/LanMount-1.0.0.dmg
```

**Process:**
1. Submit to Apple notary service
2. Wait for approval (10-30 minutes)
3. Staple ticket to DMG
4. Verify notarization

#### 6. clean - Clean Build Files

Remove all build artifacts and caches.

```bash
fastlane clean
```

**Removes:**
- `build/` directory
- Xcode DerivedData
- Temporary DMG files

#### 7. validate - Validate Configuration

Check if everything is configured correctly.

```bash
fastlane validate
```

### Typical Workflows

#### First Time Setup

```bash
# 1. Install Fastlane
brew install fastlane

# 2. Install dependencies
cd LanMount
bundle install

# 3. Configure environment
cp .env.example .env
nano .env

# 4. Validate
fastlane validate

# 5. Test build
fastlane test_build version:1.0.0-test
```

#### Development Build

Quick build for testing:

```bash
fastlane test_build version:1.0.0-dev
```

#### Beta Release

Release with pre-release flag:

```bash
fastlane release version:1.0.0-beta
```

#### Production Release

Full release with notarization:

```bash
fastlane release version:1.0.0
```

### Troubleshooting

#### Problem: "Could not find package"

**Error:**
```
Error: Could not find package at '../build/LanMount-1.0.0.dmg'
```

**Solution:**
- Ensure DMG was created successfully
- Check `build/` directory exists
- Run `fastlane clean` and try again

#### Problem: Notarization Timeout

**Error:**
```
Error: Timeout waiting for notarization
```

**Solution:**
- Apple's servers may be busy, retry later
- Check notarization status manually:
  ```bash
  xcrun notarytool history \
    --apple-id "your@email.com" \
    --team-id "ABCDE12345" \
    --password "xxxx-xxxx-xxxx-xxxx"
  ```

#### Problem: Invalid Team ID

**Error:**
```
Error: Invalid team ID
```

**Solution:**
- Verify Team ID is 10 characters (e.g., `ABCDE12345`)
- Get from https://developer.apple.com/account → Membership
- Team ID is NOT your name

#### Problem: Certificate Not Found

**Error:**
```
Error: No code signing identity found
```

**Solution:**
```bash
# List certificates
security find-identity -v -p codesigning

# If empty, install certificate from developer.apple.com
```

#### Problem: Build Failed

**Error:**
```
Error: xcodebuild failed
```

**Solution:**
```bash
# Clean and rebuild
fastlane clean
xcodebuild clean -project LanMount.xcodeproj -scheme LanMount

# Check Xcode version
xcodebuild -version

# Try building in Xcode first
```

### Advanced Usage

#### Custom Build Configuration

Edit `fastlane/Fastfile` to customize:

```ruby
# Change build configuration
CONFIGURATION = "Debug"  # or "Release"

# Change scheme
SCHEME = "LanMount"

# Change bundle ID
BUNDLE_ID = "com.lanmount.app"
```

#### Skip Tests

Add to lane:

```ruby
lane :release do |options|
  # Skip tests
  options[:skip_tests] = true
  # ...
end
```

#### Custom Notarization Timeout

```bash
# In Fastfile, modify notarize command:
sh(
  "xcrun", "notarytool", "submit",
  "--wait",
  "--timeout", "7200"  # 2 hours
)
```

### Best Practices

1. **Always test first**
   ```bash
   fastlane test_build version:X.X.X-test
   ```

2. **Use semantic versioning**
   - Major: `1.0.0` → `2.0.0` (breaking changes)
   - Minor: `1.0.0` → `1.1.0` (new features)
   - Patch: `1.0.0` → `1.0.1` (bug fixes)

3. **Keep .env secure**
   - Never commit to Git
   - Use different credentials for CI/CD
   - Rotate passwords regularly

4. **Clean before release**
   ```bash
   fastlane clean
   fastlane release version:X.X.X
   ```

5. **Verify notarization**
   ```bash
   # After release
   spctl -a -vv -t install build/LanMount-X.X.X.dmg
   ```

### Integration with GitHub Actions

Fastlane works seamlessly with GitHub Actions:

```yaml
- name: Build and Release
  run: |
    cd LanMount
    fastlane release version:${{ github.ref_name }}
  env:
    APPLE_ID: ${{ secrets.APPLE_ID }}
    TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
    APP_SPECIFIC_PASSWORD: ${{ secrets.APPLE_APP_SPECIFIC_PASSWORD }}
```

See [GitHub Actions Setup](../.github/GITHUB_ACTIONS_SETUP.md) for details.

### Resources

- [Fastlane Documentation](https://docs.fastlane.tools/)
- [Apple Notarization Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Code Signing Guide](CODE_SIGNING.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)

---

## 中文

### 概述

Fastlane 自动化 LanMount 的整个发布流程，包括构建、代码签名、DMG 创建和公证。

### 安装

#### 前提条件

- macOS 12.0 或更高版本
- Xcode 15.0 或更高版本
- Ruby 2.6 或更高版本（macOS 自带）
- Homebrew（推荐）

#### 安装 Fastlane

```bash
# 使用 Homebrew（推荐）
brew install fastlane

# 或使用 RubyGems
sudo gem install fastlane

# 验证安装
fastlane --version
```

#### 安装依赖

```bash
cd LanMount

# 安装 Ruby gems
bundle install
```

### 配置

#### 1. 环境变量

从模板创建 `.env` 文件：

```bash
cp .env.example .env
nano .env
```

必需的变量：

```bash
# Apple Developer 账号
APPLE_ID=your@email.com
TEAM_ID=ABCDE12345
APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx

# 代码签名
CODE_SIGN_IDENTITY=Developer ID Application

# 构建配置
CONFIGURATION=Release
SCHEME=LanMount
```

**重要：**
- `TEAM_ID` 必须是来自 developer.apple.com 的 10 位 Team ID
- `APP_SPECIFIC_PASSWORD` 在 appleid.apple.com 生成
- 永远不要将 `.env` 文件提交到 Git（已在 .gitignore 中）

#### 2. 验证配置

```bash
fastlane validate
```

检查：
- ✅ 环境变量已设置
- ✅ 代码签名证书存在
- ✅ 项目文件存在

### 可用的 Lanes

#### 1. release - 完整发布流程

包含构建、签名、DMG 创建和公证的完整发布。

```bash
# 基本用法
fastlane release version:1.0.0

# 跳过测试
fastlane release version:1.0.0 skip_tests:true

# 跳过公证（用于测试）
fastlane release version:1.0.0 skip_notarize:true

# 跳过版本号更新
fastlane release version:1.0.0 skip_version_bump:true
```

**流程：**
1. 运行测试（可选）
2. 更新版本号和构建号
3. 构建应用程序
4. 创建 DMG
5. 提交公证
6. 装订公证票据
7. 验证公证

**时间：** 15-45 分钟（取决于 Apple 公证队列）

#### 2. test_build - 快速测试构建

不公证的快速测试构建。

```bash
fastlane test_build version:1.0.0-test
```

**流程：**
1. 构建应用程序
2. 创建 DMG
3. 跳过公证

**时间：** 2-5 分钟

#### 3. build_app_release - 仅构建

仅构建应用程序，不创建 DMG。

```bash
fastlane build_app_release
```

**输出：** `build/Release/LanMount.app`

#### 4. create_dmg - 仅创建 DMG

从现有应用程序包创建 DMG。

```bash
fastlane create_dmg version:1.0.0
```

**输入：** `build/Release/LanMount.app`  
**输出：** `build/LanMount-1.0.0.dmg`

#### 5. notarize_dmg - 公证现有 DMG

公证已创建的 DMG。

```bash
fastlane notarize_only dmg:build/LanMount-1.0.0.dmg
```

**流程：**
1. 提交到 Apple 公证服务
2. 等待批准（10-30 分钟）
3. 装订票据到 DMG
4. 验证公证

#### 6. clean - 清理构建文件

删除所有构建产物和缓存。

```bash
fastlane clean
```

**删除：**
- `build/` 目录
- Xcode DerivedData
- 临时 DMG 文件

#### 7. validate - 验证配置

检查是否所有配置都正确。

```bash
fastlane validate
```

### 典型工作流程

#### 首次设置

```bash
# 1. 安装 Fastlane
brew install fastlane

# 2. 安装依赖
cd LanMount
bundle install

# 3. 配置环境
cp .env.example .env
nano .env

# 4. 验证
fastlane validate

# 5. 测试构建
fastlane test_build version:1.0.0-test
```

#### 开发构建

快速测试构建：

```bash
fastlane test_build version:1.0.0-dev
```

#### Beta 发布

带预发布标记的发布：

```bash
fastlane release version:1.0.0-beta
```

#### 生产发布

包含公证的完整发布：

```bash
fastlane release version:1.0.0
```

### 故障排除

#### 问题："Could not find package"

**错误：**
```
Error: Could not find package at '../build/LanMount-1.0.0.dmg'
```

**解决方案：**
- 确保 DMG 创建成功
- 检查 `build/` 目录是否存在
- 运行 `fastlane clean` 后重试

#### 问题：公证超时

**错误：**
```
Error: Timeout waiting for notarization
```

**解决方案：**
- Apple 服务器可能繁忙，稍后重试
- 手动检查公证状态：
  ```bash
  xcrun notarytool history \
    --apple-id "your@email.com" \
    --team-id "ABCDE12345" \
    --password "xxxx-xxxx-xxxx-xxxx"
  ```

#### 问题：无效的 Team ID

**错误：**
```
Error: Invalid team ID
```

**解决方案：**
- 验证 Team ID 是 10 位字符（例如：`ABCDE12345`）
- 从 https://developer.apple.com/account → Membership 获取
- Team ID 不是你的名字

#### 问题：找不到证书

**错误：**
```
Error: No code signing identity found
```

**解决方案：**
```bash
# 列出证书
security find-identity -v -p codesigning

# 如果为空，从 developer.apple.com 安装证书
```

#### 问题：构建失败

**错误：**
```
Error: xcodebuild failed
```

**解决方案：**
```bash
# 清理并重新构建
fastlane clean
xcodebuild clean -project LanMount.xcodeproj -scheme LanMount

# 检查 Xcode 版本
xcodebuild -version

# 先在 Xcode 中尝试构建
```

### 高级用法

#### 自定义构建配置

编辑 `fastlane/Fastfile` 进行自定义：

```ruby
# 更改构建配置
CONFIGURATION = "Debug"  # 或 "Release"

# 更改 scheme
SCHEME = "LanMount"

# 更改 bundle ID
BUNDLE_ID = "com.lanmount.app"
```

#### 跳过测试

添加到 lane：

```ruby
lane :release do |options|
  # 跳过测试
  options[:skip_tests] = true
  # ...
end
```

#### 自定义公证超时

```bash
# 在 Fastfile 中，修改 notarize 命令：
sh(
  "xcrun", "notarytool", "submit",
  "--wait",
  "--timeout", "7200"  # 2 小时
)
```

### 最佳实践

1. **始终先测试**
   ```bash
   fastlane test_build version:X.X.X-test
   ```

2. **使用语义化版本**
   - 主版本：`1.0.0` → `2.0.0`（破坏性更改）
   - 次版本：`1.0.0` → `1.1.0`（新功能）
   - 补丁：`1.0.0` → `1.0.1`（错误修复）

3. **保护 .env 安全**
   - 永远不要提交到 Git
   - CI/CD 使用不同的凭证
   - 定期轮换密码

4. **发布前清理**
   ```bash
   fastlane clean
   fastlane release version:X.X.X
   ```

5. **验证公证**
   ```bash
   # 发布后
   spctl -a -vv -t install build/LanMount-X.X.X.dmg
   ```

### 与 GitHub Actions 集成

Fastlane 与 GitHub Actions 无缝集成：

```yaml
- name: Build and Release
  run: |
    cd LanMount
    fastlane release version:${{ github.ref_name }}
  env:
    APPLE_ID: ${{ secrets.APPLE_ID }}
    TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
    APP_SPECIFIC_PASSWORD: ${{ secrets.APPLE_APP_SPECIFIC_PASSWORD }}
```

详见 [GitHub Actions 配置](../.github/GITHUB_ACTIONS_SETUP.md)。

### 资源

- [Fastlane 文档](https://docs.fastlane.tools/)
- [Apple 公证指南](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [代码签名指南](CODE_SIGNING.md)
- [故障排除指南](TROUBLESHOOTING.md)

---

**提示 | Tip:** 首次使用建议先运行 `test_build` 验证配置，然后再进行完整的 `release`。
