#!/bin/bash

###############################################################################
# MeterSphere 远程服务器部署脚本
#
# 此脚本在目标服务器上执行，用于构建镜像和部署服务
#
# 前提条件：
#   1. 已将编译产物传输到目标服务器
#   2. 已解压部署包到当前目录
#   3. Docker 和 docker-compose 已安装
#   4. /opt/metersphere 目录已初始化
#
# 使用方法：
#   ./remote-deploy.sh
#   ./remote-deploy.sh --skip-build    # 跳过镜像构建，直接部署
#
###############################################################################

set -e  # 遇到错误立即退出

# =============================================================================
# 配置变量
# =============================================================================

# 部署目录
DEPLOY_DIR="/opt/metersphere"

# Docker 镜像名称
IMAGE_NAME="metersphere-custom"
IMAGE_TAG="latest"
OFFICIAL_IMAGE_TAG="registry.fit2cloud.com/metersphere/metersphere-ce:v3.6.3-lts"

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
    echo "║       MeterSphere 远程部署脚本 v1.0                         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
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

SKIP_BUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        -h|--help)
            echo "使用方法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --skip-build    跳过镜像构建，直接部署"
            echo "  -h, --help      显示此帮助信息"
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

# 环境检查
log_info "执行环境检查..."

check_command docker
check_command docker-compose

# 检查必要文件
CURRENT_DIR=$(pwd)

if [ "$SKIP_BUILD" = false ]; then
    if [ ! -f "Dockerfile" ]; then
        log_error "Dockerfile 不存在，请确保已解压部署包"
        exit 1
    fi

    if [ ! -d "dependency" ]; then
        log_error "dependency 目录不存在，请确保已解压部署包"
        exit 1
    fi
fi

# 检查部署目录
if [ ! -d "$DEPLOY_DIR" ]; then
    log_error "部署目录不存在: $DEPLOY_DIR"
    log_info "请先初始化 MeterSphere 环境"
    exit 1
fi

log_success "环境检查通过"
print_separator

# =============================================================================
# 步骤 1: 构建 Docker 镜像
# =============================================================================

if [ "$SKIP_BUILD" = false ]; then
    log_step "步骤 1/3: 构建 Docker 镜像..."

    log_info "当前目录: $CURRENT_DIR"
    log_info "开始构建镜像..."

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
else
    log_warning "跳过镜像构建步骤"

    # 检查镜像是否存在
    if ! docker images | grep -q "${IMAGE_NAME}"; then
        log_error "镜像不存在: ${IMAGE_NAME}:${IMAGE_TAG}"
        log_info "请先构建镜像或移除 --skip-build 选项"
        exit 1
    fi
    print_separator
fi

# =============================================================================
# 步骤 2: 停止旧容器
# =============================================================================

log_step "步骤 2/3: 停止旧容器..."

# 检查容器是否存在
if docker ps -a --format '{{.Names}}' | grep -q "^metersphere$"; then
    log_info "停止并删除旧的 metersphere 容器..."
    docker stop metersphere 2>/dev/null || true
    docker rm metersphere 2>/dev/null || true
    log_success "旧容器已删除"
else
    log_info "未发现旧容器，跳过删除步骤"
fi

print_separator

# =============================================================================
# 步骤 3: 部署新容器
# =============================================================================

log_step "步骤 3/3: 部署新容器..."

cd "$DEPLOY_DIR"

# 检查 docker-compose 文件
if [ ! -f "docker-compose-base.yml" ] || [ ! -f "docker-compose-metersphere.yml" ]; then
    log_error "docker-compose 配置文件不存在"
    exit 1
fi

log_info "启动新的 metersphere 容器..."

# 设置环境变量并启动
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

log_success "容器启动成功"
print_separator

# =============================================================================
# 步骤 4: 健康检查
# =============================================================================

log_step "步骤 4/4: 健康检查..."

log_info "等待容器启动（30秒）..."
sleep 30

# 检查容器状态
CONTAINER_STATUS=$(docker ps --filter name=metersphere --format '{{.Status}}')

if echo "$CONTAINER_STATUS" | grep -q "healthy"; then
    log_success "容器已启动并通过健康检查"
elif echo "$CONTAINER_STATUS" | grep -q "Up"; then
    log_warning "容器已启动，但健康检查尚未通过"
    log_info "可能需要等待更长时间，建议继续观察"
else
    log_error "容器启动异常，状态: $CONTAINER_STATUS"
    log_info "请检查日志: docker logs metersphere"
    exit 1
fi

# 显示容器信息
echo ""
log_info "容器信息:"
docker ps --filter name=metersphere --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

# 测试 HTTP 访问
echo ""
log_info "测试 HTTP 访问..."
sleep 10  # 再等待10秒让应用完全启动

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081 || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
    log_success "HTTP 访问正常（状态码: 200）"
elif [ "$HTTP_CODE" = "302" ]; then
    log_success "HTTP 访问正常（状态码: 302，重定向到登录页）"
else
    log_warning "HTTP 访问异常（状态码: $HTTP_CODE）"
    log_info "请等待应用完全启动后再试，或查看日志排查问题"
fi

print_separator

# =============================================================================
# 完成总结
# =============================================================================

echo ""
log_success "========== 🎉 部署完成 =========="
echo ""
log_info "✅ Docker 镜像: ${IMAGE_NAME}:${IMAGE_TAG}"
log_info "✅ 容器状态: $CONTAINER_STATUS"
log_info "✅ HTTP 状态: $HTTP_CODE"
echo ""
log_info "🌐 访问地址:"
echo "   • 本地: http://localhost:8081"
echo "   • 远程: http://$(hostname -I | awk '{print $1}'):8081"
echo ""
log_info "🔍 常用命令:"
echo "   • 查看状态: docker ps --filter name=metersphere"
echo "   • 查看日志: docker logs -f metersphere"
echo "   • 重启服务: docker restart metersphere"
echo "   • 停止服务: docker stop metersphere"
echo ""
log_info "📚 默认登录凭据:"
echo "   • 用户名: admin"
echo "   • 密码: metersphere"
echo ""
print_separator

# 如果有错误日志，显示最近的错误
ERROR_COUNT=$(docker logs metersphere 2>&1 | grep -i error | wc -l | tr -d ' ')
if [ "$ERROR_COUNT" -gt 0 ]; then
    log_warning "检测到 $ERROR_COUNT 条错误日志"
    log_info "查看完整日志: docker logs metersphere"
    echo ""
    log_info "最近的错误信息:"
    docker logs metersphere 2>&1 | grep -i error | tail -5
    echo ""
fi
