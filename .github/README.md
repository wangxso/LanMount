# GitHub Actions 配置

本目录包含 LanMount 的 GitHub Actions workflows。

## 📁 文件说明

- **`workflows/release.yml`** - 自动发布 workflow
- **`GITHUB_ACTIONS_SETUP.md`** - 详细配置指南
- **`RELEASE_TEMPLATE.md`** - Release notes 模板

## 🚀 快速开始

### 1. 配置 Secrets

按照 [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md) 配置以下 secrets：

- `APPLE_DEVELOPER_CERTIFICATE_P12_BASE64`
- `APPLE_DEVELOPER_CERTIFICATE_PASSWORD`
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`

### 2. 触发发布

**方法 1：推送 Tag**
```bash
git tag v1.0.0
git push origin v1.0.0
```

**方法 2：手动触发**
1. 访问 GitHub Actions
2. 选择 "Release" workflow
3. 点击 "Run workflow"
4. 输入版本号

### 3. 等待完成

Workflow 会自动：
- ✅ 构建应用
- ✅ 签名和公证
- ✅ 创建 GitHub Release
- ✅ 上传 DMG

## 📖 详细文档

查看 [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md) 了解：
- 如何导出和配置证书
- 如何生成 App-specific password
- 如何测试 workflow
- 故障排除

## 🔧 本地发布

如果不想使用 GitHub Actions，可以本地发布：

```bash
cd LanMount
fastlane release version:1.0.0
```

详见 [FASTLANE_GUIDE.md](../FASTLANE_GUIDE.md)
