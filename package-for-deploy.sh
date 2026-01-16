#!/bin/bash

###############################################################################
# MeterSphere 部署包打包脚本
#
# 功能：
#   打包编译产物和配置文件，用于远程部署
#
# 使用方法：
#   ./package-for-deploy.sh              # 打包当前编译产物
#   ./package-for-deploy.sh --compile    # 先编译再打包
#
# 输出：
#   metersphere-deploy-YYYYMMDD-HHMMSS.tar.gz
#
###############################################################################

set -e  # 遇到错误立即退出

# =============================================================================
# 配置变量
# =============================================================================

SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
PACKAGE_NAME="metersphere-deploy-${TIMESTAMP}"
PACKAGE_DIR="${SOURCE_DIR}/${PACKAGE_NAME}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

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
    echo "║       MeterSphere 部署包打包脚本 v1.0                       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
}

# =============================================================================
# 参数解析
# =============================================================================

DO_COMPILE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --compile)
            DO_COMPILE=true
            shift
            ;;
        -h|--help)
            echo "使用方法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --compile     先编译源码再打包"
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

cd "$SOURCE_DIR"

# 如果需要编译
if [ "$DO_COMPILE" = true ]; then
    log_step "步骤 1: 编译源码..."
    ./compile-only.sh
    print_separator
fi

# 检查编译产物
log_step "步骤 2: 检查编译产物..."

if [ ! -d "backend/app/target/dependency" ]; then
    log_error "编译产物不存在: backend/app/target/dependency"
    log_info "请先执行: ./compile-only.sh"
    exit 1
fi

log_success "编译产物检查通过"
print_separator

# 创建打包目录
log_step "步骤 3: 创建打包目录..."

if [ -d "$PACKAGE_DIR" ]; then
    rm -rf "$PACKAGE_DIR"
fi
mkdir -p "$PACKAGE_DIR"

log_success "打包目录已创建: $PACKAGE_DIR"
print_separator

# 复制文件
log_step "步骤 4: 复制文件..."

# 编译产物
log_info "复制编译产物..."
cp -r backend/app/target/dependency "$PACKAGE_DIR/"
DEPENDENCY_SIZE=$(du -sh "$PACKAGE_DIR/dependency" | cut -f1)
log_success "编译产物: $DEPENDENCY_SIZE"

# Dockerfile
log_info "复制 Dockerfile..."
cp Dockerfile "$PACKAGE_DIR/"

# shells 目录
if [ -d "shells" ]; then
    log_info "复制 shells 目录..."
    cp -r shells "$PACKAGE_DIR/"
else
    log_warning "shells 目录不存在，跳过"
fi

# redisson.yml
if [ -f "redisson.yml" ]; then
    log_info "复制 redisson.yml..."
    cp redisson.yml "$PACKAGE_DIR/"
else
    log_warning "redisson.yml 不存在，跳过"
fi

# 静态资源
if [ -d "backend/app/src/main/resources/static" ]; then
    log_info "复制静态资源..."
    mkdir -p "$PACKAGE_DIR/backend/app/src/main/resources"
    cp -r backend/app/src/main/resources/static "$PACKAGE_DIR/backend/app/src/main/resources/"
fi

# 前端资源
if [ -d "frontend/public" ]; then
    log_info "复制前端资源..."
    mkdir -p "$PACKAGE_DIR/frontend"
    cp -r frontend/public "$PACKAGE_DIR/frontend/"
fi

# 远程部署脚本
if [ -f "remote-deploy.sh" ]; then
    log_info "复制远程部署脚本..."
    cp remote-deploy.sh "$PACKAGE_DIR/"
    chmod +x "$PACKAGE_DIR/remote-deploy.sh"
fi

# 部署指南
if [ -f "REMOTE_DEPLOY_GUIDE.md" ]; then
    log_info "复制部署指南..."
    cp REMOTE_DEPLOY_GUIDE.md "$PACKAGE_DIR/"
fi

log_success "文件复制完成"
print_separator

# 生成 README
log_step "步骤 5: 生成部署说明..."

cat > "$PACKAGE_DIR/README.txt" << EOF
===============================================================================
MeterSphere 部署包
===============================================================================

打包时间: $(date '+%Y-%m-%d %H:%M:%S')
打包机器: $(hostname)
包名称: ${PACKAGE_NAME}.tar.gz

===============================================================================
目录结构
===============================================================================

dependency/                    # 编译产物（已解压的 jar 文件）
  ├── BOOT-INF/
  │   ├── classes/            # 编译后的 class 文件
  │   └── lib/                # 依赖库
  └── META-INF/               # 元数据

Dockerfile                     # Docker 构建文件
shells/                        # 启动脚本
redisson.yml                   # Redis 配置
backend/app/src/main/resources/static/  # 静态资源
frontend/public/               # 前端资源

remote-deploy.sh               # 远程部署脚本（推荐使用）
REMOTE_DEPLOY_GUIDE.md         # 详细部署指南
README.txt                     # 本文件

