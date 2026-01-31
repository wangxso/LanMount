#!/bin/bash
# generate-icons.sh
# 从单个大图标生成所有需要的 macOS 应用图标尺寸
#
# 使用方法：
#   ./Scripts/generate-icons.sh path/to/icon-1024.png
#
# 要求：
#   - 输入图标必须是 1024×1024 PNG 格式
#   - 需要安装 sips 命令（macOS 自带）

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查参数
if [ $# -eq 0 ]; then
    echo -e "${RED}错误: 请提供图标文件路径${NC}"
    echo ""
    echo "使用方法:"
    echo "  $0 path/to/icon-1024.png"
    echo ""
    echo "要求:"
    echo "  - 图标必须是 PNG 格式"
    echo "  - 推荐尺寸: 1024×1024 像素"
    exit 1
fi

INPUT_ICON="$1"

# 检查文件是否存在
if [ ! -f "$INPUT_ICON" ]; then
    echo -e "${RED}错误: 文件不存在: $INPUT_ICON${NC}"
    exit 1
fi

# 检查是否是 PNG 文件
if ! file "$INPUT_ICON" | grep -q "PNG"; then
    echo -e "${RED}错误: 文件不是 PNG 格式${NC}"
    echo "请提供 PNG 格式的图标文件"
    exit 1
fi

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 目标目录
ICONSET_DIR="$PROJECT_ROOT/LanMount/Assets.xcassets/AppIcon.appiconset"

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              LanMount 图标生成工具                           ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}输入图标:${NC} $INPUT_ICON"
echo -e "${BLUE}输出目录:${NC} $ICONSET_DIR"
echo ""

# 检查 sips 命令
if ! command -v sips &> /dev/null; then
    echo -e "${RED}错误: 未找到 sips 命令${NC}"
    echo "sips 是 macOS 自带的图像处理工具"
    exit 1
fi

# 获取输入图标尺寸
INPUT_SIZE=$(sips -g pixelWidth "$INPUT_ICON" | grep pixelWidth | awk '{print $2}')
echo -e "${BLUE}输入图标尺寸:${NC} ${INPUT_SIZE}×${INPUT_SIZE}"

if [ "$INPUT_SIZE" -lt 1024 ]; then
    echo -e "${YELLOW}警告: 输入图标尺寸小于 1024×1024，可能导致大尺寸图标模糊${NC}"
    read -p "是否继续？(y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 创建目标目录
mkdir -p "$ICONSET_DIR"

echo ""
echo "生成图标..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 定义需要生成的尺寸
declare -A SIZES=(
    ["icon_16x16.png"]="16"
    ["icon_16x16@2x.png"]="32"
    ["icon_32x32.png"]="32"
    ["icon_32x32@2x.png"]="64"
    ["icon_128x128.png"]="128"
    ["icon_128x128@2x.png"]="256"
    ["icon_256x256.png"]="256"
    ["icon_256x256@2x.png"]="512"
    ["icon_512x512.png"]="512"
    ["icon_512x512@2x.png"]="1024"
)

# 生成每个尺寸
for filename in "${!SIZES[@]}"; do
    size="${SIZES[$filename]}"
    output_path="$ICONSET_DIR/$filename"
    
    echo -n "生成 $filename (${size}×${size})... "
    
    sips -z "$size" "$size" "$INPUT_ICON" --out "$output_path" > /dev/null 2>&1
    
    if [ -f "$output_path" ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 更新 Contents.json
echo ""
echo "更新 Contents.json..."

cat > "$ICONSET_DIR/Contents.json" << 'EOF'
{
  "images" : [
    {
      "filename" : "icon_16x16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_16x16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32x32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_32x32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128x128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_128x128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256x256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_256x256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512x512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_512x512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

echo -e "${GREEN}✓${NC} Contents.json 已更新"

# 验证生成的文件
echo ""
echo "验证生成的文件..."
MISSING_FILES=0
for filename in "${!SIZES[@]}"; do
    if [ ! -f "$ICONSET_DIR/$filename" ]; then
        echo -e "${RED}✗${NC} 缺少: $filename"
        MISSING_FILES=$((MISSING_FILES + 1))
    fi
done

if [ $MISSING_FILES -eq 0 ]; then
    echo -e "${GREEN}✓${NC} 所有图标文件已生成"
else
    echo -e "${YELLOW}⚠${NC} 有 $MISSING_FILES 个文件缺失"
fi

# 显示生成的文件列表
echo ""
echo "生成的文件:"
ls -lh "$ICONSET_DIR"/*.png 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                  图标生成完成！                              ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "下一步:"
echo "  1. 在 Xcode 中打开项目，查看 Assets.xcassets/AppIcon"
echo "  2. 清理构建缓存: rm -rf ~/Library/Developer/Xcode/DerivedData"
echo "  3. 重新构建项目: ./Scripts/quick-release.sh 1.0.0 --skip-notarize --skip-tests"
echo "  4. 查看应用图标: open build/Release/LanMount.app"
echo ""
echo -e "${BLUE}提示:${NC} 如果图标没有立即显示，尝试重启 Finder:"
echo "  killall Finder"
echo ""
