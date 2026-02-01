# ✅ GitHub Actions 自动发布已配置

## 🎉 配置完成

GitHub Actions workflow 已成功配置，可以自动构建、签名、公证并发布 LanMount。

## 📋 配置的功能

### Workflow 文件
- ✅ `.github/workflows/release.yml` - 主 workflow 文件
- ✅ 使用 Fastlane 简化构建流程
- ✅ 支持手动触发和 tag 触发
- ✅ 完整的构建、签名、公证流程

### 文档
- ✅ `.github/GITHUB_ACTIONS_SETUP.md` - 详细配置指南
- ✅ `.github/README.md` - 快速开始指南
- ✅ `README.md` - 已更新，包含发布说明

## 🚀 使用方法

### 方法 1：推送 Tag（推荐）

```bash
# 创建 tag
git tag v1.0.0

# 推送 tag
git push origin v1.0.0
```

GitHub Actions 会自动触发，执行完整的发布流程。

### 方法 2：手动触发

1. 访问 GitHub 仓库的 `Actions` 标签
2. 选择 "Release" workflow
3. 点击 "Run workflow"
4. 填写参数：
   - **Version:** 版本号（例如：`1.0.0`）
   - **Mark as pre-release:** 是否预发布
   - **Skip notarization:** 是否跳过公证（测试用）
5. 点击 "Run workflow"

## 🔐 需要配置的 Secrets

在使用前，需要在 GitHub 仓库中配置以下 secrets：

| Secret 名称 | 说明 | 如何获取 |
|------------|------|---------|
| `APPLE_DEVELOPER_CERTIFICATE_P12_BASE64` | 证书 Base64 | 从钥匙串导出 .p12 并转换 |
| `APPLE_DEVELOPER_CERTIFICATE_PASSWORD` | 证书密码 | 导出 .p12 时设置的密码 |
| `APPLE_ID` | Apple ID | 你的 Apple ID 邮箱 |
| `APPLE_TEAM_ID` | Team ID | developer.apple.com 查看 |
| `APPLE_APP_SPECIFIC_PASSWORD` | App 专用密码 | appleid.apple.com 生成 |
| `HOMEBREW_TAP_TOKEN` | GitHub Token | 可选，用于更新 Homebrew |

详细配置步骤见 [GITHUB_ACTIONS_SETUP.md](.github/GITHUB_ACTIONS_SETUP.md)

## 📊 Workflow 流程

1. **触发** - 推送 tag 或手动触发
2. **环境准备** - 安装 Xcode、Fastlane、Ruby
3. **证书安装** - 导入 Apple Developer 证书
4. **构建** - 使用 Fastlane 构建应用
5. **签名** - 使用 Developer ID 签名
6. **创建 DMG** - 打包为 DMG 安装包
7. **公证** - 提交到 Apple 公证服务
8. **装订** - 装订公证票据
9. **发布** - 创建 GitHub Release
10. **上传** - 上传 DMG 到 Release
11. **Homebrew** - 可选更新 Homebrew Cask

## ✨ 自动生成的内容

每次发布会自动生成：

### GitHub Release
- **Tag:** `v1.0.0`
- **Title:** `LanMount v1.0.0`
- **Release Notes:** 包含下载链接、系统要求、安装说明
- **Assets:** DMG 文件

### Release Notes 包含
- 📦 下载链接
- 💻 系统要求
- 🔐 安全信息（签名、公证状态）
- 📝 安装说明
- 🍺 Homebrew 安装命令
- 🔑 SHA256 校验和

## 🧪 测试建议

### 首次配置

1. **测试构建（不公证）**
   ```bash
   # 手动触发 workflow
   # Version: 1.0.0-test
   # Skip notarization: ✅
   ```
   
   验证：
   - ✅ 证书配置正确
   - ✅ 构建成功
   - ✅ DMG 创建成功

2. **完整测试（包含公证）**
   ```bash
   # 手动触发 workflow
   # Version: 1.0.0-beta
   # Mark as pre-release: ✅
   # Skip notarization: ❌
   ```
   
   验证：
   - ✅ 公证成功
   - ✅ Release 创建成功
   - ✅ DMG 可以下载和安装

### 正式发布

确认测试通过后：

```bash
git tag v1.0.0
git push origin v1.0.0
```

## 🔄 与本地发布对比

| 功能 | 本地发布 | GitHub Actions |
|------|---------|----------------|
| 构建 | ✅ Fastlane | ✅ Fastlane |
| 签名 | ✅ 本地证书 | ✅ 自动导入证书 |
| 公证 | ✅ 手动等待 | ✅ 自动等待 |
| 发布 | ❌ 手动上传 | ✅ 自动创建 Release |
| Homebrew | ❌ 手动更新 | ✅ 自动更新（可选） |
| 环境 | 需要本地配置 | 云端自动配置 |
| 速度 | 取决于本地机器 | 稳定的云端资源 |

## 📚 相关文档

- [GitHub Actions 配置指南](../.github/GITHUB_ACTIONS_SETUP.md) - 详细配置步骤
- [Fastlane 指南](FASTLANE_GUIDE.md) - Fastlane 使用说明
- [快速开始](QUICK_START.md) - 快速构建指南
- [代码签名指南](CODE_SIGNING.md) - 签名和公证说明

## 🎯 下一步

1. **配置 Secrets** - 按照 [GITHUB_ACTIONS_SETUP.md](.github/GITHUB_ACTIONS_SETUP.md) 配置
2. **测试构建** - 手动触发一次测试构建
3. **完整测试** - 测试包含公证的完整流程
4. **正式发布** - 推送 tag 进行正式发布

## 💡 提示

- 首次配置建议先跳过公证测试，确认构建流程正常
- 公证需要 10-30 分钟，请耐心等待
- 可以同时使用本地发布和 GitHub Actions
- GitHub Actions 适合正式发布，本地发布适合快速测试

---

**恭喜！** GitHub Actions 自动发布已配置完成。🎉
