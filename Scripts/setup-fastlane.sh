#!/bin/bash
# setup-fastlane.sh
# 安装和配置 Fastlane

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Fastlane 安装和配置                             ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 检查是否已安装 Fastlane
if command -v fastlane &> /dev/null; then
    FASTLANE_VERSION=$(fastlane --version | head -n 1)
    echo -e "${GREEN}✓${NC} Fastlane 已安装: $FASTLANE_VERSION"
else
    echo -e "${YELLOW}⚠${NC} Fastlane 未安装"
    echo ""
    read -p "是否安装 Fastlane？(y/n) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "安装 Fastlane..."
        
        # 检查 Homebrew
        if command -v brew &> /dev/null; then
            echo "使用 Homebrew 安装..."
            brew install fastlane
        else
            echo "使用 RubyGems 安装..."
            sudo gem install fastlane
        fi
        
        if command -v fastlane &> /dev/null; then
            echo -e "${GREEN}✓${NC} Fastlane 安装成功"
        else
            echo -e "${RED}✗${NC} Fastlane 安装失败"
            exit 1
        fi
    else
        echo "跳过安装"
        exit 0
    fi
fi

# 检查 .env 文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo ""
echo "检查配置文件..."

if [ ! -f "$PROJECT_ROOT/.env" ]; then
    echo -e "${YELLOW}⚠${NC} .env 文件不存在"
    
    if [ -f "$PROJECT_ROOT/.env.example" ]; then
        read -p "是否从 .env.example 创建 .env？(y/n) " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cp "$PROJECT_ROOT/.env.example" "$PROJECT_ROOT/.env"
            echo -e "${GREEN}✓${NC} .env 文件已创建"
            echo ""
            echo -e "${YELLOW}请编辑 .env 文件并填入你的配置：${NC}"
            echo "  nano .env"
        fi
    fi
else
    echo -e "${GREEN}✓${NC} .env 文件存在"
fi

# 安装 Ruby 依赖（如果使用 Bundler）
if [ -f "$PROJECT_ROOT/Gemfile" ]; then
    echo ""
    read -p "是否安装 Ruby 依赖（Bundler）？(y/n) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd "$PROJECT_ROOT"
        
        # 检查 Bundler
        if ! command -v bundle &> /dev/null; then
            echo "安装 Bundler..."
            sudo gem install bundler
        fi
        
        echo "安装依赖..."
        bundle install
        
        echo -e "${GREEN}✓${NC} Ruby 依赖安装完成"
    fi
fi

# 验证配置
echo ""
echo "验证 Fastlane 配置..."
cd "$PROJECT_ROOT"

if fastlane validate 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Fastlane 配置验证通过"
else
    echo -e "${YELLOW}⚠${NC} Fastlane 配置验证失败"
    echo "请确保 .env 文件已正确配置"
fi

# 显示可用的 lanes
echo ""
echo "可用的 Fastlane Lanes:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fastlane lanes 2>/dev/null || echo "运行 'fastlane lanes' 查看可用命令"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                  安装完成！                                  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "下一步："
echo "  1. 配置 .env 文件（如果还没有）"
echo "  2. 验证配置: fastlane validate"
echo "  3. 测试构建: fastlane test_build version:1.0.0-test"
echo "  4. 正式发布: fastlane release version:1.0.0"
echo ""
echo "查看完整指南: cat FASTLANE_GUIDE.md"
echo ""
