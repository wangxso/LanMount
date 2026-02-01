# Code Signing Guide | 代码签名指南

[English](#english) | [中文](#中文)

---

## English

### Overview

Code signing and notarization are required for distributing macOS applications outside the Mac App Store. This guide covers the complete process.

### Prerequisites

- Apple Developer account ($99/year)
- macOS with Xcode installed
- Valid Developer ID Application certificate

### Step 1: Create Developer ID Certificate

#### 1.1 Generate Certificate Signing Request (CSR)

1. Open **Keychain Access**
2. Menu: **Keychain Access** → **Certificate Assistant** → **Request a Certificate from a Certificate Authority**
3. Fill in:
   - User Email Address: Your email
   - Common Name: Your name
   - Request: **Saved to disk**
4. Click **Continue** and save the CSR file

#### 1.2 Create Certificate on Apple Developer Portal

1. Visit https://developer.apple.com/account/resources/certificates
2. Click **+** to create new certificate
3. Select **Developer ID Application**
4. Upload your CSR file
5. Download the certificate (.cer file)

#### 1.3 Install Certificate

1. Double-click the downloaded .cer file
2. It will be added to your Keychain
3. Verify: Open **Keychain Access** → **My Certificates**
4. You should see: "Developer ID Application: Your Name (TEAM_ID)"

### Step 2: Export Certificate for CI/CD

For GitHub Actions or other CI/CD systems:

#### 2.1 Export as .p12

1. In **Keychain Access**, find your certificate
2. Right-click → **Export**
3. File format: **.p12**
4. Set a password (remember it!)
5. Save the file

#### 2.2 Convert to Base64

```bash
# Convert .p12 to Base64
base64 -i certificate.p12 -o certificate.p12.base64

# Copy to clipboard
cat certificate.p12.base64 | pbcopy
```

### Step 3: App-Specific Password

Required for notarization:

1. Visit https://appleid.apple.com
2. Sign in
3. Go to **Security** → **App-Specific Passwords**
4. Click **Generate Password**
5. Label: "LanMount Notarization"
6. Copy the generated password (format: `xxxx-xxxx-xxxx-xxxx`)

### Step 4: Find Your Team ID

1. Visit https://developer.apple.com/account
2. Click **Membership**
3. Find **Team ID** (10-character string, e.g., `ABCDE12345`)

**Important:** Team ID is NOT your name!

### Step 5: Configure Environment

Create `.env` file:

```bash
cd LanMount
cp .env.example .env
nano .env
```

Fill in:

```bash
APPLE_ID=your@email.com
TEAM_ID=ABCDE12345
APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx
CODE_SIGN_IDENTITY=Developer ID Application
```

### Step 6: Verify Setup

```bash
# Check certificate
security find-identity -v -p codesigning

# Validate Fastlane configuration
fastlane validate
```

### Notarization Process

#### What is Notarization?

Apple's security process that scans your app for malicious content. Required for distribution outside the Mac App Store.

#### Notarization Steps

1. **Build** - Compile with hardened runtime
2. **Sign** - Code sign with Developer ID
3. **Submit** - Upload to Apple's notary service
4. **Wait** - Apple scans (10-30 minutes)
5. **Staple** - Attach notarization ticket
6. **Verify** - Confirm notarization

#### Manual Notarization

```bash
# Submit for notarization
xcrun notarytool submit LanMount.dmg \
  --apple-id "your@email.com" \
  --team-id "ABCDE12345" \
  --password "xxxx-xxxx-xxxx-xxxx" \
  --wait

# Staple ticket
xcrun stapler staple LanMount.dmg

# Verify
xcrun stapler validate LanMount.dmg
```

### Troubleshooting

#### Certificate Not Found

```bash
# List all certificates
security find-identity -v

# Import certificate
security import certificate.p12 -k ~/Library/Keychains/login.keychain-db
```

#### Notarization Failed

Check logs:
```bash
xcrun notarytool log <submission-id> \
  --apple-id "your@email.com" \
  --team-id "ABCDE12345" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

Common issues:
- Hardened runtime not enabled
- Missing entitlements
- Unsigned frameworks

#### Team ID Error

Error: "Invalid team ID"

Solution: Ensure Team ID is the 10-character string from developer.apple.com, not your name.

### Security Best Practices

1. **Never commit certificates** - Add to .gitignore
2. **Use environment variables** - Don't hardcode credentials
3. **Rotate passwords** - Update app-specific passwords periodically
4. **Secure CI/CD secrets** - Use GitHub Secrets or similar
5. **Backup certificates** - Export and store securely

### Resources

- [Apple Code Signing Guide](https://developer.apple.com/support/code-signing/)
- [Notarization Documentation](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Fastlane Code Signing](https://docs.fastlane.tools/codesigning/getting-started/)

---

## 中文

### 概述

代码签名和公证是在 Mac App Store 之外分发 macOS 应用程序的必要步骤。本指南涵盖完整流程。

### 前提条件

- Apple Developer 账号（$99/年）
- 安装了 Xcode 的 macOS
- 有效的 Developer ID Application 证书

### 第一步：创建 Developer ID 证书

#### 1.1 生成证书签名请求（CSR）

1. 打开**钥匙串访问**
2. 菜单：**钥匙串访问** → **证书助理** → **从证书颁发机构请求证书**
3. 填写：
   - 用户电子邮件地址：你的邮箱
   - 常用名称：你的名字
   - 请求：**存储到磁盘**
4. 点击**继续**并保存 CSR 文件

#### 1.2 在 Apple Developer 门户创建证书

1. 访问 https://developer.apple.com/account/resources/certificates
2. 点击 **+** 创建新证书
3. 选择 **Developer ID Application**
4. 上传你的 CSR 文件
5. 下载证书（.cer 文件）

#### 1.3 安装证书

1. 双击下载的 .cer 文件
2. 它将被添加到你的钥匙串
3. 验证：打开**钥匙串访问** → **我的证书**
4. 你应该看到："Developer ID Application: Your Name (TEAM_ID)"

### 第二步：导出证书用于 CI/CD

用于 GitHub Actions 或其他 CI/CD 系统：

#### 2.1 导出为 .p12

1. 在**钥匙串访问**中，找到你的证书
2. 右键点击 → **导出**
3. 文件格式：**.p12**
4. 设置密码（记住它！）
5. 保存文件

#### 2.2 转换为 Base64

```bash
# 将 .p12 转换为 Base64
base64 -i certificate.p12 -o certificate.p12.base64

# 复制到剪贴板
cat certificate.p12.base64 | pbcopy
```

### 第三步：App 专用密码

公证所需：

1. 访问 https://appleid.apple.com
2. 登录
3. 进入**安全** → **App 专用密码**
4. 点击**生成密码**
5. 标签："LanMount Notarization"
6. 复制生成的密码（格式：`xxxx-xxxx-xxxx-xxxx`）

### 第四步：查找你的 Team ID

1. 访问 https://developer.apple.com/account
2. 点击 **Membership**
3. 找到 **Team ID**（10 位字符串，例如：`ABCDE12345`）

**重要：** Team ID 不是你的名字！

### 第五步：配置环境

创建 `.env` 文件：

```bash
cd LanMount
cp .env.example .env
nano .env
```

填写：

```bash
APPLE_ID=your@email.com
TEAM_ID=ABCDE12345
APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx
CODE_SIGN_IDENTITY=Developer ID Application
```

### 第六步：验证设置

```bash
# 检查证书
security find-identity -v -p codesigning

# 验证 Fastlane 配置
fastlane validate
```

### 公证流程

#### 什么是公证？

Apple 的安全流程，扫描你的应用是否有恶意内容。在 Mac App Store 之外分发时必需。

#### 公证步骤

1. **构建** - 使用强化运行时编译
2. **签名** - 使用 Developer ID 代码签名
3. **提交** - 上传到 Apple 公证服务
4. **等待** - Apple 扫描（10-30 分钟）
5. **装订** - 附加公证票据
6. **验证** - 确认公证

#### 手动公证

```bash
# 提交公证
xcrun notarytool submit LanMount.dmg \
  --apple-id "your@email.com" \
  --team-id "ABCDE12345" \
  --password "xxxx-xxxx-xxxx-xxxx" \
  --wait

# 装订票据
xcrun stapler staple LanMount.dmg

# 验证
xcrun stapler validate LanMount.dmg
```

### 故障排除

#### 找不到证书

```bash
# 列出所有证书
security find-identity -v

# 导入证书
security import certificate.p12 -k ~/Library/Keychains/login.keychain-db
```

#### 公证失败

查看日志：
```bash
xcrun notarytool log <submission-id> \
  --apple-id "your@email.com" \
  --team-id "ABCDE12345" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

常见问题：
- 未启用强化运行时
- 缺少权限
- 未签名的框架

#### Team ID 错误

错误："Invalid team ID"

解决方案：确保 Team ID 是来自 developer.apple.com 的 10 位字符串，不是你的名字。

### 安全最佳实践

1. **永远不要提交证书** - 添加到 .gitignore
2. **使用环境变量** - 不要硬编码凭证
3. **定期轮换密码** - 定期更新 App 专用密码
4. **保护 CI/CD secrets** - 使用 GitHub Secrets 或类似工具
5. **备份证书** - 导出并安全存储

### 资源

- [Apple 代码签名指南](https://developer.apple.com/support/code-signing/)
- [公证文档](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Fastlane 代码签名](https://docs.fastlane.tools/codesigning/getting-started/)

---

**提示 | Tip:** 证书有效期为 5 年，到期前需要续期。
