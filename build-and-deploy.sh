#!/bin/bash

###############################################################################
# MeterSphere 源码编译、构建和部署脚本
#
# 功能：
#   1. 编译源码（使用 Java 21）
#   2. 解压 jar 包
#   3. 构建 Docker 镜像
#   4. 部署到 /opt/metersphere
#
# 使用方法：
#   ./build-and-deploy.sh                  # 完整流程：编译+构建+部署
#   ./build-and-deploy.sh --skip-compile   # 跳过编译，只构建和部署
#   ./build-and-deploy.sh --skip-deploy    # 只编译和构建，不部署
#   ./build-and-deploy.sh --build-only     # 只构建镜像，不编译不部署
#
###############################################################################

set -e  # 遇到错误立即退出

# =============================================================================
# 配置变量
# =============================================================================

# 源码目录
SOURCE_DIR="/Users/huawen.li/IdeaProjects/metersphere_github/metersphere"

# 部署目录
DEPLOY_DIR="/opt/metersphere"

# Java 21 路径
JAVA_HOME="/opt/homebrew/Cellar/openjdk@21/21.0.9/libexec/openjdk.jdk/Contents/Home"

# Docker 镜像名称
IMAGE_NAME="metersphere-custom"
IMAGE_TAG="latest"
OFFICIAL_IMAGE_TAG="registry.fit2cloud.com/metersphere/metersphere-ce:v3.6.3-lts"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_separator() {
    echo "=================================================================="
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        log_error "$1 未安装或不在 PATH 中"
        exit 1
    fi
}

# =============================================================================
# 参数解析
# =============================================================================

SKIP_COMPILE=false
SKIP_DEPLOY=false
BUILD_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-compile)
            SKIP_COMPILE=true
            shift
            ;;
        --skip-deploy)
            SKIP_DEPLOY=true
            shift
            ;;
        --build-only)
            BUILD_ONLY=true
            SKIP_COMPILE=true
            SKIP_DEPLOY=true
            shift
            ;;
        -h|--help)
            echo "使用方法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --skip-compile    跳过编译步骤，直接构建镜像"
            echo "  --skip-deploy     跳过部署步骤，只编译和构建镜像"
            echo "  --build-only      只构建镜像（跳过编译和部署）"
            echo "  -h, --help        显示此帮助信息"
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
# 环境检查
# =============================================================================

log_info "开始环境检查..."

# 检查必要命令
check_command docker
check_command docker-compose

# 检查 Java
if [ ! -d "$JAVA_HOME" ]; then
    log_error "Java 21 未找到: $JAVA_HOME"
    exit 1
fi

# 检查源码目录
if [ ! -d "$SOURCE_DIR" ]; then
    log_error "源码目录不存在: $SOURCE_DIR"
    exit 1
fi

# 检查 mvnw
if [ ! -f "$SOURCE_DIR/mvnw" ]; then
    log_error "mvnw 脚本不存在: $SOURCE_DIR/mvnw"
    exit 1
fi

log_success "环境检查通过"
print_separator

# =============================================================================
# 步骤 1: 编译源码
# =============================================================================

if [ "$SKIP_COMPILE" = false ]; then
    log_info "步骤 1/4: 编译源码..."

    cd "$SOURCE_DIR"

    # 设置 Java 环境
    export JAVA_HOME="$JAVA_HOME"
    export PATH="$JAVA_HOME/bin:$PATH"

    # 显示 Java 版本
    log_info "使用 Java 版本: $($JAVA_HOME/bin/java -version 2>&1 | head -n 1)"

    # 清理并编译
    log_info "执行 Maven 编译（跳过测试）..."
    ./mvnw clean package -DskipTests -Dmaven.test.skip=true

    if [ ! -f "backend/app/target/app-3.x.jar" ]; then
        log_error "编译失败：jar 文件不存在"
        exit 1
    fi

    log_success "源码编译完成"
    print_separator

    # 解压 jar 包
    log_info "步骤 2/4: 解压 jar 包..."

    cd "$SOURCE_DIR/backend/app/target"

    # 清理旧的 dependency 目录
    if [ -d "dependency" ]; then
        log_info "清理旧的 dependency 目录..."
        rm -rf dependency
    fi

    # 创建并解压
    mkdir -p dependency
    cd dependency

    log_info "解压 app-3.x.jar..."
    jar -xf ../app-3.x.jar

    if [ ! -d "BOOT-INF" ]; then
        log_error "解压失败：BOOT-INF 目录不存在"
        exit 1
    fi

    log_success "jar 包解压完成"
    print_separator
else
    log_warning "跳过编译步骤"

    # 检查是否已存在解压的文件
    if [ ! -d "$SOURCE_DIR/backend/app/target/dependency/BOOT-INF" ]; then
        log_error "跳过编译但未找到已解压的文件，请先执行完整编译"
        exit 1
    fi

    print_separator
fi

# =============================================================================
# 步骤 3: 构建 Docker 镜像
# =============================================================================

log_info "步骤 3/4: 构建 Docker 镜像..."

cd "$SOURCE_DIR"

# 检查 Dockerfile
if [ ! -f "Dockerfile" ]; then
    log_error "Dockerfile 不存在: $SOURCE_DIR/Dockerfile"
    exit 1
fi

