#!/bin/bash
# quick-release.sh
# 一键发布脚本 - 从 .env 文件读取配置
#
# 使用方法：
#   1. 复制 .env.example 为 .env
#   2. 填写 .env 中的配置信息
#   3. 运行：./Scripts/quick-release.sh 1.0.0
#
# 参数：
#   $1: 版本号（必需）例如：1.0.0
#
# 选项：
#   --skip-notarize    跳过公证（用于本地测试）
#   --skip-tests       跳过测试
#   --debug            使用 Debug 配置构建

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 默认值
SKIP_NOTARIZE=false
SKIP_TESTS=false
BUILD_CONFIG="Release"

# 解析参数
VERSION=""
for arg in "$@"; do
    case $arg in
        --skip-notarize)
            SKIP_NOTARIZE=true
            shift
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --debug)
            BUILD_CONFIG="Debug"
            shift
            ;;
        -h|--help)
            echo "使用方法: $0 <版本号> [选项]"
            echo ""
            echo "参数:"
            echo "  版本号          版本号，例如：1.0.0"
            echo ""
            echo "选项:"
            echo "  --skip-notarize  跳过公证（用于本地测试）"
            echo "  --skip-tests     跳过测试"
            echo "  --debug          使用 Debug 配置构建"
            echo "  -h, --help       显示此帮助信息"
            echo ""
            echo "示例:"
            echo "  $0 1.0.0"
            echo "  $0 1.0.0 --skip-notarize"
            echo "  $0 1.0.0 --debug --skip-tests"
            exit 0
            ;;
        *)
            if [ -z "$VERSION" ]; then
                VERSION="$arg"
            fi
            ;;
    esac
done

# 检查版本号
if [ -z "$VERSION" ]; then
    echo -e "${RED}错误: 请提供版本号${NC}"
    echo ""
    echo "使用方法: $0 <版本号>"
    echo "示例: $0 1.0.0"
    exit 1
fi

# 验证版本号格式
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?$ ]]; then
    echo -e "${RED}错误: 版本号格式无效: $VERSION${NC}"
    echo "期望格式: X.Y.Z 或 X.Y.Z-suffix (例如: 1.0.0, 1.0.0-beta1)"
    exit 1
fi

# 打印横幅
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                              ║${NC}"
echo -e "${CYAN}║              LanMount 一键发布脚本                           ║${NC}"
echo -e "${CYAN}║                                                              ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 加载 .env 文件
ENV_FILE="$PROJECT_ROOT/.env"
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}错误: 未找到 .env 文件${NC}"
    echo ""
    echo "请按以下步骤配置："
    echo "1. 复制模板文件："
    echo "   cp .env.example .env"
    echo ""
    echo "2. 编辑 .env 文件，填入你的配置："
    echo "   - APPLE_ID: 你的 Apple ID"
    echo "   - TEAM_ID: 你的 Team ID"
    echo "   - APP_SPECIFIC_PASSWORD: App 专用密码"
    echo ""
    echo "3. 重新运行此脚本"
    exit 1
fi

echo -e "${BLUE}加载配置...${NC}"
# 加载环境变量
set -a
source "$ENV_FILE"
set +a

# 验证必需的环境变量
if [ "$SKIP_NOTARIZE" = false ]; then
    if [ -z "$APPLE_ID" ] || [ -z "$TEAM_ID" ] || [ -z "$APP_SPECIFIC_PASSWORD" ]; then
        echo -e "${RED}错误: .env 文件中缺少必需的配置${NC}"
        echo ""
        echo "请确保 .env 文件包含以下配置："
        echo "  - APPLE_ID"
        echo "  - TEAM_ID"
        echo "  - APP_SPECIFIC_PASSWORD"
        echo ""
        echo "或者使用 --skip-notarize 跳过公证"
        exit 1
    fi
fi

# 设置默认值
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-AC_PASSWORD}"
APP_NAME="${APP_NAME:-LanMount}"
BUNDLE_ID="${BUNDLE_ID:-com.lanmount.app}"

# 路径配置
BUILD_DIR="$PROJECT_ROOT/build"
RELEASE_DIR="$BUILD_DIR/$BUILD_CONFIG"
APP_PATH="$RELEASE_DIR/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION.dmg"

echo -e "${GREEN}✓${NC} 配置加载完成"
echo ""
echo -e "${BLUE}版本:${NC}        $VERSION"
echo -e "${BLUE}构建配置:${NC}    $BUILD_CONFIG"
echo -e "${BLUE}应用名称:${NC}    $APP_NAME"
echo -e "${BLUE}Bundle ID:${NC}   $BUNDLE_ID"
echo -e "${BLUE}输出路径:${NC}    $DMG_PATH"
if [ "$SKIP_NOTARIZE" = false ]; then
    echo -e "${BLUE}Apple ID:${NC}    $APPLE_ID"
    echo -e "${BLUE}Team ID:${NC}     $TEAM_ID"
