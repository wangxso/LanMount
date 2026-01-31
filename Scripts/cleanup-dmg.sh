#!/bin/bash
# cleanup-dmg.sh
# 清理 DMG 构建过程中可能残留的挂载点和临时文件
#
# 使用方法：
#   ./Scripts/cleanup-dmg.sh

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              DMG 清理工具                                    ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 检查是否有 LanMount 相关的挂载点
echo "检查挂载的 DMG..."
MOUNTED_DMGS=$(hdiutil info | grep "/Volumes/LanMount" | awk '{print $1}' || true)

if [ -z "$MOUNTED_DMGS" ]; then
    echo -e "${GREEN}✓${NC} 没有发现挂载的 LanMount DMG"
else
    echo -e "${YELLOW}发现以下挂载点:${NC}"
    hdiutil info | grep "/Volumes/LanMount" || true
    echo ""
    
    read -p "是否卸载所有 LanMount DMG？(y/n) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "卸载 DMG..."
        
        # 尝试正常卸载
        for mount_point in $(hdiutil info | grep "/Volumes/LanMount" | awk '{print $3}' || true); do
            echo "卸载: $mount_point"
            if hdiutil detach "$mount_point" 2>/dev/null; then
                echo -e "${GREEN}✓${NC} 已卸载: $mount_point"
            else
                echo -e "${YELLOW}⚠${NC} 正常卸载失败，尝试强制卸载..."
                hdiutil detach "$mount_point" -force || true
            fi
        done
        
        echo -e "${GREEN}✓${NC} 所有 DMG 已卸载"
    fi
fi

# 清理临时文件
echo ""
echo "检查临时文件..."
TEMP_FILES=$(find /var/folders -name "tmp.*" -name "*dmg*" 2>/dev/null | head -5 || true)

if [ -z "$TEMP_FILES" ]; then
    echo -e "${GREEN}✓${NC} 没有发现临时 DMG 文件"
else
    echo -e "${YELLOW}发现临时文件:${NC}"
    echo "$TEMP_FILES"
    echo ""
    
    read -p "是否清理临时文件？(y/n) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "清理临时文件..."
        find /var/folders -name "tmp.*" -name "*dmg*" -delete 2>/dev/null || true
        echo -e "${GREEN}✓${NC} 临时文件已清理"
    fi
fi

# 清理构建目录中的临时文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build"

if [ -d "$BUILD_DIR" ]; then
    echo ""
    echo "检查构建目录..."
    
    # 查找未完成的 DMG
    INCOMPLETE_DMGS=$(find "$BUILD_DIR" -name "*.dmg" -size 0 2>/dev/null || true)
    
    if [ -n "$INCOMPLETE_DMGS" ]; then
        echo -e "${YELLOW}发现未完成的 DMG:${NC}"
        echo "$INCOMPLETE_DMGS"
        echo ""
        
        read -p "是否删除未完成的 DMG？(y/n) " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            find "$BUILD_DIR" -name "*.dmg" -size 0 -delete
            echo -e "${GREEN}✓${NC} 未完成的 DMG 已删除"
        fi
    else
        echo -e "${GREEN}✓${NC} 构建目录正常"
    fi
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                  清理完成！                                  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "现在可以重新运行构建脚本："
echo "  ./Scripts/quick-release.sh 1.0.0 --skip-notarize --skip-tests"
echo ""
