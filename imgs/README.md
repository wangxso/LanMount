# LanMount 图片资源

这个目录包含 LanMount 的图标和截图资源。

## 📁 目录结构

```
imgs/
├── LanMount.png          # 原始图标 (2048x2048)
├── icon-64.png           # 小图标 (64x64)
├── icon-128.png          # 中图标 (128x128) - 用于 README
├── icon-256.png          # 大图标 (256x256)
├── icon-512.png          # 超大图标 (512x512)
└── screenshots/          # 应用截图目录
    ├── dashboard.png
    ├── network-scanner.png
    └── mount-config.png
```

## 🎨 图标

### 可用尺寸

| 文件 | 尺寸 | 用途 |
|------|------|------|
| `LanMount.png` | 2048x2048 | 原始图标，用于生成其他尺寸 |
| `icon-64.png` | 64x64 | 小图标，徽章等 |
| `icon-128.png` | 128x128 | README 顶部图标 |
| `icon-256.png` | 256x256 | 中等展示 |
| `icon-512.png` | 512x512 | 大图展示 |

### 重新生成图标

如果更新了原始图标 `LanMount.png`，可以使用以下命令重新生成所有尺寸：

```bash
cd /Users/wangxs/LanMount/LanMount/imgs

# 生成所有尺寸
sips -z 64 64 LanMount.png --out icon-64.png
sips -z 128 128 LanMount.png --out icon-128.png
sips -z 256 256 LanMount.png --out icon-256.png
sips -z 512 512 LanMount.png --out icon-512.png
```

或使用脚本：

```bash
cd /Users/wangxs/LanMount/LanMount
./Scripts/generate-icons.sh
```

## 📸 截图

应用截图存放在 `screenshots/` 目录。

详见 [screenshots/README.md](screenshots/README.md) 了解：
- 需要哪些截图
- 如何截图
- 截图规范
- 后处理建议

## 🔄 使用

### 在 README 中使用

**根目录 README.md：**
```markdown
<img src="LanMount/imgs/icon-128.png" alt="LanMount Icon" width="128">
```

**LanMount/README.md：**
```markdown
<img src="imgs/icon-128.png" alt="LanMount Icon" width="128">
```

### 在文档中使用

```markdown
![Dashboard](imgs/screenshots/dashboard.png)
```

## 📝 注意事项

1. **图标文件**
   - 保持 PNG 格式
   - 保持透明背景
   - 不要手动编辑生成的图标

2. **截图文件**
   - 使用 PNG 格式
   - 推荐 16:10 比例
   - 文件大小控制在 500KB 以内
   - 使用有意义的文件名

3. **版本控制**
   - 所有图标都应提交到 Git
   - 截图也应提交（除非太大）
   - 使用 Git LFS 管理大文件（可选）

---

**提示：** 更新图标后记得重新生成所有尺寸，确保一致性。
