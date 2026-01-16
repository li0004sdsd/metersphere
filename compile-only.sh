#!/bin/bash

###############################################################################
# MeterSphere 源码编译脚本（仅编译）
#
# 功能：
#   1. 编译源码（使用 Java 21）
#   2. 解压 jar 包
#   3. 准备编译产物用于远程部署
#
# 使用方法：
#   ./compile-only.sh              # 完整编译并解压
#   ./compile-only.sh --clean      # 清理后重新编译
#
# 输出：
#   - backend/app/target/app-3.x.jar           (编译产物)
#   - backend/app/target/dependency/           (解压后的文件)
#
###############################################################################

set -e  # 遇到错误立即退出

# =============================================================================
# 配置变量
# =============================================================================

# 源码目录
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"

# Java 21 路径
JAVA_HOME="/opt/homebrew/Cellar/openjdk@21/21.0.9/libexec/openjdk.jdk/Contents/Home"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# =============================================================================
# 工具函数
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

print_separator() {
    echo "=================================================================="
}

print_banner() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║         MeterSphere 源码编译脚本 v1.0                       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
}

# =============================================================================
# 参数解析
# =============================================================================

CLEAN_BUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        -h|--help)
            echo "使用方法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --clean       清理后重新编译（执行 mvn clean）"
            echo "  -h, --help    显示此帮助信息"
            exit 0
            ;;
        *)
            log_error "未知参数: $1"
            echo "使用 $0 --help 查看帮助"
            exit 1
            ;;
    esac
done

# =============================================================================
# 主流程
# =============================================================================

print_banner

# 检查 Java
if [ ! -d "$JAVA_HOME" ]; then
    log_error "Java 21 未找到: $JAVA_HOME"
    log_info "请修改脚本中的 JAVA_HOME 变量"
    exit 1
fi

# 设置 Java 环境
export JAVA_HOME="$JAVA_HOME"
export PATH="$JAVA_HOME/bin:$PATH"

# 显示 Java 版本
JAVA_VERSION=$($JAVA_HOME/bin/java -version 2>&1 | head -n 1)
log_info "使用 Java 版本: $JAVA_VERSION"
print_separator

# 进入源码目录
cd "$SOURCE_DIR"

# 检查 mvnw
if [ ! -f "mvnw" ]; then
    log_error "mvnw 脚本不存在: $SOURCE_DIR/mvnw"
    exit 1
fi

# =============================================================================
# 步骤 1: 编译源码
# =============================================================================

log_step "步骤 1/3: 编译源码..."

if [ "$CLEAN_BUILD" = true ]; then
    log_info "执行清理构建: mvn clean package -DskipTests"
    ./mvnw clean package -DskipTests -Dmaven.test.skip=true
else
    log_info "执行增量构建: mvn package -DskipTests"
    ./mvnw package -DskipTests -Dmaven.test.skip=true
fi

if [ ! -f "backend/app/target/app-3.x.jar" ]; then
    log_error "编译失败：jar 文件不存在"
    exit 1
fi

# 获取 jar 文件大小
JAR_SIZE=$(du -h backend/app/target/app-3.x.jar | cut -f1)
log_success "编译完成，jar 文件大小: $JAR_SIZE"
print_separator

# =============================================================================
# 步骤 2: 解压 jar 包
# =============================================================================

log_step "步骤 2/3: 解压 jar 包..."

cd backend/app/target

# 清理旧的 dependency 目录
if [ -d "dependency" ]; then
    log_info "清理旧的 dependency 目录..."
    rm -rf dependency
fi

# 创建并解压
mkdir -p dependency
cd dependency

log_info "解压 app-3.x.jar（这可能需要几秒钟）..."
jar -xf ../app-3.x.jar

if [ ! -d "BOOT-INF" ]; then
    log_error "解压失败：BOOT-INF 目录不存在"
    exit 1
fi

# 统计文件数量
FILE_COUNT=$(find . -type f | wc -l | tr -d ' ')
TOTAL_SIZE=$(du -sh . | cut -f1)

log_success "解压完成"
log_info "文件数量: $FILE_COUNT"
log_info "总大小: $TOTAL_SIZE"
print_separator

# =============================================================================
# 步骤 3: 生成部署清单
# =============================================================================

log_step "步骤 3/3: 生成部署信息..."

cd "$SOURCE_DIR"

# 创建部署信息文件
DEPLOY_INFO_FILE="backend/app/target/DEPLOY_INFO.txt"

cat > "$DEPLOY_INFO_FILE" << EOF
===============================================================================
MeterSphere 编译产物部署信息
===============================================================================

编译时间: $(date '+%Y-%m-%d %H:%M:%S')
编译机器: $(hostname)
Java 版本: $JAVA_VERSION

编译产物:
  • Jar 文件: backend/app/target/app-3.x.jar ($JAR_SIZE)
  • 解压目录: backend/app/target/dependency/ ($TOTAL_SIZE)
  • 文件数量: $FILE_COUNT

远程部署步骤:
  1. 将以下文件/目录传输到目标服务器:
     - backend/app/target/dependency/
     - Dockerfile
     - shells/
     - redisson.yml
     - frontend/public/

  2. 在目标服务器上构建镜像:
     docker build -f Dockerfile -t metersphere-custom:latest .

  3. 部署容器（参考 REMOTE_DEPLOY_GUIDE.md）

详细部署指南: REMOTE_DEPLOY_GUIDE.md

===============================================================================
EOF

log_success "部署信息已生成: $DEPLOY_INFO_FILE"
print_separator

# =============================================================================
# 完成总结
# =============================================================================

echo ""
log_success "========== 🎉 编译完成 =========="
echo ""
log_info "📦 编译产物位置:"
echo "   • Jar 文件: backend/app/target/app-3.x.jar"
echo "   • 解压目录: backend/app/target/dependency/"
echo "   • 部署信息: backend/app/target/DEPLOY_INFO.txt"
echo ""
log_info "📤 远程部署准备:"
echo "   1. 查看部署指南: cat backend/app/target/DEPLOY_INFO.txt"
echo "   2. 详细步骤文档: REMOTE_DEPLOY_GUIDE.md"
echo ""
log_info "💡 后续操作:"
echo "   • 本地构建镜像: ./build-and-deploy.sh --skip-compile"
echo "   • 远程部署: 参考 REMOTE_DEPLOY_GUIDE.md"
echo ""
print_separator
