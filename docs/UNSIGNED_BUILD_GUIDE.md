# 未签名构建指南

本指南说明如何使用 GitHub Actions 构建未签名的 LanMount DMG，无需 Apple 开发者账号或证书。

## 为什么需要未签名构建？

- **无需开发者账号**：不需要付费的 Apple Developer Program 会员资格
- **快速测试**：跳过签名和公证流程，加快构建速度
- **开源友好**：任何人都可以 fork 项目并构建自己的版本
- **学习和开发**：适合学习 macOS 应用开发

## 使用方法

### 1. 通过 GitHub Actions 界面

1. 访问你的 GitHub 仓库
2. 点击 **Actions** 标签
3. 在左侧选择 **Release** workflow
4. 点击右上角的 **Run workflow** 按钮
5. 填写参数：
   - **Version**: 输入版本号（例如：`1.0.0`）
   - **Mark as pre-release**: 是否标记为预发布版本
   - **Skip code signing and notarization**: ✅ **勾选此项**
   - **Skip notarization only**: 不勾选（此选项用于已签名但不公证的构建）
6. 点击绿色的 **Run workflow** 按钮

### 2. 等待构建完成

- 构建过程大约需要 5-10 分钟
- 你可以点击运行中的 workflow 查看实时日志
- 构建完成后会自动创建 GitHub Release

### 3. 下载和安装

1. 构建完成后，访问仓库的 **Releases** 页面
2. 找到刚创建的版本（例如：`v1.0.0`）
3. 下载 `LanMount-1.0.0.dmg` 文件
4. 打开 DMG 文件
5. 将 LanMount 拖到 Applications 文件夹

### 4. 首次运行

由于应用未签名，macOS Gatekeeper 会阻止直接运行：

1. 打开 **Finder**，进入 **Applications** 文件夹
2. 找到 **LanMount** 应用
3. **右键点击**（或 Control + 点击）应用图标
4. 选择 **打开**
5. 在弹出的对话框中点击 **打开**
6. 应用现在可以正常运行了

之后就可以像普通应用一样启动 LanMount。

## 安全说明

### 未签名构建的限制

- ⚠️ macOS 会显示"无法验证开发者"警告
- ⚠️ 需要手动绕过 Gatekeeper（右键打开）
- ⚠️ 某些系统功能可能受限
- ⚠️ 不适合分发给普通用户

### 适用场景

✅ 个人使用和测试  
✅ 开发和调试  
✅ 学习和研究  
✅ Fork 项目的自定义构建  

❌ 不适合公开分发  
❌ 不适合企业环境  
❌ 不适合 Mac App Store  

## 构建选项对比

| 选项 | 代码签名 | 公证 | 需要证书 | 适用场景 |
|------|---------|------|---------|---------|
| 默认 | ✅ | ✅ | 是 | 公开发布 |
| skip_notarization | ✅ | ❌ | 是 | 快速测试 |
| skip_signing | ❌ | ❌ | 否 | 个人构建 |

## 常见问题

### Q: 为什么需要右键打开？

A: macOS Gatekeeper 默认阻止未签名的应用。右键打开是 Apple 提供的官方绕过方式。

### Q: 这样安全吗？

A: 如果你信任源代码（可以在 GitHub 上查看），那么是安全的。但要注意只从可信的源下载。

### Q: 可以分发给其他人吗？

A: 技术上可以，但不推荐。其他用户也需要右键打开，体验不好。建议使用签名版本进行分发。

### Q: 如何升级到签名版本？

A: 获取 Apple Developer 账号后，配置 GitHub Secrets（见主文档），然后不勾选 skip_signing 选项即可。

## 相关文档

- [完整发布指南](RELEASE_GUIDE.md) - 包含签名和公证的完整流程
- [代码签名指南](CODE_SIGNING.md) - 如何配置证书和签名
- [GitHub Actions 说明](GITHUB_ACTIONS_SUMMARY.md) - CI/CD 配置详解

## 技术细节

未签名构建使用以下命令：

```bash
xcodebuild \
  -project LanMount.xcodeproj \
  -scheme LanMount \
  -configuration Release \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  clean build
```

然后使用 `hdiutil` 创建 DMG：

```bash
hdiutil create -size 200m -fs HFS+ -volname "LanMount" temp.dmg
hdiutil attach temp.dmg
cp -R LanMount.app /Volumes/LanMount/
ln -s /Applications /Volumes/LanMount/Applications
hdiutil detach /Volumes/LanMount
hdiutil convert temp.dmg -format UDZO -o LanMount-1.0.0.dmg
```

## 支持

如有问题，请在 GitHub Issues 中提问。
