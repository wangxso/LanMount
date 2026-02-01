# GitHub Actions Workflow 修复 | Workflow Fix

## 问题 | Issue

GitHub Actions workflow 文件在第 275 行出现语法错误：

```
Invalid workflow file(Line: 275, Col: 13): Unrecognized named-value: 'secrets'. 
Located at position 1 within expression: secrets.HOMEBREW_TAP_TOKEN != '' && github.event.inputs.skip_nota
```

## 原因 | Root Cause

在 GitHub Actions 中，`secrets` 上下文不能直接在 `if` 条件表达式中使用。这是 GitHub Actions 的安全限制。

**错误的用法：**
```yaml
- name: Update Homebrew Cask
  if: ${{ secrets.HOMEBREW_TAP_TOKEN != '' && github.event.inputs.skip_notarization != 'true' }}
  env:
    HOMEBREW_TAP_TOKEN: ${{ secrets.HOMEBREW_TAP_TOKEN }}
```

## 解决方案 | Solution

将 secret 检查移到脚本内部，而不是在 `if` 条件中：

**正确的用法：**
```yaml
- name: Update Homebrew Cask
  if: ${{ github.event.inputs.skip_notarization != 'true' }}
  env:
    HOMEBREW_TAP_TOKEN: ${{ secrets.HOMEBREW_TAP_TOKEN }}
  run: |
    # Skip if token not configured
    if [ -z "$HOMEBREW_TAP_TOKEN" ]; then
      echo "⚠️  HOMEBREW_TAP_TOKEN not configured, skipping Homebrew Cask update"
      exit 0
    fi
    
    # Continue with Homebrew Cask update...
```

## 修改内容 | Changes Made

### 1. 移除 `if` 条件中的 secrets 检查

**之前：**
```yaml
if: ${{ secrets.HOMEBREW_TAP_TOKEN != '' && github.event.inputs.skip_notarization != 'true' }}
```

**之后：**
```yaml
if: ${{ github.event.inputs.skip_notarization != 'true' }}
```

### 2. 在脚本内部添加 token 检查

```bash
# Skip if token not configured
if [ -z "$HOMEBREW_TAP_TOKEN" ]; then
  echo "⚠️  HOMEBREW_TAP_TOKEN not configured, skipping Homebrew Cask update"
  exit 0
fi
```

## 验证 | Verification

### YAML 语法验证

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml'))"
# ✅ YAML syntax is valid
```

### Secrets 使用检查

所有 `secrets` 的使用现在都正确地只在 `env:` 部分：

```yaml
env:
  CERTIFICATE_P12_BASE64: ${{ secrets.APPLE_DEVELOPER_CERTIFICATE_P12_BASE64 }}
  CERTIFICATE_PASSWORD: ${{ secrets.APPLE_DEVELOPER_CERTIFICATE_PASSWORD }}
  APPLE_ID: ${{ secrets.APPLE_ID }}
  APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
  APPLE_APP_SPECIFIC_PASSWORD: ${{ secrets.APPLE_APP_SPECIFIC_PASSWORD }}
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  HOMEBREW_TAP_TOKEN: ${{ secrets.HOMEBREW_TAP_TOKEN }}
```

## 工作流程 | Workflow Behavior

### 场景 1：HOMEBREW_TAP_TOKEN 已配置

1. Step 运行
2. Token 存在，继续更新 Homebrew Cask
3. 成功完成

### 场景 2：HOMEBREW_TAP_TOKEN 未配置

1. Step 运行
2. 检测到 token 为空
3. 输出警告信息
4. 优雅退出（exit 0）
5. Workflow 继续执行

### 场景 3：skip_notarization = true

1. Step 被跳过（if 条件为 false）
2. 不执行任何操作

## 最佳实践 | Best Practices

### ✅ 正确的做法

1. **在 env 中使用 secrets**
   ```yaml
   env:
     MY_SECRET: ${{ secrets.MY_SECRET }}
   ```

2. **在脚本中检查 secrets**
   ```bash
   if [ -z "$MY_SECRET" ]; then
     echo "Secret not configured"
     exit 0
   fi
   ```

3. **使用 github 上下文在 if 中**
   ```yaml
   if: ${{ github.event.inputs.some_input != 'value' }}
   ```

### ❌ 错误的做法

1. **在 if 中直接使用 secrets**
   ```yaml
   if: ${{ secrets.MY_SECRET != '' }}  # ❌ 不允许
   ```

2. **在 if 中比较 secrets**
   ```yaml
   if: ${{ secrets.MY_SECRET == 'value' }}  # ❌ 不允许
   ```

## 相关文档 | Related Documentation

- [GitHub Actions Contexts](https://docs.github.com/en/actions/learn-github-actions/contexts)
- [GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)

## 状态 | Status

✅ **已修复** - Workflow 文件现在符合 GitHub Actions 语法规范

---

**修复时间 | Fix Date:** 2026-01-31  
**文件 | File:** `.github/workflows/release.yml`  
**行号 | Line:** 275
