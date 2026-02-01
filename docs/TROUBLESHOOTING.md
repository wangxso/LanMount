# Troubleshooting Guide | 故障排除指南

[English](#english) | [中文](#中文)

---

## English

### Build Issues

#### Problem: Xcode Build Failed

**Symptoms:**
```
Error: xcodebuild failed with exit code 65
```

**Solutions:**

1. **Clean build folder**
   ```bash
   fastlane clean
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```

2. **Check Xcode version**
   ```bash
   xcodebuild -version
   # Should be 15.0 or later
   ```

3. **Open in Xcode and build manually**
   ```bash
   open LanMount.xcodeproj
   # Product → Clean Build Folder
   # Product → Build
   ```

4. **Check for syntax errors**
   - Look for red errors in Xcode
   - Fix any Swift compilation errors

#### Problem: Scheme Not Found

**Symptoms:**
```
Error: Scheme 'LanMount' not found
```

**Solutions:**

1. **Verify scheme exists**
   ```bash
   xcodebuild -list -project LanMount.xcodeproj
   ```

2. **Make scheme shared**
   - Open Xcode
   - Product → Scheme → Manage Schemes
   - Check "Shared" for LanMount scheme

#### Problem: Missing Dependencies

**Symptoms:**
```
Error: No such module 'SomeModule'
```

**Solutions:**

1. **Update Swift Package Manager**
   ```bash
   # In Xcode
   # File → Packages → Update to Latest Package Versions
   ```

2. **Reset package cache**
   ```bash
   rm -rf ~/Library/Caches/org.swift.swiftpm
   ```


### Code Signing Issues

#### Problem: Certificate Not Found

**Symptoms:**
```
Error: No code signing identity found
```

**Solutions:**

1. **List available certificates**
   ```bash
   security find-identity -v -p codesigning
   ```

2. **Install certificate**
   - Download from developer.apple.com
   - Double-click to install
   - Verify in Keychain Access

3. **Import certificate (CI/CD)**
   ```bash
   security import certificate.p12 \
     -k ~/Library/Keychains/login.keychain-db \
     -P "password" \
     -T /usr/bin/codesign
   ```

#### Problem: Certificate Expired

**Symptoms:**
```
Error: Certificate has expired
```

**Solutions:**

1. **Check expiration**
   ```bash
   security find-certificate -c "Developer ID Application" -p | \
     openssl x509 -noout -dates
   ```

2. **Renew certificate**
   - Visit developer.apple.com
   - Revoke old certificate
   - Create new certificate
   - Download and install

#### Problem: Wrong Certificate

**Symptoms:**
```
Error: No identity found matching 'Developer ID Application'
```

**Solutions:**

1. **Check certificate name**
   ```bash
   security find-identity -v -p codesigning
   ```

2. **Update CODE_SIGN_IDENTITY in .env**
   ```bash
   CODE_SIGN_IDENTITY=Developer ID Application: Your Name (TEAM_ID)
   ```


### Notarization Issues

#### Problem: Invalid Team ID

**Symptoms:**
```
Error: Invalid team ID
```

**Solutions:**

1. **Verify Team ID format**
   - Must be 10 characters (e.g., `ABCDE12345`)
   - NOT your name or email

2. **Find correct Team ID**
   - Visit https://developer.apple.com/account
   - Click "Membership"
   - Copy the 10-character Team ID

3. **Update .env file**
   ```bash
   TEAM_ID=ABCDE12345
   ```

#### Problem: Invalid Credentials

**Symptoms:**
```
Error: Invalid credentials
```

**Solutions:**

1. **Verify Apple ID**
   ```bash
   # Check .env file
   cat .env | grep APPLE_ID
   ```

2. **Generate new App-specific password**
   - Visit https://appleid.apple.com
   - Security → App-Specific Passwords
   - Generate new password
   - Update .env file

3. **Test credentials**
   ```bash
   xcrun notarytool history \
     --apple-id "your@email.com" \
     --team-id "ABCDE12345" \
     --password "xxxx-xxxx-xxxx-xxxx"
   ```

#### Problem: Notarization Timeout

**Symptoms:**
```
Error: Timeout waiting for notarization
```

**Solutions:**

1. **Check submission status**
   ```bash
   xcrun notarytool history \
     --apple-id "your@email.com" \
     --team-id "ABCDE12345" \
     --password "xxxx-xxxx-xxxx-xxxx"
   ```

2. **Wait and retry**
   - Apple's servers may be busy
   - Typical time: 10-30 minutes
   - Peak times may take longer

3. **Increase timeout**
   - Edit Fastfile
   - Add `--timeout 7200` to notarytool command

#### Problem: Notarization Rejected

**Symptoms:**
```
Error: Notarization failed with status: Invalid
```

**Solutions:**

1. **Get detailed log**
   ```bash
   xcrun notarytool log <submission-id> \
     --apple-id "your@email.com" \
     --team-id "ABCDE12345" \
     --password "xxxx-xxxx-xxxx-xxxx"
   ```

2. **Common issues:**
   - **Hardened runtime not enabled**
     - Enable in Xcode: Signing & Capabilities → Hardened Runtime
   
   - **Missing entitlements**
     - Add required entitlements in .entitlements file
   
   - **Unsigned frameworks**
     - Sign all embedded frameworks
     - Check with: `codesign -dv --verbose=4 LanMount.app`


### DMG Issues

#### Problem: DMG Creation Failed

**Symptoms:**
```
Error: hdiutil: create failed
```

**Solutions:**

1. **Check disk space**
   ```bash
   df -h
   ```

2. **Remove old DMG**
   ```bash
   rm -f build/LanMount-*.dmg
   ```

3. **Verify app exists**
   ```bash
   ls -la build/Release/LanMount.app
   ```

4. **Create manually**
   ```bash
   hdiutil create -volname LanMount \
     -srcfolder build/Release/LanMount.app \
     -ov -format UDZO \
     build/LanMount-1.0.0.dmg
   ```

#### Problem: DMG Won't Mount

**Symptoms:**
```
Error: resource busy
```

**Solutions:**

1. **Unmount existing volumes**
   ```bash
   hdiutil detach /Volumes/LanMount
   ```

2. **Verify DMG**
   ```bash
   hdiutil verify build/LanMount-1.0.0.dmg
   ```

3. **Recreate if corrupted**
   ```bash
   fastlane create_dmg version:1.0.0
   ```

#### Problem: "App is Damaged"

**Symptoms:**
User sees: "LanMount is damaged and can't be opened"

**Solutions:**

1. **Verify notarization**
   ```bash
   spctl -a -vv -t install build/LanMount-1.0.0.dmg
   ```

2. **Staple ticket**
   ```bash
   xcrun stapler staple build/LanMount-1.0.0.dmg
   ```

3. **Verify stapling**
   ```bash
   xcrun stapler validate build/LanMount-1.0.0.dmg
   ```


### Fastlane Issues

#### Problem: Fastlane Not Found

**Symptoms:**
```
bash: fastlane: command not found
```

**Solutions:**

1. **Install Fastlane**
   ```bash
   brew install fastlane
   ```

2. **Or use bundle**
   ```bash
   bundle install
   bundle exec fastlane
   ```

3. **Add to PATH**
   ```bash
   echo 'export PATH="$HOME/.fastlane/bin:$PATH"' >> ~/.zshrc
   source ~/.zshrc
   ```

#### Problem: Missing .env File

**Symptoms:**
```
Error: .env file not found
```

**Solutions:**

1. **Create from template**
   ```bash
   cp .env.example .env
   ```

2. **Fill in required values**
   ```bash
   nano .env
   ```

3. **Verify**
   ```bash
   cat .env
   ```

#### Problem: Lane Failed

**Symptoms:**
```
Error: Lane 'release' failed
```

**Solutions:**

1. **Check error message**
   - Read the full error output
   - Look for specific error codes

2. **Run with verbose**
   ```bash
   fastlane release version:1.0.0 --verbose
   ```

3. **Test individual lanes**
   ```bash
   fastlane build_app_release
   fastlane create_dmg version:1.0.0
   ```


### GitHub Actions Issues

#### Problem: Workflow Failed

**Symptoms:**
Workflow shows red X on GitHub Actions

**Solutions:**

1. **Check workflow logs**
   - Go to Actions tab
   - Click on failed workflow
   - Read error messages

2. **Verify secrets**
   - Settings → Secrets and variables → Actions
   - Ensure all required secrets are set:
     - `APPLE_DEVELOPER_CERTIFICATE_P12_BASE64`
     - `APPLE_DEVELOPER_CERTIFICATE_PASSWORD`
     - `APPLE_ID`
     - `APPLE_TEAM_ID`
     - `APPLE_APP_SPECIFIC_PASSWORD`

3. **Test locally first**
   ```bash
   fastlane test_build version:1.0.0-test
   ```

#### Problem: Certificate Import Failed

**Symptoms:**
```
Error: security: SecKeychainItemImport failed
```

**Solutions:**

1. **Verify Base64 encoding**
   ```bash
   # Re-encode certificate
   base64 -i certificate.p12 -o certificate.p12.base64
   ```

2. **Check password**
   - Verify `APPLE_DEVELOPER_CERTIFICATE_PASSWORD` is correct

3. **Recreate certificate**
   - Export from Keychain Access
   - Set new password
   - Re-encode and update secret

#### Problem: Tag Not Triggering Workflow

**Symptoms:**
Pushed tag but workflow didn't run

**Solutions:**

1. **Check tag format**
   ```bash
   # Must start with 'v'
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. **Verify workflow file**
   ```yaml
   on:
     push:
       tags:
         - 'v*'
   ```

3. **Check workflow is enabled**
   - Actions tab → Select workflow
   - Ensure not disabled


### Runtime Issues

#### Problem: App Won't Launch

**Symptoms:**
App crashes immediately on launch

**Solutions:**

1. **Check Console.app**
   - Open Console.app
   - Filter for "LanMount"
   - Look for crash logs

2. **Check entitlements**
   ```bash
   codesign -d --entitlements - build/Release/LanMount.app
   ```

3. **Verify code signature**
   ```bash
   codesign -dv --verbose=4 build/Release/LanMount.app
   ```

4. **Test unsigned build**
   - Build in Xcode without signing
   - If works, it's a signing issue

#### Problem: SMB Mount Fails

**Symptoms:**
```
Error: NetFS returned status 2 (ENOENT)
```

**Solutions:**

1. **Check network connectivity**
   ```bash
   ping 10.0.0.172
   ```

2. **Test in Finder**
   - Cmd+K
   - Enter smb://10.0.0.172/ShareName
   - If works, check credentials in app

3. **Check mount point**
   - Pass `nil` as mount point URL
   - Let NetFS choose location automatically

4. **Verify credentials**
   - Check username/password
   - Test with different credentials

#### Problem: Keychain Access Denied

**Symptoms:**
```
Error: User denied access to keychain
```

**Solutions:**

1. **Grant keychain access**
   - User must click "Allow" when prompted

2. **Add to keychain access list**
   - Open Keychain Access
   - Find credential
   - Access Control → Add LanMount.app

3. **Use app-specific keychain**
   - Create separate keychain for app
   - Don't use login keychain


### Environment Issues

#### Problem: Wrong macOS Version

**Symptoms:**
```
Error: Requires macOS 12.0 or later
```

**Solutions:**

1. **Check macOS version**
   ```bash
   sw_vers
   ```

2. **Update macOS**
   - System Settings → General → Software Update

3. **Lower deployment target** (if needed)
   - Edit project settings
   - Deployment Target → 11.0 or lower

#### Problem: Xcode Command Line Tools Missing

**Symptoms:**
```
Error: xcrun: error: invalid active developer path
```

**Solutions:**

1. **Install Command Line Tools**
   ```bash
   xcode-select --install
   ```

2. **Set Xcode path**
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app
   ```

3. **Verify**
   ```bash
   xcode-select -p
   ```

### Getting Help

#### Collect Diagnostic Information

Before asking for help, collect:

1. **System information**
   ```bash
   sw_vers
   xcodebuild -version
   fastlane --version
   ```

2. **Build logs**
   ```bash
   fastlane release version:1.0.0 --verbose > build.log 2>&1
   ```

3. **Notarization logs** (if applicable)
   ```bash
   xcrun notarytool log <submission-id> \
     --apple-id "your@email.com" \
     --team-id "ABCDE12345" \
     --password "xxxx-xxxx-xxxx-xxxx" \
     > notarization.log
   ```

4. **Code signing info**
   ```bash
   security find-identity -v -p codesigning > certificates.txt
   codesign -dv --verbose=4 build/Release/LanMount.app > codesign.txt 2>&1
   ```

#### Where to Get Help

1. **GitHub Issues**
   - https://github.com/your-username/LanMount/issues
   - Search existing issues first
   - Provide diagnostic information

2. **Documentation**
   - [Quick Start](QUICK_START.md)
   - [Fastlane Guide](FASTLANE_GUIDE.md)
   - [Code Signing Guide](CODE_SIGNING.md)
   - [Release Guide](RELEASE_GUIDE.md)

3. **Apple Developer Forums**
   - https://developer.apple.com/forums/
   - For code signing and notarization issues

4. **Fastlane Community**
   - https://github.com/fastlane/fastlane/discussions
   - For Fastlane-specific issues


---

## 中文

### 构建问题

#### 问题：Xcode 构建失败

**症状：**
```
Error: xcodebuild failed with exit code 65
```

**解决方案：**

1. **清理构建文件夹**
   ```bash
   fastlane clean
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```

2. **检查 Xcode 版本**
   ```bash
   xcodebuild -version
   # 应该是 15.0 或更高版本
   ```

3. **在 Xcode 中打开并手动构建**
   ```bash
   open LanMount.xcodeproj
   # Product → Clean Build Folder
   # Product → Build
   ```

4. **检查语法错误**
   - 查找 Xcode 中的红色错误
   - 修复任何 Swift 编译错误

#### 问题：找不到 Scheme

**症状：**
```
Error: Scheme 'LanMount' not found
```

**解决方案：**

1. **验证 scheme 存在**
   ```bash
   xcodebuild -list -project LanMount.xcodeproj
   ```

2. **使 scheme 共享**
   - 打开 Xcode
   - Product → Scheme → Manage Schemes
   - 勾选 LanMount scheme 的 "Shared"

#### 问题：缺少依赖

**症状：**
```
Error: No such module 'SomeModule'
```

**解决方案：**

1. **更新 Swift Package Manager**
   ```bash
   # 在 Xcode 中
   # File → Packages → Update to Latest Package Versions
   ```

2. **重置包缓存**
   ```bash
   rm -rf ~/Library/Caches/org.swift.swiftpm
   ```

### 代码签名问题

#### 问题：找不到证书

**症状：**
```
Error: No code signing identity found
```

**解决方案：**

1. **列出可用证书**
   ```bash
   security find-identity -v -p codesigning
   ```

2. **安装证书**
   - 从 developer.apple.com 下载
   - 双击安装
   - 在钥匙串访问中验证

3. **导入证书（CI/CD）**
   ```bash
   security import certificate.p12 \
     -k ~/Library/Keychains/login.keychain-db \
     -P "password" \
     -T /usr/bin/codesign
   ```

#### 问题：证书过期

**症状：**
```
Error: Certificate has expired
```

**解决方案：**

1. **检查过期时间**
   ```bash
   security find-certificate -c "Developer ID Application" -p | \
     openssl x509 -noout -dates
   ```

2. **续期证书**
   - 访问 developer.apple.com
   - 撤销旧证书
   - 创建新证书
   - 下载并安装

#### 问题：错误的证书

**症状：**
```
Error: No identity found matching 'Developer ID Application'
```

**解决方案：**

1. **检查证书名称**
   ```bash
   security find-identity -v -p codesigning
   ```

2. **更新 .env 中的 CODE_SIGN_IDENTITY**
   ```bash
   CODE_SIGN_IDENTITY=Developer ID Application: Your Name (TEAM_ID)
   ```


### 公证问题

#### 问题：无效的 Team ID

**症状：**
```
Error: Invalid team ID
```

**解决方案：**

1. **验证 Team ID 格式**
   - 必须是 10 位字符（例如：`ABCDE12345`）
   - 不是你的名字或邮箱

2. **查找正确的 Team ID**
   - 访问 https://developer.apple.com/account
   - 点击 "Membership"
   - 复制 10 位 Team ID

3. **更新 .env 文件**
   ```bash
   TEAM_ID=ABCDE12345
   ```

#### 问题：无效的凭证

**症状：**
```
Error: Invalid credentials
```

**解决方案：**

1. **验证 Apple ID**
   ```bash
   # 检查 .env 文件
   cat .env | grep APPLE_ID
   ```

2. **生成新的 App 专用密码**
   - 访问 https://appleid.apple.com
   - 安全 → App 专用密码
   - 生成新密码
   - 更新 .env 文件

3. **测试凭证**
   ```bash
   xcrun notarytool history \
     --apple-id "your@email.com" \
     --team-id "ABCDE12345" \
     --password "xxxx-xxxx-xxxx-xxxx"
   ```

#### 问题：公证超时

**症状：**
```
Error: Timeout waiting for notarization
```

**解决方案：**

1. **检查提交状态**
   ```bash
   xcrun notarytool history \
     --apple-id "your@email.com" \
     --team-id "ABCDE12345" \
     --password "xxxx-xxxx-xxxx-xxxx"
   ```

2. **等待并重试**
   - Apple 服务器可能繁忙
   - 典型时间：10-30 分钟
   - 高峰时段可能更长

3. **增加超时时间**
   - 编辑 Fastfile
   - 在 notarytool 命令中添加 `--timeout 7200`

#### 问题：公证被拒绝

**症状：**
```
Error: Notarization failed with status: Invalid
```

**解决方案：**

1. **获取详细日志**
   ```bash
   xcrun notarytool log <submission-id> \
     --apple-id "your@email.com" \
     --team-id "ABCDE12345" \
     --password "xxxx-xxxx-xxxx-xxxx"
   ```

2. **常见问题：**
   - **未启用强化运行时**
     - 在 Xcode 中启用：Signing & Capabilities → Hardened Runtime
   
   - **缺少权限**
     - 在 .entitlements 文件中添加所需权限
   
   - **未签名的框架**
     - 签名所有嵌入的框架
     - 检查：`codesign -dv --verbose=4 LanMount.app`

### DMG 问题

#### 问题：DMG 创建失败

**症状：**
```
Error: hdiutil: create failed
```

**解决方案：**

1. **检查磁盘空间**
   ```bash
   df -h
   ```

2. **删除旧的 DMG**
   ```bash
   rm -f build/LanMount-*.dmg
   ```

3. **验证应用存在**
   ```bash
   ls -la build/Release/LanMount.app
   ```

4. **手动创建**
   ```bash
   hdiutil create -volname LanMount \
     -srcfolder build/Release/LanMount.app \
     -ov -format UDZO \
     build/LanMount-1.0.0.dmg
   ```

#### 问题：DMG 无法挂载

**症状：**
```
Error: resource busy
```

**解决方案：**

1. **卸载现有卷**
   ```bash
   hdiutil detach /Volumes/LanMount
   ```

2. **验证 DMG**
   ```bash
   hdiutil verify build/LanMount-1.0.0.dmg
   ```

3. **如果损坏则重新创建**
   ```bash
   fastlane create_dmg version:1.0.0
   ```

#### 问题："应用已损坏"

**症状：**
用户看到："LanMount 已损坏，无法打开"

**解决方案：**

1. **验证公证**
   ```bash
   spctl -a -vv -t install build/LanMount-1.0.0.dmg
   ```

2. **装订票据**
   ```bash
   xcrun stapler staple build/LanMount-1.0.0.dmg
   ```

3. **验证装订**
   ```bash
   xcrun stapler validate build/LanMount-1.0.0.dmg
   ```


### Fastlane 问题

#### 问题：找不到 Fastlane

**症状：**
```
bash: fastlane: command not found
```

**解决方案：**

1. **安装 Fastlane**
   ```bash
   brew install fastlane
   ```

2. **或使用 bundle**
   ```bash
   bundle install
   bundle exec fastlane
   ```

3. **添加到 PATH**
   ```bash
   echo 'export PATH="$HOME/.fastlane/bin:$PATH"' >> ~/.zshrc
   source ~/.zshrc
   ```

#### 问题：缺少 .env 文件

**症状：**
```
Error: .env file not found
```

**解决方案：**

1. **从模板创建**
   ```bash
   cp .env.example .env
   ```

2. **填写必需的值**
   ```bash
   nano .env
   ```

3. **验证**
   ```bash
   cat .env
   ```

#### 问题：Lane 失败

**症状：**
```
Error: Lane 'release' failed
```

**解决方案：**

1. **检查错误消息**
   - 阅读完整的错误输出
   - 查找特定的错误代码

2. **使用详细模式运行**
   ```bash
   fastlane release version:1.0.0 --verbose
   ```

3. **测试单个 lanes**
   ```bash
   fastlane build_app_release
   fastlane create_dmg version:1.0.0
   ```

### GitHub Actions 问题

#### 问题：Workflow 失败

**症状：**
Workflow 在 GitHub Actions 上显示红色 X

**解决方案：**

1. **检查 workflow 日志**
   - 访问 Actions 标签
   - 点击失败的 workflow
   - 阅读错误消息

2. **验证 secrets**
   - Settings → Secrets and variables → Actions
   - 确保所有必需的 secrets 已设置：
     - `APPLE_DEVELOPER_CERTIFICATE_P12_BASE64`
     - `APPLE_DEVELOPER_CERTIFICATE_PASSWORD`
     - `APPLE_ID`
     - `APPLE_TEAM_ID`
     - `APPLE_APP_SPECIFIC_PASSWORD`

3. **先在本地测试**
   ```bash
   fastlane test_build version:1.0.0-test
   ```

#### 问题：证书导入失败

**症状：**
```
Error: security: SecKeychainItemImport failed
```

**解决方案：**

1. **验证 Base64 编码**
   ```bash
   # 重新编码证书
   base64 -i certificate.p12 -o certificate.p12.base64
   ```

2. **检查密码**
   - 验证 `APPLE_DEVELOPER_CERTIFICATE_PASSWORD` 是否正确

3. **重新创建证书**
   - 从钥匙串访问导出
   - 设置新密码
   - 重新编码并更新 secret

#### 问题：Tag 未触发 Workflow

**症状：**
推送了 tag 但 workflow 没有运行

**解决方案：**

1. **检查 tag 格式**
   ```bash
   # 必须以 'v' 开头
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. **验证 workflow 文件**
   ```yaml
   on:
     push:
       tags:
         - 'v*'
   ```

3. **检查 workflow 是否启用**
   - Actions 标签 → 选择 workflow
   - 确保未禁用


### 运行时问题

#### 问题：应用无法启动

**症状：**
应用启动后立即崩溃

**解决方案：**

1. **检查 Console.app**
   - 打开 Console.app
   - 过滤 "LanMount"
   - 查找崩溃日志

2. **检查权限**
   ```bash
   codesign -d --entitlements - build/Release/LanMount.app
   ```

3. **验证代码签名**
   ```bash
   codesign -dv --verbose=4 build/Release/LanMount.app
   ```

4. **测试未签名的构建**
   - 在 Xcode 中不签名构建
   - 如果可以工作，则是签名问题

#### 问题：SMB 挂载失败

**症状：**
```
Error: NetFS returned status 2 (ENOENT)
```

**解决方案：**

1. **检查网络连接**
   ```bash
   ping 10.0.0.172
   ```

2. **在 Finder 中测试**
   - Cmd+K
   - 输入 smb://10.0.0.172/ShareName
   - 如果可以工作，检查应用中的凭证

3. **检查挂载点**
   - 传递 `nil` 作为挂载点 URL
   - 让 NetFS 自动选择位置

4. **验证凭证**
   - 检查用户名/密码
   - 使用不同的凭证测试

#### 问题：钥匙串访问被拒绝

**症状：**
```
Error: User denied access to keychain
```

**解决方案：**

1. **授予钥匙串访问权限**
   - 用户必须在提示时点击 "允许"

2. **添加到钥匙串访问列表**
   - 打开钥匙串访问
   - 找到凭证
   - 访问控制 → 添加 LanMount.app

3. **使用应用专用钥匙串**
   - 为应用创建单独的钥匙串
   - 不要使用登录钥匙串

### 环境问题

#### 问题：错误的 macOS 版本

**症状：**
```
Error: Requires macOS 12.0 or later
```

**解决方案：**

1. **检查 macOS 版本**
   ```bash
   sw_vers
   ```

2. **更新 macOS**
   - 系统设置 → 通用 → 软件更新

3. **降低部署目标**（如需要）
   - 编辑项目设置
   - Deployment Target → 11.0 或更低

#### 问题：缺少 Xcode 命令行工具

**症状：**
```
Error: xcrun: error: invalid active developer path
```

**解决方案：**

1. **安装命令行工具**
   ```bash
   xcode-select --install
   ```

2. **设置 Xcode 路径**
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app
   ```

3. **验证**
   ```bash
   xcode-select -p
   ```

### 获取帮助

#### 收集诊断信息

在寻求帮助之前，收集：

1. **系统信息**
   ```bash
   sw_vers
   xcodebuild -version
   fastlane --version
   ```

2. **构建日志**
   ```bash
   fastlane release version:1.0.0 --verbose > build.log 2>&1
   ```

3. **公证日志**（如适用）
   ```bash
   xcrun notarytool log <submission-id> \
     --apple-id "your@email.com" \
     --team-id "ABCDE12345" \
     --password "xxxx-xxxx-xxxx-xxxx" \
     > notarization.log
   ```

4. **代码签名信息**
   ```bash
   security find-identity -v -p codesigning > certificates.txt
   codesign -dv --verbose=4 build/Release/LanMount.app > codesign.txt 2>&1
   ```

#### 在哪里获取帮助

1. **GitHub Issues**
   - https://github.com/your-username/LanMount/issues
   - 先搜索现有问题
   - 提供诊断信息

2. **文档**
   - [快速开始](QUICK_START.md)
   - [Fastlane 指南](FASTLANE_GUIDE.md)
   - [代码签名指南](CODE_SIGNING.md)
   - [发布指南](RELEASE_GUIDE.md)

3. **Apple Developer 论坛**
   - https://developer.apple.com/forums/
   - 用于代码签名和公证问题

4. **Fastlane 社区**
   - https://github.com/fastlane/fastlane/discussions
   - 用于 Fastlane 特定问题

---

**提示 | Tip:** 遇到问题时，先查看错误日志的完整输出，通常会包含解决问题的关键信息。
