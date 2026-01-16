# MeterSphere 远程服务器部署指南

## 📋 概述

本指南详细说明如何将在开发机器上编译的 MeterSphere 部署到远程服务器。

**适用场景**：
- 开发机器编译，生产服务器部署
- 持续集成/持续部署（CI/CD）
- 多台服务器批量部署

---

## 🔄 完整流程

```
┌─────────────────┐
│  开发机器        │
│  1. 编译源码     │
│  2. 打包产物     │
└────────┬────────┘
         │ 传输文件
         ↓
┌─────────────────┐
│  目标服务器      │
│  3. 构建镜像     │
│  4. 部署容器     │
└─────────────────┘
```

---

## 📦 方式一：传输编译产物（推荐）

### 步骤 1: 在开发机器上编译

```bash
cd /Users/huawen.li/IdeaProjects/metersphere_github/metersphere

# 执行编译
./compile-only.sh

# 查看编译结果
cat backend/app/target/DEPLOY_INFO.txt
```

### 步骤 2: 打包需要传输的文件

```bash
# 创建部署包目录
mkdir -p deploy-package

# 复制编译产物
cp -r backend/app/target/dependency deploy-package/

# 复制配置文件
cp Dockerfile deploy-package/
cp redisson.yml deploy-package/
cp -r shells deploy-package/
cp -r backend/app/src/main/resources/static deploy-package/ 2>/dev/null || true
cp -r frontend/public deploy-package/ 2>/dev/null || true

# 复制远程部署脚本
cp remote-deploy.sh deploy-package/

# 打包压缩
cd deploy-package
tar -czf ../metersphere-deploy-$(date +%Y%m%d-%H%M%S).tar.gz .
cd ..

echo "部署包已生成: metersphere-deploy-*.tar.gz"
ls -lh metersphere-deploy-*.tar.gz
```

**部署包大小**: 约 300-400 MB

### 步骤 3: 传输到目标服务器

**方法 A: 使用 scp**

```bash
# 传输部署包
scp metersphere-deploy-*.tar.gz user@remote-server:/tmp/

# 登录到远程服务器
ssh user@remote-server
```

**方法 B: 使用 rsync（更快，支持断点续传）**

```bash
# 传输部署包
rsync -avz --progress metersphere-deploy-*.tar.gz user@remote-server:/tmp/

# 登录到远程服务器
ssh user@remote-server
```

**方法 C: 使用内网共享目录**

```bash
# 如果有 NFS 或 SMB 共享
cp metersphere-deploy-*.tar.gz /mnt/shared/
```

### 步骤 4: 在目标服务器上解压

```bash
# 登录到目标服务器后
cd /tmp

# 创建工作目录
mkdir -p ~/metersphere-build
cd ~/metersphere-build

# 解压部署包
tar -xzf /tmp/metersphere-deploy-*.tar.gz

# 查看文件
ls -la
```

### 步骤 5: 构建 Docker 镜像

```bash
cd ~/metersphere-build

# 构建镜像
docker build -f Dockerfile -t metersphere-custom:latest .

# 打标签（匹配 docker-compose 配置）
docker tag metersphere-custom:latest registry.fit2cloud.com/metersphere/metersphere-ce:v3.6.3-lts

# 查看镜像
docker images | grep metersphere
```

### 步骤 6: 部署服务

```bash
# 使用远程部署脚本（推荐）
chmod +x remote-deploy.sh
./remote-deploy.sh

# 或者手动部署
cd /opt/metersphere
docker stop metersphere && docker rm metersphere
MS_MYSQL_HOST=mysql \
MS_KAFKA_HOST=kafka \
MS_REDIS_HOST=redis \
MS_MINIO_HOST=minio \
MS_MINIO_ENDPOINT="http://minio:9000" \
docker-compose -f docker-compose-base.yml \
               -f docker-compose-metersphere.yml \
               up -d metersphere
```

### 步骤 7: 验证部署

```bash
# 检查容器状态
docker ps --filter name=metersphere

# 查看日志
docker logs -f metersphere

# 测试访问
curl -I http://localhost:8081

# 等待健康检查通过（约30-60秒）
watch -n 2 'docker ps --filter name=metersphere --format "{{.Status}}"'
```

---

## 🖼️ 方式二：传输 Docker 镜像

适用于无法在目标服务器编译，或者需要保证环境一致性的场景。

### 步骤 1: 在开发机器上构建镜像

```bash
cd /Users/huawen.li/IdeaProjects/metersphere_github/metersphere

# 完整构建（包括编译）
./build-and-deploy.sh --skip-deploy

# 或使用已编译的产物构建
./build-and-deploy.sh --build-only
```

### 步骤 2: 导出镜像

