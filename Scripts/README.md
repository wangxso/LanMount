# 发布脚本使用指南

## 快速开始

### 1. 配置环境变量

首次使用需要配置 Apple Developer 信息：

```bash
# 复制模板文件
cp .env.example .env

# 编辑 .env 文件
nano .env  # 或使用你喜欢的编辑器
```

在 `.env` 文件中填入以下信息：

```bash
# Apple ID（用于公证）
APPLE_ID=your@email.com

# Team ID（在 Apple Developer 账号中查看）
TEAM_ID=YOUR_TEAM_ID

# App-Specific Password（从 appleid.apple.com 生成）
APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx

# 钥匙串配置名称
KEYCHAIN_PROFILE=AC_PASSWORD
```

#### 如何获取 App-Specific Password：

1. 访问 https://appleid.apple.com
2. 登录你的 Apple ID
3. 进入 **安全** -> **App 专用密码**
4. 点击 **生成密码**
5. 输入标签（例如："LanMount Notarization"）
6. 复制生成的密码到 `.env` 文件

### 2. 一键发布

配置完成后，运行：

```bash
# 完整发布流程（包括公证）
./Scripts/quick-release.sh 1.0.0

# 本地测试（跳过公证）
./Scripts/quick-release.sh 1.0.0 --skip-notarize

# Debug 构建（用于开发测试）
./Scripts/quick-release.sh 1.0.0 --debug --skip-notarize
```

## 脚本说明

### quick-release.sh（推荐）

**一键发布脚本** - 从 `.env` 文件读取配置，自动完成所有步骤。

```bash
./Scripts/quick-release.sh <版本号> [选项]

参数：
  版本号          版本号，例如：1.0.0

选项：
  --skip-notarize  跳过公证（用于本地测试）
  --skip-tests     跳过测试
  --debug          使用 Debug 配置构建
  -h, --help       显示帮助信息

示例：
  ./Scripts/quick-release.sh 1.0.0
  ./Scripts/quick-release.sh 1.0.0 --skip-notarize
  ./Scripts/quick-release.sh 1.0.0 --debug --skip-tests
```

**执行步骤：**
1. 加载 `.env` 配置
2. 配置公证凭证
3. 运行测试
4. 清理构建目录
5. 构建应用
6. 验证代码签名
7. 创建 DMG
8. 提交公证（可选）
9. 装订公证票据（可选）
10. 验证公证（可选）

### prepare-release.sh

**完整发布脚本** - 功能更全面，支持更多选项。

```bash
./Scripts/prepare-release.sh -v <版本号> [选项]

选项：
  -v, --version VERSION   版本号（必需）
  -n, --notes FILE        发布说明文件路径
  -s, --skip-build        跳过构建
  -t, --skip-tests        跳过测试
  --skip-notarize         跳过公证
  --dry-run               预览操作
  -h, --help              显示帮助

示例：
  ./Scripts/prepare-release.sh -v 1.0.0
  ./Scripts/prepare-release.sh -v 1.0.0 --skip-notarize
```

### build-dmg.sh

**创建 DMG** - 单独创建 DMG 安装包。

```bash
./Scripts/build-dmg.sh [选项]

选项：
  -a, --app-path PATH     .app 路径
  -o, --output PATH       输出 DMG 路径
  -v, --volume-name NAME  卷名称
  -h, --help              显示帮助

示例：
  ./Scripts/build-dmg.sh
  ./Scripts/build-dmg.sh --app-path build/Debug/LanMount.app
```

### notarize-app.sh

**提交公证** - 将 DMG 提交到 Apple 进行公证。

```bash
./Scripts/notarize-app.sh [选项] <dmg-path>

选项：
  -p, --profile NAME      钥匙串配置名称
  -w, --wait              等待完成
  -t, --timeout SECONDS   超时时间
  -h, --help              显示帮助

示例：
  ./Scripts/notarize-app.sh build/LanMount.dmg
```

### verify-codesign.sh

**验证代码签名** - 检查应用的代码签名是否有效。

```bash
./Scripts/verify-codesign.sh <app-path>

示例：
  ./Scripts/verify-codesign.sh build/Release/LanMount.app
```

### staple-ticket.sh

**装订公证票据** - 将公证票据附加到 DMG。

```bash
./Scripts/staple-ticket.sh [选项] <dmg-or-app-path>

选项：
  -v, --verify    验证装订
  -h, --help      显示帮助

示例：
  ./Scripts/staple-ticket.sh build/LanMount.dmg
```

### verify-notarization.sh

