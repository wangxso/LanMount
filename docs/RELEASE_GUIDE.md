# Release Guide | 发布指南

[English](#english) | [中文](#中文)

---

## English

### Overview

This guide covers the complete process for releasing LanMount, from preparation to distribution.

### Release Checklist

#### Pre-Release

- [ ] All features tested and working
- [ ] No critical bugs
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Version number decided
- [ ] Code signing certificate valid
- [ ] .env file configured

#### Release

- [ ] Build successful
- [ ] DMG created
- [ ] Notarization successful
- [ ] Manual testing on clean macOS
- [ ] GitHub Release created
- [ ] Release notes published

#### Post-Release

- [ ] Homebrew Cask updated (if applicable)
- [ ] Social media announcement
- [ ] Monitor for issues
- [ ] Respond to user feedback

### Release Types

#### 1. Development Release (X.X.X-dev)

For internal testing only.

```bash
fastlane test_build version:1.0.0-dev
```

**Characteristics:**
- No notarization
- Quick build (2-5 minutes)
- Not for distribution

#### 2. Beta Release (X.X.X-beta)

For external testing with selected users.

```bash
fastlane release version:1.0.0-beta
```

**Characteristics:**
- Full notarization
- Marked as pre-release
- Limited distribution
- Feedback collection

#### 3. Release Candidate (X.X.X-rc)

Final testing before production.

```bash
fastlane release version:1.0.0-rc1
```

**Characteristics:**
- Full notarization
- Feature complete
- Bug fixes only
- Wide testing

#### 4. Production Release (X.X.X)

Official public release.

```bash
fastlane release version:1.0.0
```

**Characteristics:**
- Full notarization
- Public distribution
- Stable and tested
- Full documentation

### Versioning Strategy

Follow [Semantic Versioning](https://semver.org/):

**Format:** MAJOR.MINOR.PATCH

#### MAJOR (X.0.0)

Breaking changes that require user action.

**Examples:**
- Complete UI redesign
- Removed features
- Changed data format
- macOS version requirement change

**Increment:** `1.0.0` → `2.0.0`

#### MINOR (0.X.0)

New features, backward compatible.

**Examples:**
- New mount options
- Additional settings
- Performance improvements
- New integrations

**Increment:** `1.0.0` → `1.1.0`

#### PATCH (0.0.X)

Bug fixes, backward compatible.

**Examples:**
- Bug fixes
- Security patches
- Minor UI tweaks
- Documentation updates

**Increment:** `1.0.0` → `1.0.1`

### Release Process

#### Method 1: Local Release (Fastlane)

**Step 1: Prepare**

```bash
cd LanMount

# Update version in CHANGELOG.md
nano CHANGELOG.md

# Commit changes
git add .
git commit -m "Prepare for v1.0.0 release"
git push
```

**Step 2: Build and Notarize**

```bash
# Full release
fastlane release version:1.0.0
```

This will:
1. ✅ Run tests
2. ✅ Update version number
3. ✅ Build application
4. ✅ Create DMG
5. ✅ Submit for notarization
6. ✅ Wait for approval (10-30 min)
7. ✅ Staple ticket
8. ✅ Verify notarization

**Step 3: Test DMG**

```bash
# Mount DMG
open build/LanMount-1.0.0.dmg

# Verify notarization
spctl -a -vv -t install build/LanMount-1.0.0.dmg

# Test installation
# Drag to Applications, launch, test features
```

**Step 4: Create GitHub Release**

```bash
# Create and push tag
git tag v1.0.0
git push origin v1.0.0

# Or create release manually on GitHub
```

**Step 5: Upload DMG**

1. Go to GitHub Releases
2. Click "Draft a new release"
3. Select tag `v1.0.0`
4. Upload `LanMount-1.0.0.dmg`
5. Add release notes
6. Publish release

#### Method 2: Automated Release (GitHub Actions)

**Step 1: Prepare**

```bash
cd LanMount

# Update CHANGELOG.md
nano CHANGELOG.md

# Commit and push
git add .
git commit -m "Prepare for v1.0.0 release"
git push
```

**Step 2: Create and Push Tag**

```bash
# Create tag
git tag v1.0.0

# Push tag (triggers workflow)
git push origin v1.0.0
```

**Step 3: Monitor Workflow**

1. Go to GitHub Actions tab
2. Watch "Release" workflow
3. Wait for completion (15-45 minutes)

**Step 4: Verify Release**

1. Check GitHub Releases page
2. Download and test DMG
3. Verify release notes

### Release Notes Template

```markdown
## LanMount v1.0.0

### 🎉 New Features

- Feature 1 description
- Feature 2 description

### 🐛 Bug Fixes

- Fixed issue #123: Description
- Fixed crash when...

### 🔧 Improvements

- Improved performance of...
- Updated UI for...

### 📚 Documentation

- Added guide for...
- Updated README with...

### 🔒 Security

- Fixed security issue...
- Updated dependencies

### ⚠️ Breaking Changes

- Changed behavior of...
- Removed deprecated...

### 📦 Installation

**Direct Download:**
```bash
# Download DMG
curl -LO https://github.com/user/LanMount/releases/download/v1.0.0/LanMount-1.0.0.dmg

# Verify checksum
shasum -a 256 LanMount-1.0.0.dmg
```

**Homebrew:**
```bash
brew install --cask lanmount
```

### 🔍 Verification

```bash
# Verify notarization
spctl -a -vv -t install LanMount-1.0.0.dmg
```

### 📋 Requirements

- macOS 12.0 (Monterey) or later
- 50 MB disk space

### 🙏 Contributors

Thanks to all contributors!

---

**Full Changelog**: https://github.com/user/LanMount/compare/v0.9.0...v1.0.0
```

### Hotfix Release

For critical bugs in production:

**Step 1: Create Hotfix Branch**

```bash
# From main/master
git checkout -b hotfix/1.0.1

# Fix the bug
# ...

# Commit
git commit -m "Fix critical bug in mount logic"
```

**Step 2: Quick Release**

```bash
# Test build first
fastlane test_build version:1.0.1

# Full release
fastlane release version:1.0.1
```

**Step 3: Merge and Tag**

```bash
# Merge to main
git checkout main
git merge hotfix/1.0.1

# Tag and push
git tag v1.0.1
git push origin main v1.0.1
```

### Rollback Procedure

If a release has critical issues:

**Step 1: Mark as Pre-release**

1. Go to GitHub Releases
2. Edit the release
3. Check "This is a pre-release"
4. Add warning to description

**Step 2: Communicate**

- Post issue on GitHub
- Update README with warning
- Notify users via social media

**Step 3: Fix and Re-release**

```bash
# Fix issues
# ...

# Release patch version
fastlane release version:1.0.1
git tag v1.0.1
git push origin v1.0.1
```

### Distribution Channels

#### 1. GitHub Releases

**Pros:**
- Direct download
- Full control
- Version history

**Setup:**
- Automatic with GitHub Actions
- Manual upload also supported

#### 2. Homebrew Cask

**Pros:**
- Easy installation
- Automatic updates
- Package management

**Setup:**

```bash
# Create Cask file
cat > Casks/lanmount.rb << 'EOF'
cask "lanmount" do
  version "1.0.0"
  sha256 "..."
  
  url "https://github.com/user/LanMount/releases/download/v#{version}/LanMount-#{version}.dmg"
  name "LanMount"
  desc "SMB network drive manager for macOS"
  homepage "https://github.com/user/LanMount"
  
  app "LanMount.app"
end
EOF

# Submit to homebrew-cask
# Or maintain your own tap
```

#### 3. Direct Website

Host DMG on your own website:

```html
<a href="https://yoursite.com/downloads/LanMount-1.0.0.dmg">
  Download LanMount v1.0.0
</a>
```

### Post-Release Tasks

#### 1. Update Documentation

- [ ] Update README.md with new version
- [ ] Update screenshots if UI changed
- [ ] Update installation instructions
- [ ] Update CHANGELOG.md

#### 2. Announce Release

**GitHub:**
- Create release with notes
- Close related issues
- Update project board

**Social Media:**
- Twitter/X announcement
- Reddit post (if applicable)
- Blog post (if you have one)

**Community:**
- Notify beta testers
- Thank contributors
- Request feedback

#### 3. Monitor

**First 24 Hours:**
- Watch for crash reports
- Monitor GitHub issues
- Check social media mentions
- Respond to questions

**First Week:**
- Collect feedback
- Plan hotfixes if needed
- Update documentation based on questions

#### 4. Metrics

Track:
- Download count
- Installation success rate
- Crash reports
- User feedback
- GitHub stars/forks

### Troubleshooting Releases

#### Build Fails

```bash
# Clean everything
fastlane clean
rm -rf ~/Library/Developer/Xcode/DerivedData

# Rebuild
fastlane test_build version:X.X.X
```

#### Notarization Fails

```bash
# Check notarization log
xcrun notarytool log <submission-id> \
  --apple-id "your@email.com" \
  --team-id "ABCDE12345" \
  --password "xxxx-xxxx-xxxx-xxxx"

# Common issues:
# - Hardened runtime not enabled
# - Missing entitlements
# - Unsigned frameworks
```

#### DMG Won't Open

```bash
# Verify DMG
hdiutil verify build/LanMount-X.X.X.dmg

# Recreate if corrupted
fastlane create_dmg version:X.X.X
```

#### Users Can't Install

**"App is damaged":**
- Notarization not stapled
- Run: `xcrun stapler staple LanMount-X.X.X.dmg`

**"App can't be opened":**
- Not notarized
- User needs to right-click → Open

### Best Practices

1. **Test Thoroughly**
   - Test on clean macOS installation
   - Test all major features
   - Test upgrade from previous version

2. **Version Consistently**
   - Follow semantic versioning
   - Update all version references
   - Keep CHANGELOG.md current

3. **Communicate Clearly**
   - Write detailed release notes
   - Highlight breaking changes
   - Provide upgrade instructions

4. **Automate When Possible**
   - Use GitHub Actions for releases
   - Automate testing
   - Automate distribution

5. **Monitor and Respond**
   - Watch for issues
   - Respond quickly to bugs
   - Plan hotfixes when needed

### Resources

- [Semantic Versioning](https://semver.org/)
- [Keep a Changelog](https://keepachangelog.com/)
- [GitHub Releases](https://docs.github.com/en/repositories/releasing-projects-on-github)
- [Fastlane Guide](FASTLANE_GUIDE.md)
- [Code Signing Guide](CODE_SIGNING.md)

---

## 中文

### 概述

本指南涵盖 LanMount 的完整发布流程，从准备到分发。

### 发布检查清单

#### 发布前

- [ ] 所有功能已测试且正常工作
- [ ] 没有严重 bug
- [ ] 文档已更新
- [ ] CHANGELOG.md 已更新
- [ ] 版本号已确定
- [ ] 代码签名证书有效
- [ ] .env 文件已配置

#### 发布中

- [ ] 构建成功
- [ ] DMG 已创建
- [ ] 公证成功
- [ ] 在干净的 macOS 上手动测试
- [ ] GitHub Release 已创建
- [ ] 发布说明已发布

#### 发布后

- [ ] Homebrew Cask 已更新（如适用）
- [ ] 社交媒体公告
- [ ] 监控问题
- [ ] 回应用户反馈

### 发布类型

#### 1. 开发版本 (X.X.X-dev)

仅供内部测试。

```bash
fastlane test_build version:1.0.0-dev
```

**特点：**
- 无公证
- 快速构建（2-5 分钟）
- 不用于分发

#### 2. Beta 版本 (X.X.X-beta)

供选定用户进行外部测试。

```bash
fastlane release version:1.0.0-beta
```

**特点：**
- 完整公证
- 标记为预发布
- 有限分发
- 收集反馈

#### 3. 候选版本 (X.X.X-rc)

生产前的最终测试。

```bash
fastlane release version:1.0.0-rc1
```

**特点：**
- 完整公证
- 功能完整
- 仅修复 bug
- 广泛测试

#### 4. 生产版本 (X.X.X)

官方公开发布。

```bash
fastlane release version:1.0.0
```

**特点：**
- 完整公证
- 公开分发
- 稳定且经过测试
- 完整文档

### 版本策略

遵循[语义化版本](https://semver.org/lang/zh-CN/)：

**格式：** 主版本.次版本.修订号

#### 主版本 (X.0.0)

需要用户操作的破坏性更改。

**示例：**
- 完全重新设计 UI
- 删除功能
- 更改数据格式
- macOS 版本要求变更

**递增：** `1.0.0` → `2.0.0`

#### 次版本 (0.X.0)

新功能，向后兼容。

**示例：**
- 新的挂载选项
- 额外设置
- 性能改进
- 新集成

**递增：** `1.0.0` → `1.1.0`

#### 修订号 (0.0.X)

Bug 修复，向后兼容。

**示例：**
- Bug 修复
- 安全补丁
- 小的 UI 调整
- 文档更新

**递增：** `1.0.0` → `1.0.1`

### 发布流程

#### 方法 1：本地发布（Fastlane）

**步骤 1：准备**

```bash
cd LanMount

# 更新 CHANGELOG.md 中的版本
nano CHANGELOG.md

# 提交更改
git add .
git commit -m "Prepare for v1.0.0 release"
git push
```

**步骤 2：构建和公证**

```bash
# 完整发布
fastlane release version:1.0.0
```

这将：
1. ✅ 运行测试
2. ✅ 更新版本号
3. ✅ 构建应用程序
4. ✅ 创建 DMG
5. ✅ 提交公证
6. ✅ 等待批准（10-30 分钟）
7. ✅ 装订票据
8. ✅ 验证公证

**步骤 3：测试 DMG**

```bash
# 挂载 DMG
open build/LanMount-1.0.0.dmg

# 验证公证
spctl -a -vv -t install build/LanMount-1.0.0.dmg

# 测试安装
# 拖到应用程序，启动，测试功能
```

**步骤 4：创建 GitHub Release**

```bash
# 创建并推送 tag
git tag v1.0.0
git push origin v1.0.0

# 或在 GitHub 上手动创建 release
```

**步骤 5：上传 DMG**

1. 访问 GitHub Releases
2. 点击 "Draft a new release"
3. 选择 tag `v1.0.0`
4. 上传 `LanMount-1.0.0.dmg`
5. 添加发布说明
6. 发布 release

#### 方法 2：自动发布（GitHub Actions）

**步骤 1：准备**

```bash
cd LanMount

# 更新 CHANGELOG.md
nano CHANGELOG.md

# 提交并推送
git add .
git commit -m "Prepare for v1.0.0 release"
git push
```

**步骤 2：创建并推送 Tag**

```bash
# 创建 tag
git tag v1.0.0

# 推送 tag（触发 workflow）
git push origin v1.0.0
```

**步骤 3：监控 Workflow**

1. 访问 GitHub Actions 标签
2. 观察 "Release" workflow
3. 等待完成（15-45 分钟）

**步骤 4：验证 Release**

1. 检查 GitHub Releases 页面
2. 下载并测试 DMG
3. 验证发布说明

### 发布说明模板

```markdown
## LanMount v1.0.0

### 🎉 新功能

- 功能 1 描述
- 功能 2 描述

### 🐛 Bug 修复

- 修复问题 #123：描述
- 修复崩溃当...

### 🔧 改进

- 改进了...的性能
- 更新了...的 UI

### 📚 文档

- 添加了...的指南
- 更新了 README

### 🔒 安全

- 修复了安全问题...
- 更新了依赖

### ⚠️ 破坏性更改

- 更改了...的行为
- 删除了已弃用的...

### 📦 安装

**直接下载：**
```bash
# 下载 DMG
curl -LO https://github.com/user/LanMount/releases/download/v1.0.0/LanMount-1.0.0.dmg

# 验证校验和
shasum -a 256 LanMount-1.0.0.dmg
```

**Homebrew：**
```bash
brew install --cask lanmount
```

### 🔍 验证

```bash
# 验证公证
spctl -a -vv -t install LanMount-1.0.0.dmg
```

### 📋 系统要求

- macOS 12.0 (Monterey) 或更高版本
- 50 MB 磁盘空间

### 🙏 贡献者

感谢所有贡献者！

---

**完整更新日志**: https://github.com/user/LanMount/compare/v0.9.0...v1.0.0
```

### 热修复发布

对于生产中的严重 bug：

**步骤 1：创建热修复分支**

```bash
# 从 main/master
git checkout -b hotfix/1.0.1

# 修复 bug
# ...

# 提交
git commit -m "Fix critical bug in mount logic"
```

**步骤 2：快速发布**

```bash
# 先测试构建
fastlane test_build version:1.0.1

# 完整发布
fastlane release version:1.0.1
```

**步骤 3：合并和标记**

```bash
# 合并到 main
git checkout main
git merge hotfix/1.0.1

# 标记并推送
git tag v1.0.1
git push origin main v1.0.1
```

### 回滚程序

如果发布有严重问题：

**步骤 1：标记为预发布**

1. 访问 GitHub Releases
2. 编辑 release
3. 勾选 "This is a pre-release"
4. 在描述中添加警告

**步骤 2：沟通**

- 在 GitHub 上发布问题
- 在 README 中添加警告
- 通过社交媒体通知用户

**步骤 3：修复并重新发布**

```bash
# 修复问题
# ...

# 发布补丁版本
fastlane release version:1.0.1
git tag v1.0.1
git push origin v1.0.1
```

### 分发渠道

#### 1. GitHub Releases

**优点：**
- 直接下载
- 完全控制
- 版本历史

**设置：**
- GitHub Actions 自动
- 也支持手动上传

#### 2. Homebrew Cask

**优点：**
- 简单安装
- 自动更新
- 包管理

**设置：**

```bash
# 创建 Cask 文件
cat > Casks/lanmount.rb << 'EOF'
cask "lanmount" do
  version "1.0.0"
  sha256 "..."
  
  url "https://github.com/user/LanMount/releases/download/v#{version}/LanMount-#{version}.dmg"
  name "LanMount"
  desc "SMB network drive manager for macOS"
  homepage "https://github.com/user/LanMount"
  
  app "LanMount.app"
end
EOF

# 提交到 homebrew-cask
# 或维护自己的 tap
```

#### 3. 直接网站

在自己的网站上托管 DMG：

```html
<a href="https://yoursite.com/downloads/LanMount-1.0.0.dmg">
  下载 LanMount v1.0.0
</a>
```

### 发布后任务

#### 1. 更新文档

- [ ] 更新 README.md 的新版本
- [ ] 如果 UI 更改，更新截图
- [ ] 更新安装说明
- [ ] 更新 CHANGELOG.md

#### 2. 宣布发布

**GitHub：**
- 创建带说明的 release
- 关闭相关问题
- 更新项目看板

**社交媒体：**
- Twitter/X 公告
- Reddit 帖子（如适用）
- 博客文章（如果有）

**社区：**
- 通知 beta 测试者
- 感谢贡献者
- 请求反馈

#### 3. 监控

**前 24 小时：**
- 关注崩溃报告
- 监控 GitHub 问题
- 检查社交媒体提及
- 回答问题

**第一周：**
- 收集反馈
- 如需要计划热修复
- 根据问题更新文档

#### 4. 指标

跟踪：
- 下载次数
- 安装成功率
- 崩溃报告
- 用户反馈
- GitHub stars/forks

### 发布故障排除

#### 构建失败

```bash
# 清理所有
fastlane clean
rm -rf ~/Library/Developer/Xcode/DerivedData

# 重新构建
fastlane test_build version:X.X.X
```

#### 公证失败

```bash
# 检查公证日志
xcrun notarytool log <submission-id> \
  --apple-id "your@email.com" \
  --team-id "ABCDE12345" \
  --password "xxxx-xxxx-xxxx-xxxx"

# 常见问题：
# - 未启用强化运行时
# - 缺少权限
# - 未签名的框架
```

#### DMG 无法打开

```bash
# 验证 DMG
hdiutil verify build/LanMount-X.X.X.dmg

# 如果损坏则重新创建
fastlane create_dmg version:X.X.X
```

#### 用户无法安装

**"应用已损坏"：**
- 公证未装订
- 运行：`xcrun stapler staple LanMount-X.X.X.dmg`

**"无法打开应用"：**
- 未公证
- 用户需要右键点击 → 打开

### 最佳实践

1. **彻底测试**
   - 在干净的 macOS 安装上测试
   - 测试所有主要功能
   - 测试从以前版本升级

2. **一致的版本控制**
   - 遵循语义化版本
   - 更新所有版本引用
   - 保持 CHANGELOG.md 最新

3. **清晰沟通**
   - 编写详细的发布说明
   - 突出破坏性更改
   - 提供升级说明

4. **尽可能自动化**
   - 使用 GitHub Actions 发布
   - 自动化测试
   - 自动化分发

5. **监控和响应**
   - 关注问题
   - 快速响应 bug
   - 需要时计划热修复

### 资源

- [语义化版本](https://semver.org/lang/zh-CN/)
- [Keep a Changelog](https://keepachangelog.com/)
- [GitHub Releases](https://docs.github.com/en/repositories/releasing-projects-on-github)
- [Fastlane 指南](FASTLANE_GUIDE.md)
- [代码签名指南](CODE_SIGNING.md)

---

**提示 | Tip:** 首次发布建议使用 beta 版本进行测试，确认一切正常后再发布正式版本。
