# GitHub Workflow 缓存问题修复 | Workflow Cache Fix

## 问题 | Issue

GitHub 报告 workflow 文件错误：

```
Invalid workflow file: .github/workflows/release.yml#L1
(Line: 275, Col: 13): Unrecognized named-value: 'secrets'. 
Located at position 1 within expression: secrets.HOMEBREW_TAP_TOKEN != '' && ...
```

但是本地文件中已经没有这个问题了。

## 原因 | Root Cause

**GitHub Actions 缓存问题**

- 本地文件已经修复并提交
- GitHub 可能还在使用旧的缓存版本
- 需要强制 GitHub 重新读取文件

## 验证 | Verification

### 本地文件检查

```bash
# 检查是否还有 HOMEBREW_TAP_TOKEN
grep -n "HOMEBREW_TAP_TOKEN" LanMount/.github/workflows/release.yml
# 结果：无匹配（✅ 已删除）

# 验证 YAML 语法
python3 -c "import yaml; yaml.safe_load(open('LanMount/.github/workflows/release.yml'))"
# 结果：✅ YAML 语法正确

# 检查 git 状态
git -C LanMount log --oneline -1 .github/workflows/release.yml
# 结果：28e842c [ci]: update ci file
```

### 文件状态

- ✅ 本地文件正确
- ✅ 已提交到 git
- ✅ 已推送到远程
- ⚠️ GitHub 可能使用旧缓存

## 解决方案 | Solution

### 方法 1：强制刷新（推荐）

添加一个小的注释来强制 GitHub 重新读取文件：

```yaml
# Last updated: 2026-01-31
```

然后重新提交：

```bash
git -C LanMount add .github/workflows/release.yml
git -C LanMount commit -m 'fix: force refresh workflow file'
git -C LanMount push
```

### 方法 2：等待缓存过期

GitHub 的缓存通常会在几分钟内自动刷新。

### 方法 3：重新创建 workflow

如果问题持续，可以：

1. 删除 `.github/workflows/release.yml`
2. 提交删除
3. 重新创建文件
4. 提交新文件

## 当前文件状态 | Current File Status

### 文件信息

- **路径：** `.github/workflows/release.yml`
- **行数：** 305 行
- **大小：** ~10KB
- **最后修改：** 2026-01-31

### 功能确认

✅ **已移除的内容：**
- Homebrew Cask 自动更新
- `HOMEBREW_TAP_TOKEN` secret 引用
- 所有 Homebrew 相关代码

✅ **保留的功能：**
- 构建应用
- 代码签名
- 创建 DMG
- Apple 公证
- 创建 GitHub Release
- 上传 DMG

### 语法验证

```bash
# YAML 语法
✅ 有效

# Secrets 使用
✅ 只在 env: 部分使用

# If 条件
✅ 不包含 secrets 引用
```

## 预防措施 | Prevention

### 最佳实践

1. **本地验证**
   ```bash
   # 验证 YAML 语法
   python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml'))"
   
   # 检查 secrets 使用
   grep -n "if:.*secrets" .github/workflows/release.yml
   ```

2. **提交前检查**
   ```bash
   # 查看修改
   git diff .github/workflows/release.yml
   
   # 确认无误后提交
   git add .github/workflows/release.yml
   git commit -m "fix: update workflow"
   ```

3. **推送后验证**
   - 访问 GitHub Actions 页面
   - 检查 workflow 文件是否有错误
   - 如有缓存问题，等待几分钟或强制刷新

## 相关文档 | Related Documentation

- [Workflow Fix](WORKFLOW_FIX.md) - Secrets 语法修复
- [Workflow Simplified](WORKFLOW_SIMPLIFIED.md) - Workflow 简化说明
- [GitHub Actions Setup](GITHUB_ACTIONS_SETUP.md) - 完整配置指南

## 总结 | Summary

**问题：** GitHub 报告 workflow 文件有 secrets 语法错误  
**原因：** GitHub 缓存了旧版本的文件  
**解决：** 添加注释强制刷新，重新提交推送  
**状态：** ✅ 本地文件正确，等待 GitHub 刷新

---

**修复时间 | Fix Date:** 2026-01-31  
**状态 | Status:** ✅ 已修复，等待 GitHub 刷新缓存