**验证公证** - 检查公证状态和 Gatekeeper 接受情况。

```bash
./Scripts/verify-notarization.sh [选项] [dmg-or-app-path]

选项：
  -s, --submission-id ID  检查特定提交状态
  -p, --profile NAME      钥匙串配置名称
  -l, --log               显示详细日志
  -h, --help              显示帮助

示例：
  ./Scripts/verify-notarization.sh build/LanMount.dmg
  ./Scripts/verify-notarization.sh --submission-id <id> --log
```

## 使用场景

### 场景 1：本地开发测试

不需要代码签名和公证：

```bash
# 使用 Debug 配置，跳过公证和测试
./Scripts/quick-release.sh 1.0.0-dev --debug --skip-notarize --skip-tests
```

### 场景 2：内部测试版本

需要代码签名但不公证：

```bash
# 使用 Release 配置，跳过公证
./Scripts/quick-release.sh 1.0.0-beta --skip-notarize
```

### 场景 3：正式发布

完整流程，包括公证：

```bash
# 完整发布流程
./Scripts/quick-release.sh 1.0.0
```

### 场景 4：仅创建 DMG

已有构建好的 .app，只需创建 DMG：

```bash
./Scripts/build-dmg.sh \
    --app-path build/Release/LanMount.app \
    --output build/LanMount-1.0.0.dmg
```

### 场景 5：重新公证

DMG 已创建，需要重新公证：

```bash
# 提交公证
./Scripts/notarize-app.sh build/LanMount.dmg

# 装订票据
./Scripts/staple-ticket.sh build/LanMount.dmg

# 验证
./Scripts/verify-notarization.sh build/LanMount.dmg
```

## 常见问题

### 1. 找不到 .env 文件

```bash
错误: 未找到 .env 文件
```

**解决：**
```bash
cp .env.example .env
nano .env  # 填入配置
```

### 2. 公证凭证配置失败

```bash
错误: 公证凭证配置失败
```

**解决：**
- 检查 Apple ID 是否正确
- 确认 Team ID 正确（在 Apple Developer 账号中查看）
- 确认 App-Specific Password 有效
- 重新生成 App-Specific Password

### 3. 代码签名失败

```bash
错误: 代码签名验证失败
```

**解决：**
- 确保已安装 Developer ID 证书
- 在 Xcode 中配置 Team
- 或使用 `--skip-notarize` 跳过签名（仅本地测试）

### 4. 公证超时

```bash
错误: 公证超时
```

**解决：**
- 公证通常需要 5-15 分钟，请耐心等待
- 可以稍后使用以下命令检查状态：
  ```bash
  ./Scripts/verify-notarization.sh --submission-id <id>
  ```

### 5. DMG 无法打开

```bash
"LanMount.dmg is damaged"
```

**解决：**
- 本地测试时，右键点击 -> 打开
- 或完成公证流程
- 或移除隔离属性：
  ```bash
  xattr -cr LanMount.app
  ```

## 环境变量说明

| 变量 | 必需 | 说明 |
|------|------|------|
| `APPLE_ID` | 是* | Apple ID 邮箱 |
| `TEAM_ID` | 是* | Apple Developer Team ID |
| `APP_SPECIFIC_PASSWORD` | 是* | App 专用密码 |
| `KEYCHAIN_PROFILE` | 否 | 钥匙串配置名称（默认：AC_PASSWORD） |
| `CODE_SIGN_IDENTITY` | 否 | 代码签名身份（默认：Developer ID Application） |
| `APP_NAME` | 否 | 应用名称（默认：LanMount） |
| `BUNDLE_ID` | 否 | Bundle ID（默认：com.lanmount.app） |

\* 仅在需要公证时必需，使用 `--skip-notarize` 时可以不配置

## 安全提示

⚠️ **重要：** `.env` 文件包含敏感信息，请勿提交到版本控制系统！

`.gitignore` 已配置忽略 `.env` 文件，但请确保：

1. 不要将 `.env` 文件分享给他人
2. 不要将 `.env` 文件提交到 Git
3. 定期更新 App-Specific Password
4. 使用完毕后可以删除钥匙串中的凭证：
   ```bash
   xcrun notarytool history --keychain-profile AC_PASSWORD
   # 然后在钥匙串访问中删除相关项目
   ```

## 更多信息

- 完整发布指南：查看 `../RELEASE_GUIDE.md`
- 代码签名配置：查看 `../CODE_SIGNING.md`
- 故障排除：查看 `../TROUBLESHOOTING.md`