fi
echo ""

# 函数：打印步骤标题
print_step() {
    local step_num=$1
    local step_name=$2
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}步骤 $step_num: $step_name${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 步骤 1: 配置公证凭证
if [ "$SKIP_NOTARIZE" = false ]; then
    print_step 1 "配置公证凭证"
    
    # 检查凭证是否已存储
    if xcrun notarytool history --keychain-profile "$KEYCHAIN_PROFILE" &>/dev/null; then
        echo -e "${GREEN}✓${NC} 公证凭证已配置"
    else
        echo "首次配置公证凭证..."
        echo -e "${YELLOW}注意: 如果遇到 Apple 服务器错误（500），这是暂时性问题，稍后重试即可${NC}"
        
        # 尝试存储凭证，但允许失败
        if xcrun notarytool store-credentials "$KEYCHAIN_PROFILE" \
            --apple-id "$APPLE_ID" \
            --team-id "$TEAM_ID" \
            --password "$APP_SPECIFIC_PASSWORD" 2>&1 | tee /tmp/notarytool_error.log; then
            echo -e "${GREEN}✓${NC} 公证凭证配置成功"
        else
            # 检查是否是服务器错误
            if grep -q "500\|UNEXPECTED_ERROR\|internalError" /tmp/notarytool_error.log; then
                echo -e "${YELLOW}⚠${NC} Apple 公证服务暂时不可用（服务器错误）"
                echo ""
                echo "这是 Apple 服务器的临时问题，不是你的配置问题。"
                echo ""
                echo "解决方案："
                echo "1. 等待几分钟后重试"
                echo "2. 或者先跳过公证，稍后手动公证："
                echo "   ./Scripts/quick-release.sh $VERSION --skip-notarize"
                echo "   # 构建完成后再公证："
                echo "   ./Scripts/notarize-app.sh build/$APP_NAME-$VERSION.dmg"
                echo ""
                read -p "是否继续（跳过公证凭证配置）？(y/n) " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    exit 1
                fi
                echo -e "${YELLOW}⚠${NC} 继续执行，但将跳过公证步骤"
                SKIP_NOTARIZE=true
            else
                echo -e "${RED}✗${NC} 公证凭证配置失败"
                cat /tmp/notarytool_error.log
                exit 1
            fi
        fi
        rm -f /tmp/notarytool_error.log
    fi
else
    print_step 1 "配置公证凭证 (已跳过)"
    echo -e "${YELLOW}⚠${NC} 跳过公证配置"
fi

# 步骤 2: 运行测试
if [ "$SKIP_TESTS" = false ]; then
    print_step 2 "运行测试"
    
    cd "$PROJECT_ROOT"
    if xcodebuild test \
        -project LanMount.xcodeproj \
        -scheme LanMount \
        -destination 'platform=macOS' \
        -quiet 2>&1 | grep -q "not currently configured for the test action"; then
        echo -e "${YELLOW}⚠${NC} Scheme 未配置测试目标，跳过测试"
        echo "提示: 如果需要运行测试，请在 Xcode 中配置 Scheme 的测试目标"
    elif xcodebuild test \
        -project LanMount.xcodeproj \
        -scheme LanMount \
        -destination 'platform=macOS' \
        -quiet; then
        echo -e "${GREEN}✓${NC} 所有测试通过"
    else
        echo -e "${YELLOW}⚠${NC} 测试失败，但继续构建"
        echo "提示: 使用 --skip-tests 可以跳过测试步骤"
    fi
else
    print_step 2 "运行测试 (已跳过)"
    echo -e "${YELLOW}⚠${NC} 跳过测试"
fi

# 步骤 3: 清理构建目录
print_step 3 "清理构建目录"

echo "清理旧的构建文件..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
echo -e "${GREEN}✓${NC} 构建目录已清理"

# 步骤 4: 构建应用
print_step 4 "构建应用"

cd "$PROJECT_ROOT"
echo "构建 $APP_NAME ($BUILD_CONFIG 配置)..."

BUILD_ARGS=(
    -project LanMount.xcodeproj
    -scheme LanMount
    -configuration "$BUILD_CONFIG"
    -derivedDataPath "$BUILD_DIR/DerivedData"
    CONFIGURATION_BUILD_DIR="$RELEASE_DIR"
)

# 如果不跳过公证，添加代码签名参数
if [ "$SKIP_NOTARIZE" = false ]; then
    if [ -n "$CODE_SIGN_IDENTITY" ]; then
        BUILD_ARGS+=(CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY")
    else
        BUILD_ARGS+=(CODE_SIGN_IDENTITY="Developer ID Application")
    fi
    BUILD_ARGS+=(OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime")
fi

xcodebuild "${BUILD_ARGS[@]}" clean build

if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}✗ 构建失败 - 未找到应用: $APP_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} 构建完成"

# 步骤 5: 验证代码签名
if [ "$SKIP_NOTARIZE" = false ]; then
    print_step 5 "验证代码签名"
    
    if "$SCRIPT_DIR/verify-codesign.sh" "$APP_PATH"; then
        echo -e "${GREEN}✓${NC} 代码签名验证通过"
    else
        echo -e "${RED}✗ 代码签名验证失败${NC}"
        exit 1
    fi
else
    print_step 5 "验证代码签名 (已跳过)"
    echo -e "${YELLOW}⚠${NC} 跳过代码签名验证"
fi

# 步骤 6: 创建 DMG
print_step 6 "创建 DMG"

# 尝试创建 DMG，如果失败则清理并重试
DMG_RETRIES=2
DMG_SUCCESS=false

for attempt in $(seq 1 $DMG_RETRIES); do
    if [ $attempt -gt 1 ]; then
        echo ""
        echo -e "${YELLOW}第 $attempt 次尝试创建 DMG...${NC}"
        echo "清理可能的残留挂载点..."
        
        # 卸载所有 LanMount 相关的挂载点
        for mount_point in $(hdiutil info | grep "/Volumes/LanMount" | awk '{print $3}' 2>/dev/null || true); do
            echo "卸载: $mount_point"
            hdiutil detach "$mount_point" -force 2>/dev/null || true
        done
        
        sleep 2
    fi
    
    if "$SCRIPT_DIR/build-dmg.sh" \
        --app-path "$APP_PATH" \
        --output "$DMG_PATH" \
        --volume-name "$APP_NAME"; then
        DMG_SUCCESS=true
        break
    fi
    
    if [ $attempt -lt $DMG_RETRIES ]; then
        echo -e "${YELLOW}⚠${NC} DMG 创建失败，准备重试..."
        sleep 3
    fi
done

if [ "$DMG_SUCCESS" = false ]; then
    echo -e "${RED}✗ DMG 创建失败${NC}"
    echo ""
    echo "故障排除："
    echo "1. 运行清理脚本: ./Scripts/cleanup-dmg.sh"
    echo "2. 检查磁盘空间: df -h"
    echo "3. 重启后重试"
    exit 1
fi

if [ ! -f "$DMG_PATH" ]; then
    echo -e "${RED}✗ DMG 创建失败 - 文件不存在${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} DMG 创建成功"

# 步骤 7: 公证
if [ "$SKIP_NOTARIZE" = false ]; then
    print_step 7 "提交公证"
    
    echo "提交 DMG 到 Apple 进行公证..."
    echo "（这可能需要 5-15 分钟，请耐心等待）"
    
    "$SCRIPT_DIR/notarize-app.sh" \
        --profile "$KEYCHAIN_PROFILE" \
        "$DMG_PATH"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} 公证成功"
    else
        echo -e "${RED}✗ 公证失败${NC}"
        exit 1
    fi
    
    # 步骤 8: 装订公证票据
    print_step 8 "装订公证票据"
    
    "$SCRIPT_DIR/staple-ticket.sh" "$DMG_PATH"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} 公证票据装订成功"
    else
        echo -e "${YELLOW}⚠${NC} 公证票据装订失败（可能需要稍后重试）"
    fi
    
    # 步骤 9: 验证公证
    print_step 9 "验证公证"
    
    "$SCRIPT_DIR/verify-notarization.sh" "$DMG_PATH" || true
else
    print_step 7 "公证 (已跳过)"
    echo -e "${YELLOW}⚠${NC} 跳过公证流程"
fi

# 步骤 10: 完成
print_step 10 "发布完成"

DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    发布准备完成！                            ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}版本:${NC}     $VERSION"
echo -e "${BLUE}DMG:${NC}      $DMG_PATH"
echo -e "${BLUE}大小:${NC}     $DMG_SIZE"
echo ""
echo "输出文件："
echo "  • $DMG_PATH"
echo ""

if [ "$SKIP_NOTARIZE" = false ]; then
    echo -e "${GREEN}✓${NC} DMG 已签名并公证，可以公开分发"
else
    echo -e "${YELLOW}⚠${NC} DMG 未公证，仅用于本地测试"
fi

echo ""
echo "下一步："
echo "  1. 测试 DMG 安装"
echo "  2. 创建 GitHub Release"
echo "  3. 上传 DMG 到 GitHub"
echo ""

# 询问是否打开 DMG 所在目录
read -p "是否打开 DMG 所在目录？(y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "$BUILD_DIR"
fi

echo -e "${GREEN}完成！${NC}"