```bash
# 导出为 tar.gz 文件（推荐）
docker save metersphere-custom:latest | gzip > metersphere-custom-$(date +%Y%m%d).tar.gz

# 查看文件大小
ls -lh metersphere-custom-*.tar.gz
```

**镜像文件大小**: 约 400-500 MB（压缩后）

### 步骤 3: 传输镜像到目标服务器

```bash
# 使用 scp
scp metersphere-custom-*.tar.gz user@remote-server:/tmp/

# 或使用 rsync（推荐，支持断点续传）
rsync -avz --progress metersphere-custom-*.tar.gz user@remote-server:/tmp/
```

### 步骤 4: 在目标服务器导入镜像

```bash
# 登录到远程服务器
ssh user@remote-server

# 导入镜像
docker load < /tmp/metersphere-custom-*.tar.gz

# 打标签
docker tag metersphere-custom:latest registry.fit2cloud.com/metersphere/metersphere-ce:v3.6.3-lts

# 验证镜像
docker images | grep metersphere
```

### 步骤 5: 部署服务

同方式一的步骤 6 和步骤 7。

---

## 🚀 方式三：一键远程部署脚本

适用于有 SSH 访问权限的场景，可以从开发机直接部署到远程服务器。

### 创建一键部署脚本

在开发机器上创建 `deploy-to-remote.sh`：

```bash
#!/bin/bash

# 配置
REMOTE_HOST="user@remote-server"
REMOTE_DIR="/tmp/metersphere-deploy"
DEPLOY_DIR="/opt/metersphere"

# 1. 本地编译
echo "=== 1. 本地编译 ==="
./compile-only.sh

# 2. 打包部署文件
echo "=== 2. 打包部署文件 ==="
mkdir -p deploy-package
cp -r backend/app/target/dependency deploy-package/
cp Dockerfile deploy-package/
cp redisson.yml deploy-package/
cp -r shells deploy-package/
cp -r backend/app/src/main/resources/static deploy-package/ 2>/dev/null || true
cp -r frontend/public deploy-package/ 2>/dev/null || true
cd deploy-package
tar -czf ../deploy.tar.gz .
cd ..

# 3. 传输到远程服务器
echo "=== 3. 传输到远程服务器 ==="
ssh $REMOTE_HOST "mkdir -p $REMOTE_DIR"
scp deploy.tar.gz $REMOTE_HOST:$REMOTE_DIR/

# 4. 远程构建和部署
echo "=== 4. 远程构建和部署 ==="
ssh $REMOTE_HOST << 'ENDSSH'
cd /tmp/metersphere-deploy
tar -xzf deploy.tar.gz

# 构建镜像
docker build -f Dockerfile -t metersphere-custom:latest .
docker tag metersphere-custom:latest registry.fit2cloud.com/metersphere/metersphere-ce:v3.6.3-lts

# 部署
cd /opt/metersphere
docker stop metersphere && docker rm metersphere
MS_MYSQL_HOST=mysql \
MS_KAFKA_HOST=kafka \
MS_REDIS_HOST=redis \
MS_MINIO_HOST=minio \
MS_MINIO_ENDPOINT="http://minio:9000" \
docker-compose -f docker-compose-base.yml \
               -f docker-compose-metersphere.yml \
               up -d metersphere

echo "部署完成！"
docker ps --filter name=metersphere
ENDSSH

echo "=== 5. 验证部署 ==="
ssh $REMOTE_HOST "sleep 30 && docker ps --filter name=metersphere"
```

### 使用方法

```bash
chmod +x deploy-to-remote.sh
./deploy-to-remote.sh
```

---

## 📊 传输方式对比

| 方式 | 文件大小 | 传输时间* | 优点 | 缺点 |
|------|---------|----------|------|------|
| **编译产物** | 300-400 MB | 5-10分钟 | • 灵活<br>• 可修改配置 | • 需要远程构建 |
| **Docker镜像** | 400-500 MB | 8-15分钟 | • 环境一致<br>• 无需远程构建 | • 文件较大 |
| **一键脚本** | 300-400 MB | 自动化 | • 全自动<br>• 省心 | • 需要SSH访问 |

\* 基于 100 Mbps 网络估算

---

## ⚙️ 环境变量配置

无论使用哪种方式，部署时都必须设置正确的环境变量：

```bash
MS_MYSQL_HOST=mysql              # MySQL 主机名
MS_KAFKA_HOST=kafka              # Kafka 主机名
MS_REDIS_HOST=redis              # Redis 主机名
MS_MINIO_HOST=minio              # MinIO 主机名
MS_MINIO_ENDPOINT=http://minio:9000  # MinIO 端点
```

**注意**:
- 使用容器名而不是 IP 地址
- 确保所有服务在同一个 Docker 网络中
- 如果使用外部服务，请使用实际的主机名或 IP

