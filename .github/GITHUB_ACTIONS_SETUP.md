# GitHub Actions 自动发布配置指南

> 📍 **注意：** 这是 GitHub Actions 的配置文档。项目主文档请查看 [../README.md](../README.md)

本文档说明如何配置 GitHub Actions 以实现自动构建、签名、公证和发布 LanMount。

## 📋 前提条件

1. ✅ Apple Developer 账号
2. ✅ Developer ID Application 证书
3. ✅ App-specific password
4. ✅ GitHub 仓库管理员权限

## 🔐 配置 GitHub Secrets

### 第一步：导出 Apple Developer 证书

1. **打开钥匙串访问（Keychain Access）**

2. **找到你的 Developer ID Application 证书**
   - 在左侧选择 "登录" 钥匙串
   - 在类别中选择 "我的证书"
   - 找到 "Developer ID Application: Your Name (TEAM_ID)"

3. **导出证书为 .p12 文件**
   - 右键点击证书
   - 选择 "导出..."
   - 文件格式选择 ".p12"
   - 保存为 `certificate.p12`
   - 设置一个密码（记住这个密码！）

4. **转换为 Base64**
   ```bash
   base64 -i certificate.p12 -o certificate.p12.base64
   ```

5. **复制 Base64 内容**
   ```bash
   cat certificate.p12.base64 | pbcopy
   ```

### 第二步：添加 GitHub Secrets

访问你的 GitHub 仓库：`Settings` → `Secrets and variables` → `Actions` → `New repository secret`

添加以下 secrets：

#### 1. APPLE_DEVELOPER_CERTIFICATE_P12_BASE64

- **Name:** `APPLE_DEVELOPER_CERTIFICATE_P12_BASE64`
- **Value:** 粘贴刚才复制的 Base64 内容

#### 2. APPLE_DEVELOPER_CERTIFICATE_PASSWORD

- **Name:** `APPLE_DEVELOPER_CERTIFICATE_PASSWORD`
- **Value:** 导出 .p12 时设置的密码

#### 3. APPLE_ID

- **Name:** `APPLE_ID`
- **Value:** 你的 Apple ID 邮箱（例如：`your@email.com`）

#### 4. APPLE_TEAM_ID

- **Name:** `APPLE_TEAM_ID`
- **Value:** 你的 Team ID（10 位字符，例如：`ABCDE12345`）

**如何查找 Team ID：**
1. 访问 https://developer.apple.com/account
2. 登录后点击 "Membership"
3. 找到 "Team ID"

#### 5. APPLE_APP_SPECIFIC_PASSWORD

- **Name:** `APPLE_APP_SPECIFIC_PASSWORD`
- **Value:** App-specific password

**如何生成 App-specific password：**
1. 访问 https://appleid.apple.com
2. 登录 → 安全 → App 专用密码
3. 点击 "生成密码"
4. 输入标签（例如："LanMount GitHub Actions"）
5. 复制生成的密码（格式：`xxxx-xxxx-xxxx-xxxx`）

#### 6. HOMEBREW_TAP_TOKEN（可选）

如果你想自动更新 Homebrew Cask：

- **Name:** `HOMEBREW_TAP_TOKEN`
- **Value:** GitHub Personal Access Token

**如何生成 Token：**
1. GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token (classic)
3. 选择权限：`repo` (Full control of private repositories)
4. 复制生成的 token

## 🚀 使用方法

### 方法 1：手动触发（推荐用于测试）

1. 访问 GitHub 仓库的 `Actions` 标签
2. 选择 "Release" workflow
3. 点击 "Run workflow"
4. 填写参数：
   - **Version:** 版本号（例如：`1.0.0`）
   - **Mark as pre-release:** 是否标记为预发布
   - **Skip notarization:** 是否跳过公证（测试用）
5. 点击 "Run workflow"

### 方法 2：推送 Tag 自动触发

```bash
# 创建并推送 tag
git tag v1.0.0
git push origin v1.0.0
```

workflow 会自动：
1. ✅ 检出代码
2. ✅ 安装 Fastlane
3. ✅ 安装证书
4. ✅ 构建应用
5. ✅ 创建 DMG
6. ✅ 公证 DMG
7. ✅ 创建 GitHub Release
8. ✅ 上传 DMG 到 Release
9. ✅ 更新 Homebrew Cask（如果配置）

## 📊 Workflow 输出

成功后会创建：

1. **GitHub Release**
   - Tag: `v1.0.0`
   - Title: `LanMount v1.0.0`
   - 包含 Release Notes
   - 附带 DMG 文件

2. **Release Notes 包含：**
   - 下载链接
   - 系统要求
   - 安全信息
   - 安装说明
   - Homebrew 安装命令
   - SHA256 校验和

## 🔍 验证配置

### 测试构建（不公证）

首次配置后，建议先测试构建：

1. 手动触发 workflow
2. 版本号填写：`1.0.0-test`
3. 勾选 "Skip notarization"
4. 运行

这样可以快速验证：
- ✅ 证书配置正确
- ✅ 构建成功
- ✅ DMG 创建成功

### 完整测试（包含公证）

确认测试构建成功后：

1. 手动触发 workflow
2. 版本号填写：`1.0.0-beta`
3. 勾选 "Mark as pre-release"
4. 不勾选 "Skip notarization"
5. 运行

这会执行完整流程，包括公证（需要 10-30 分钟）。

## 🐛 故障排除

### 问题 1：证书导入失败

**错误：** `security: SecKeychainItemImport: The specified item already exists in the keychain.`

**解决：** 这通常不是问题，workflow 会继续执行。

### 问题 2：公证失败 - Team ID 错误

**错误：** `Error: Invalid team ID`

**解决：** 确保 `APPLE_TEAM_ID` 是 10 位字符的 Team ID，不是你的名字。

### 问题 3：公证超时

**错误：** `Error: Timeout waiting for notarization`

**解决：** 
- Apple 服务器可能繁忙，重试即可
- 或者增加 `--timeout` 值（默认 3600 秒）

### 问题 4：Fastlane 找不到

**错误：** `bundle: command not found`

**解决：** 确保 `Gemfile` 和 `Gemfile.lock` 已提交到仓库。

## 📝 Workflow 配置文件

Workflow 文件位置：`.github/workflows/release.yml`

主要特性：
- ✅ 使用 Fastlane 简化构建流程
- ✅ 自动版本号管理
- ✅ 完整的代码签名和公证
- ✅ 自动生成 Release Notes
- ✅ 可选的 Homebrew Cask 更新
- ✅ 详细的构建摘要

## 🔄 更新 Workflow

如果需要修改 workflow：

1. 编辑 `.github/workflows/release.yml`
2. 提交并推送更改
3. 下次运行时会使用新配置

## 📚 相关文档

- [Fastlane 指南](../FASTLANE_GUIDE.md)
- [快速开始](../QUICK_START.md)
- [代码签名指南](../CODE_SIGNING.md)
- [发布指南](../RELEASE_GUIDE.md)

## 🎉 完成！

配置完成后，你可以：

1. **本地开发：** 使用 `fastlane test_build`
2. **本地发布：** 使用 `fastlane release`
3. **自动发布：** 推送 tag 或手动触发 GitHub Actions

---

**提示：** 首次配置建议先运行测试构建，确认所有配置正确后再进行完整发布。
