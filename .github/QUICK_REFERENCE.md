# GitHub Actions 快速参考

## 🚀 快速发布

### 推送 Tag 自动发布
```bash
git tag v1.0.0
git push origin v1.0.0
```

### 手动触发
1. GitHub → Actions → Release → Run workflow
2. 输入版本号
3. 点击 Run

## 🔐 必需的 Secrets

| Secret | 说明 |
|--------|------|
| `APPLE_DEVELOPER_CERTIFICATE_P12_BASE64` | 证书 Base64 |
| `APPLE_DEVELOPER_CERTIFICATE_PASSWORD` | 证书密码 |
| `APPLE_ID` | Apple ID 邮箱 |
| `APPLE_TEAM_ID` | 10 位 Team ID |
| `APPLE_APP_SPECIFIC_PASSWORD` | App 专用密码 |

## 📝 常用命令

### 导出证书
```bash
# 从钥匙串导出 .p12
# 然后转换为 Base64
base64 -i certificate.p12 -o certificate.p12.base64
cat certificate.p12.base64 | pbcopy
```

### 查看 Team ID
```bash
# 访问 https://developer.apple.com/account
# Membership → Team ID
```

### 生成 App-specific Password
```bash
# 访问 https://appleid.apple.com
# 安全 → App 专用密码 → 生成
```

## 🎯 Workflow 参数

### 手动触发参数

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `version` | string | 必填 | 版本号（如 1.0.0） |
| `prerelease` | boolean | false | 标记为预发布 |
| `skip_notarization` | boolean | false | 跳过公证（测试用） |

### Tag 触发

- 格式：`v*`（如 `v1.0.0`）
- 自动提取版本号
- 默认为正式发布
- 不跳过公证

## ⏱️ 执行时间

| 步骤 | 时间 |
|------|------|
| 环境准备 | 2-3 分钟 |
| 构建 | 3-5 分钟 |
| 公证 | 10-30 分钟 |
| 发布 | 1-2 分钟 |
| **总计** | **15-40 分钟** |

## 📦 输出

### GitHub Release
- Tag: `v1.0.0`
- Title: `LanMount v1.0.0`
- Assets: `LanMount-1.0.0.dmg`
- Release Notes: 自动生成

### Release Notes 包含
- 下载链接
- 系统要求
- 安全信息
- 安装说明
- Homebrew 命令
- SHA256 校验和

## 🐛 常见问题

### 证书导入失败
```
Error: SecKeychainItemImport failed
```
**解决：** 检查 Base64 编码和密码是否正确

### Team ID 错误
```
Error: Invalid team ID
```
**解决：** 确保是 10 位字符的 Team ID，不是名字

### 公证超时
```
Error: Timeout waiting for notarization
```
**解决：** Apple 服务器繁忙，重试即可

### Fastlane 找不到
```
bundle: command not found
```
**解决：** 确保 Gemfile 已提交到仓库

## 🔄 本地 vs GitHub Actions

| 功能 | 本地 | GitHub Actions |
|------|------|----------------|
| 构建 | `fastlane release` | 自动 |
| 环境 | 需要配置 | 自动配置 |
| 公证 | 手动等待 | 自动等待 |
| 发布 | 手动上传 | 自动创建 |
| 速度 | 取决于本地 | 稳定 |

## 📚 相关文档

- [详细配置指南](GITHUB_ACTIONS_SETUP.md)
- [Workflow 流程图](WORKFLOW_DIAGRAM.md)
- [Fastlane 指南](../FASTLANE_GUIDE.md)

## 💡 最佳实践

### 首次配置
1. ✅ 先配置所有 Secrets
2. ✅ 手动触发测试构建（跳过公证）
3. ✅ 验证构建成功
4. ✅ 测试完整流程（包含公证）
5. ✅ 正式发布

### 日常使用
1. ✅ 开发完成后创建 tag
2. ✅ 推送 tag 触发自动发布
3. ✅ 等待 workflow 完成
4. ✅ 验证 Release 创建成功
5. ✅ 测试下载的 DMG

### 版本号规范
- 正式版：`v1.0.0`
- Beta 版：`v1.0.0-beta`
- RC 版：`v1.0.0-rc.1`
- 测试版：`v1.0.0-test`

## 🎯 快速检查清单

发布前检查：

- [ ] 所有 Secrets 已配置
- [ ] 证书未过期
- [ ] Team ID 正确（10 位字符）
- [ ] App-specific password 有效
- [ ] 代码已提交并推送
- [ ] CHANGELOG 已更新
- [ ] 版本号符合规范

发布后验证：

- [ ] GitHub Release 已创建
- [ ] DMG 文件可下载
- [ ] SHA256 正确
- [ ] DMG 可以安装
- [ ] 应用可以启动
- [ ] 公证状态正确

## 🔗 快速链接

- [GitHub Actions](../../actions)
- [Releases](../../releases)
- [Settings → Secrets](../../settings/secrets/actions)
- [Apple Developer](https://developer.apple.com/account)
- [Apple ID](https://appleid.apple.com)

---

**提示：** 保存此页面以便快速参考！