---

## 🔧 远程服务器部署脚本

在目标服务器上使用的 `remote-deploy.sh` 脚本（已包含在部署包中）：

```bash
#!/bin/bash
# 此脚本已自动包含在部署包中
# 使用方法: ./remote-deploy.sh

set -e

echo "=== MeterSphere 远程部署脚本 ==="

# 检查必要文件
if [ ! -f "Dockerfile" ]; then
    echo "错误: Dockerfile 不存在"
    exit 1
fi

if [ ! -d "dependency" ]; then
    echo "错误: dependency 目录不存在"
    exit 1
fi

# 构建镜像
echo "1. 构建 Docker 镜像..."
docker build -f Dockerfile -t metersphere-custom:latest .
docker tag metersphere-custom:latest registry.fit2cloud.com/metersphere/metersphere-ce:v3.6.3-lts

# 部署服务
echo "2. 部署服务..."
cd /opt/metersphere

docker stop metersphere 2>/dev/null || true
docker rm metersphere 2>/dev/null || true

MS_MYSQL_HOST=mysql \
MS_KAFKA_HOST=kafka \
MS_REDIS_HOST=redis \
MS_MINIO_HOST=minio \
MS_MINIO_ENDPOINT="http://minio:9000" \
docker-compose -f docker-compose-base.yml \
               -f docker-compose-metersphere.yml \
               up -d metersphere

# 等待启动
echo "3. 等待服务启动（30秒）..."
sleep 30

# 检查状态
echo "4. 检查服务状态..."
docker ps --filter name=metersphere --format 'table {{.Names}}\t{{.Status}}'

echo ""
echo "部署完成！"
echo "访问地址: http://服务器IP:8081"
```

---

## ✅ 验证清单

部署完成后，按以下清单验证：

- [ ] 容器状态为 `healthy`
  ```bash
  docker ps --filter name=metersphere
  ```

- [ ] 日志无错误
  ```bash
  docker logs metersphere | grep -i error
  ```

- [ ] HTTP 访问正常（状态码 200）
  ```bash
  curl -I http://localhost:8081
  ```

- [ ] Web 界面可访问
  - 访问: `http://服务器IP:8081`
  - 登录: admin / metersphere

- [ ] 数据库连接正常
  ```bash
  docker logs metersphere | grep "HikariPool"
  ```

- [ ] 所有依赖服务健康
  ```bash
  docker ps --format 'table {{.Names}}\t{{.Status}}' | grep -E "(mysql|redis|kafka|minio)"
  ```

---

## ⚠️ 常见问题

### 1. 传输中断怎么办？

**使用 rsync 支持断点续传**：

```bash
rsync -avz --progress --partial metersphere-deploy-*.tar.gz user@remote-server:/tmp/
```

### 2. 目标服务器网络受限

如果目标服务器无法访问外网：

1. 在开发机器上构建完整镜像
2. 导出镜像包括基础镜像：
   ```bash
   docker save metersphere-custom:latest \
               registry.fit2cloud.com/metersphere/alpine-openjdk21-jre:latest \
               | gzip > full-images.tar.gz
   ```

### 3. 磁盘空间不足

**清理旧镜像和容器**：

```bash
# 清理未使用的镜像
docker image prune -a

# 清理停止的容器
docker container prune

# 查看磁盘使用
docker system df
```

### 4. 权限问题

确保用户在 docker 组中：

```bash
sudo usermod -aG docker $USER
# 需要重新登录生效
```

---

## 📚 相关文档

- [compile-only.sh](compile-only.sh) - 纯编译脚本
- [build-and-deploy.sh](build-and-deploy.sh) - 一键本地部署脚本
- [BUILD_DEPLOY_README.md](BUILD_DEPLOY_README.md) - 本地部署指南
- [UPDATE_COMPONENTS_GUIDE.md](UPDATE_COMPONENTS_GUIDE.md) - 组件更新指南

---

## 💡 最佳实践

### 1. 版本管理

为每次部署的镜像打上版本标签：

```bash
VERSION=$(date +%Y%m%d-%H%M%S)
docker tag metersphere-custom:latest metersphere-custom:$VERSION
```

### 2. 回滚准备

部署前备份当前镜像：

```bash
docker tag registry.fit2cloud.com/metersphere/metersphere-ce:v3.6.3-lts \
           metersphere-backup:$(date +%Y%m%d)
```

### 3. 分阶段部署

1. 测试环境验证
2. 灰度发布（部分用户）
3. 全量部署

### 4. 监控部署

```bash
# 实时查看日志
docker logs -f metersphere

# 监控资源使用
docker stats metersphere
```

---

**版本**: v1.0
**更新时间**: 2026-01-16
**维护者**: MeterSphere Development Team