# 检查 shells 目录
if [ ! -d "shells" ] || [ ! -f "shells/metersphere.sh" ]; then
    log_error "shells/metersphere.sh 不存在，请确保已创建启动脚本"
    exit 1
fi

# 构建镜像
log_info "构建镜像: ${IMAGE_NAME}:${IMAGE_TAG}"
docker build -f Dockerfile -t "${IMAGE_NAME}:${IMAGE_TAG}" .

if [ $? -ne 0 ]; then
    log_error "Docker 镜像构建失败"
    exit 1
fi

# 打标签
log_info "为镜像打标签: ${OFFICIAL_IMAGE_TAG}"
docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${OFFICIAL_IMAGE_TAG}"

# 显示镜像信息
IMAGE_ID=$(docker images -q "${IMAGE_NAME}:${IMAGE_TAG}")
IMAGE_SIZE=$(docker images "${IMAGE_NAME}:${IMAGE_TAG}" --format "{{.Size}}")

log_success "Docker 镜像构建完成"
log_info "镜像 ID: ${IMAGE_ID}"
log_info "镜像大小: ${IMAGE_SIZE}"
print_separator

# =============================================================================
# 步骤 4: 部署到服务器
# =============================================================================

if [ "$SKIP_DEPLOY" = false ] && [ "$BUILD_ONLY" = false ]; then
    log_info "步骤 4/4: 部署到服务器..."

    # 检查部署目录
    if [ ! -d "$DEPLOY_DIR" ]; then
        log_error "部署目录不存在: $DEPLOY_DIR"
        exit 1
    fi

    cd "$DEPLOY_DIR"

    # 检查 docker-compose 文件
    if [ ! -f "docker-compose-base.yml" ] || [ ! -f "docker-compose-metersphere.yml" ]; then
        log_error "docker-compose 配置文件不存在"
        exit 1
    fi

    # 停止并删除旧容器
    log_info "停止并删除旧的 metersphere 容器..."
    docker stop metersphere 2>/dev/null || true
    docker rm metersphere 2>/dev/null || true

    # 启动新容器（使用正确的环境变量）
    log_info "启动新的 metersphere 容器..."

    MS_MYSQL_HOST=mysql \
    MS_KAFKA_HOST=kafka \
    MS_REDIS_HOST=redis \
    MS_MINIO_HOST=minio \
    MS_MINIO_ENDPOINT="http://minio:9000" \
    docker-compose -f docker-compose-base.yml \
                   -f docker-compose-metersphere.yml \
                   up -d metersphere

    if [ $? -ne 0 ]; then
        log_error "容器启动失败"
        exit 1
    fi

    # 等待容器启动
    log_info "等待容器启动（30秒）..."
    sleep 30

    # 检查容器状态
    CONTAINER_STATUS=$(docker ps --filter name=metersphere --format '{{.Status}}')

    if echo "$CONTAINER_STATUS" | grep -q "healthy"; then
        log_success "容器启动成功并已健康"
    elif echo "$CONTAINER_STATUS" | grep -q "Up"; then
        log_warning "容器已启动，但健康检查尚未通过，请稍后再检查"
    else
        log_error "容器启动失败，状态: $CONTAINER_STATUS"
        log_info "查看日志: docker logs metersphere"
        exit 1
    fi

    # 测试 HTTP 访问
    log_info "测试 HTTP 访问..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081 || echo "000")

    if [ "$HTTP_CODE" = "200" ]; then
        log_success "HTTP 访问正常（状态码: 200）"
    else
        log_warning "HTTP 访问异常（状态码: $HTTP_CODE），请等待应用完全启动"
    fi

    log_success "部署完成"
    print_separator
else
    log_warning "跳过部署步骤"
    print_separator
fi

# =============================================================================
# 完成总结
# =============================================================================

echo ""
log_success "========== 🎉 所有步骤完成 =========="
echo ""

if [ "$BUILD_ONLY" = true ]; then
    log_info "✅ Docker 镜像已构建: ${IMAGE_NAME}:${IMAGE_TAG}"
    log_info "   镜像 ID: ${IMAGE_ID}"
    log_info "   镜像大小: ${IMAGE_SIZE}"
elif [ "$SKIP_DEPLOY" = true ]; then
    log_info "✅ 源码已编译"
    log_info "✅ Docker 镜像已构建: ${IMAGE_NAME}:${IMAGE_TAG}"
    log_info ""
    log_info "手动部署命令:"
    echo "   cd $DEPLOY_DIR"
    echo "   docker stop metersphere && docker rm metersphere"
    echo "   MS_MYSQL_HOST=mysql MS_KAFKA_HOST=kafka MS_REDIS_HOST=redis MS_MINIO_HOST=minio MS_MINIO_ENDPOINT=\"http://minio:9000\" \\"
    echo "     docker-compose -f docker-compose-base.yml -f docker-compose-metersphere.yml up -d metersphere"
else
    log_info "✅ 源码已编译"
    log_info "✅ Docker 镜像已构建"
    log_info "✅ 服务已部署"
    echo ""
    log_info "访问地址: http://localhost:8081"
    log_info "查看状态: docker ps --filter name=metersphere"
    log_info "查看日志: docker logs -f metersphere"
fi

echo ""
log_info "=================================================="