===============================================================================
快速部署步骤
===============================================================================

1. 传输到目标服务器:

   scp ${PACKAGE_NAME}.tar.gz user@remote-server:/tmp/

2. 在目标服务器上解压:

   cd /tmp
   mkdir -p metersphere-build
   cd metersphere-build
   tar -xzf /tmp/${PACKAGE_NAME}.tar.gz

3. 执行部署（推荐使用脚本）:

   chmod +x remote-deploy.sh
   ./remote-deploy.sh

   或手动执行:

   # 构建镜像
   docker build -f Dockerfile -t metersphere-custom:latest .
   docker tag metersphere-custom:latest \\
     registry.fit2cloud.com/metersphere/metersphere-ce:v3.6.3-lts

   # 部署服务
   cd /opt/metersphere
   docker stop metersphere && docker rm metersphere
   MS_MYSQL_HOST=mysql \\
   MS_KAFKA_HOST=kafka \\
   MS_REDIS_HOST=redis \\
   MS_MINIO_HOST=minio \\
   MS_MINIO_ENDPOINT="http://minio:9000" \\
   docker-compose -f docker-compose-base.yml \\
                  -f docker-compose-metersphere.yml \\
                  up -d metersphere

4. 验证部署:

   docker ps --filter name=metersphere
   curl -I http://localhost:8081

===============================================================================
详细文档
===============================================================================

查看 REMOTE_DEPLOY_GUIDE.md 获取完整的部署指南，包括：
  • 多种传输方式
  • 详细的部署步骤
  • 故障排查方法
  • 最佳实践建议

===============================================================================
技术支持
===============================================================================

问题反馈: https://github.com/metersphere/metersphere/issues
官方文档: https://metersphere.io/docs/

===============================================================================
EOF

log_success "部署说明已生成"
print_separator

# 统计文件
log_step "步骤 6: 统计文件..."

FILE_COUNT=$(find "$PACKAGE_DIR" -type f | wc -l | tr -d ' ')
TOTAL_SIZE=$(du -sh "$PACKAGE_DIR" | cut -f1)

log_info "文件数量: $FILE_COUNT"
log_info "总大小: $TOTAL_SIZE"
print_separator

# 打包压缩
log_step "步骤 7: 打包压缩..."

log_info "创建 tar.gz 压缩包..."
cd "$SOURCE_DIR"
tar -czf "${PACKAGE_NAME}.tar.gz" -C "$PACKAGE_DIR" .

if [ ! -f "${PACKAGE_NAME}.tar.gz" ]; then
    log_error "打包失败"
    exit 1
fi

PACKAGE_SIZE=$(du -h "${PACKAGE_NAME}.tar.gz" | cut -f1)

log_success "打包完成"
print_separator

# 清理临时目录
log_step "步骤 8: 清理临时文件..."

rm -rf "$PACKAGE_DIR"

log_success "临时文件已清理"
print_separator

# =============================================================================
# 完成总结
# =============================================================================

echo ""
log_success "========== 🎉 打包完成 =========="
echo ""
log_info "📦 部署包信息:"
echo "   • 文件名: ${PACKAGE_NAME}.tar.gz"
echo "   • 大小: $PACKAGE_SIZE"
echo "   • 位置: $SOURCE_DIR/${PACKAGE_NAME}.tar.gz"
echo "   • 包含文件: $FILE_COUNT 个"
echo ""
log_info "📤 传输到远程服务器:"
echo "   scp ${PACKAGE_NAME}.tar.gz user@remote-server:/tmp/"
echo ""
log_info "🚀 在远程服务器上部署:"
echo "   cd /tmp && mkdir metersphere-build && cd metersphere-build"
echo "   tar -xzf /tmp/${PACKAGE_NAME}.tar.gz"
echo "   chmod +x remote-deploy.sh"
echo "   ./remote-deploy.sh"
echo ""
log_info "📚 详细文档: REMOTE_DEPLOY_GUIDE.md"
echo ""
print_separator

# 生成传输命令文件
cat > "${PACKAGE_NAME}-deploy-commands.txt" << EOF
# MeterSphere 远程部署命令
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')

# 1. 传输部署包到远程服务器（替换 user@remote-server）
scp ${PACKAGE_NAME}.tar.gz user@remote-server:/tmp/

# 2. SSH 登录到远程服务器
ssh user@remote-server

# 3. 在远程服务器上执行以下命令
cd /tmp
mkdir -p metersphere-build
cd metersphere-build
tar -xzf /tmp/${PACKAGE_NAME}.tar.gz
chmod +x remote-deploy.sh
./remote-deploy.sh

# 4. 验证部署
docker ps --filter name=metersphere
docker logs -f metersphere
curl -I http://localhost:8081

# 5. 访问 Web 界面
# http://服务器IP:8081
# 用户名: admin
# 密码: metersphere
EOF

log_info "📝 部署命令已保存到: ${PACKAGE_NAME}-deploy-commands.txt"
echo ""
