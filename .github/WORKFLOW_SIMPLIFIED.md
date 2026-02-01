# Workflow 简化完成 | Workflow Simplified

## 变更说明 | Changes

已将 GitHub Actions workflow 简化，移除了 Homebrew Cask 自动更新功能。

The GitHub Actions workflow has been simplified by removing the Homebrew Cask auto-update feature.

---

## 移除的功能 | Removed Features

### ❌ Homebrew Cask 自动更新

**之前的功能：**
- 自动克隆 homebrew-lanmount 仓库
- 更新 Casks/lanmount.rb 文件
- 提交并推送更新

**移除原因：**
- 不需要自动更新 Homebrew
- 简化 workflow 流程
- 减少所需的 secrets 配置

---

## 当前 Workflow 功能 | Current Workflow Features

### ✅ 核心功能

1. **构建应用** - 使用 Fastlane 构建 Release 版本
2. **代码签名** - 使用 Developer ID 证书签名
3. **创建 DMG** - 打包为 DMG 安装包
4. **Apple 公证** - 提交到 Apple 进行公证（可选）
5. **创建 Release** - 在 GitHub 创建 Release
6. **上传 DMG** - 将 DMG 附加到 Release

### 📋 所需 Secrets

只需要以下 5 个 secrets：

| Secret | 说明 |
|--------|------|
| `APPLE_DEVELOPER_CERTIFICATE_P12_BASE64` | Base64 编码的证书 |
| `APPLE_DEVELOPER_CERTIFICATE_PASSWORD` | 证书密码 |
| `APPLE_ID` | Apple ID 邮箱 |
| `APPLE_TEAM_ID` | 10 位 Team ID |
| `APPLE_APP_SPECIFIC_PASSWORD` | App 专用密码 |

**不再需要：**
- ~~`HOMEBREW_TAP_TOKEN`~~ ❌

---

## Workflow 流程 | Workflow Process

```
触发 (Tag v* 或手动)
    ↓
检出代码
    ↓
安装 Fastlane
    ↓
安装证书
    ↓
创建 .env 文件
    ↓
运行 Fastlane release
    ├─ 构建应用
    ├─ 创建 DMG
    └─ 公证 (可选)
    ↓
计算 SHA256
    ↓
创建 GitHub Release
    ├─ 生成 Release Notes
    └─ 上传 DMG
    ↓
清理
    ↓
完成 ✅
```

---

## 使用方法 | Usage

### 方法 1：推送 Tag

```bash
git tag v1.0.0
git push origin v1.0.0
```

### 方法 2：手动触发

1. 访问 GitHub Actions 页面
2. 选择 "Release" workflow
3. 点击 "Run workflow"
4. 输入版本号（如 `1.0.0`）
5. 选择选项：
   - Mark as pre-release（是否为预发布）
   - Skip notarization（是否跳过公证，用于测试）

---

## Release 输出 | Release Output

### GitHub Release 包含：

1. **DMG 文件** - `LanMount-X.X.X.dmg`
2. **Release Notes** - 包含：
   - 版本信息
   - 系统要求
   - 安全信息（签名、公证状态）
   - 安装说明
   - SHA256 校验和
   - CHANGELOG 链接

### 安装说明

Release Notes 中包含简单的安装步骤：

```
1. Download the DMG file below
2. Open the DMG and drag LanMount to Applications folder
3. Launch LanMount from Applications
4. Grant necessary permissions when prompted
```

---

## 文件大小对比 | File Size Comparison

| 版本 | 行数 | 说明 |
|------|------|------|
| 之前 | ~370 行 | 包含 Homebrew 更新 |
| 之后 | ~303 行 | 仅核心功能 |
| **减少** | **~67 行** | **简化 18%** |

---

## 配置验证 | Configuration Verification

### ✅ 验证通过

- [x] YAML 语法有效
- [x] 所有 Homebrew 引用已移除
- [x] Secrets 使用正确
- [x] 工作流程完整
- [x] Release Notes 更新

### 测试命令

```bash
# 验证 YAML 语法
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml'))"

# 检查 Homebrew 引用
grep -i "homebrew" .github/workflows/release.yml

# 检查文件行数
wc -l .github/workflows/release.yml
```

---

## 如果需要 Homebrew | If Homebrew Needed

如果将来需要 Homebrew Cask，可以手动更新：

### 手动更新 Homebrew Cask

1. **下载 DMG 并计算 SHA256**
   ```bash
   shasum -a 256 LanMount-1.0.0.dmg
   ```

2. **更新 Cask 文件**
   ```ruby
   cask "lanmount" do
     version "1.0.0"
     sha256 "..."
     
     url "https://github.com/user/LanMount/releases/download/v#{version}/LanMount-#{version}.dmg"
     name "LanMount"
     desc "macOS SMB network share mounter"
     homepage "https://github.com/user/LanMount"
     
     app "LanMount.app"
   end
   ```

3. **提交到 Homebrew Tap**
   ```bash
   git add Casks/lanmount.rb
   git commit -m "Update LanMount to v1.0.0"
   git push
   ```

---

## 相关文档 | Related Documentation

- [GitHub Actions Setup](GITHUB_ACTIONS_SETUP.md) - 完整配置指南
- [Workflow Fix](WORKFLOW_FIX.md) - Secrets 语法修复
- [Fastlane Guide](../docs/FASTLANE_GUIDE.md) - Fastlane 使用说明
- [Release Guide](../docs/RELEASE_GUIDE.md) - 发布流程

---

## 总结 | Summary

✅ **简化完成** - Workflow 现在只专注于核心功能：构建、签名、公证、发布

**优点：**
- 更简单的配置
- 更少的 secrets 需求
- 更快的执行时间
- 更容易维护

**功能保留：**
- 完整的构建流程
- 代码签名和公证
- GitHub Release 创建
- DMG 文件上传

---

**简化时间 | Simplified Date:** 2026-01-31  
**文件 | File:** `.github/workflows/release.yml`  
**状态 | Status:** ✅ 完成 | Complete
