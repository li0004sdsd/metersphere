# MeterSphere 一键编译构建部署脚本使用指南

## 📋 脚本功能

`build-and-deploy.sh` 脚本提供以下功能：

1. ✅ **源码编译** - 使用 Java 21 编译项目
2. ✅ **jar 解压** - 自动解压编译产物
3. ✅ **镜像构建** - 构建 Docker 镜像
4. ✅ **服务部署** - 部署到 /opt/metersphere

## 🚀 快速开始

### 方式一：完整流程（推荐）

编译 + 构建 + 部署一条龙服务：

```bash
cd /Users/huawen.li/IdeaProjects/metersphere_github/metersphere
./build-and-deploy.sh
```

**执行时间**: 约 5-10 分钟（取决于机器性能）

---

### 方式二：跳过编译

如果代码没有修改，只想重新构建和部署：

```bash
./build-and-deploy.sh --skip-compile
```

**执行时间**: 约 2-3 分钟

---

### 方式三：只编译和构建

只编译和构建镜像，不部署到服务器：

```bash
./build-and-deploy.sh --skip-deploy
```

**使用场景**:
- 先构建镜像，稍后再部署
- 构建镜像用于分发到其他服务器

---

### 方式四：只构建镜像

跳过编译，只从已解压的文件构建镜像：

```bash
./build-and-deploy.sh --build-only
```

**使用场景**:
- 已经编译过，只需要重新打包镜像
- 修改了 Dockerfile，需要重新构建

---

## 📊 执行流程

```
┌─────────────────────────────────────────────────┐
│  步骤 1: 编译源码                                │
│  ├─ 设置 Java 21 环境                           │
│  ├─ 执行 mvn clean package -DskipTests          │
│  └─ 生成 backend/app/target/app-3.x.jar        │
└─────────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────┐
│  步骤 2: 解压 jar 包                             │
│  ├─ 创建 dependency 目录                        │
│  ├─ 解压 jar 文件                               │
│  └─ 生成 BOOT-INF/classes 和 lib               │
└─────────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────┐
│  步骤 3: 构建 Docker 镜像                        │
│  ├─ 执行 docker build                           │
│  ├─ 生成 metersphere-custom:latest             │
│  └─ 打标签为官方镜像名                          │
└─────────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────┐
│  步骤 4: 部署服务                                │
│  ├─ 停止并删除旧容器                            │
│  ├─ 使用正确的环境变量启动新容器                │
│  ├─ 等待健康检查通过                            │
│  └─ 测试 HTTP 访问                              │
└─────────────────────────────────────────────────┘
```

---

## ⚙️ 配置说明

脚本中的关键配置（位于脚本开头）：

```bash
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
```

如果这些路径在你的环境中不同，请修改脚本开头的配置变量。

---

## ✅ 成功示例

```bash
$ ./build-and-deploy.sh

==================================================================
[INFO] 开始环境检查...
[SUCCESS] 环境检查通过
==================================================================
[INFO] 步骤 1/4: 编译源码...
[INFO] 使用 Java 版本: openjdk version "21.0.9"
[INFO] 执行 Maven 编译（跳过测试）...
[BUILD SUCCESS]
[SUCCESS] 源码编译完成
==================================================================
[INFO] 步骤 2/4: 解压 jar 包...
[INFO] 解压 app-3.x.jar...
[SUCCESS] jar 包解压完成
==================================================================
[INFO] 步骤 3/4: 构建 Docker 镜像...
[INFO] 构建镜像: metersphere-custom:latest
[SUCCESS] Docker 镜像构建完成
[INFO] 镜像 ID: 4ffb6fc2f1cc
[INFO] 镜像大小: 1.2GB
==================================================================
[INFO] 步骤 4/4: 部署到服务器...
[INFO] 停止并删除旧的 metersphere 容器...
[INFO] 启动新的 metersphere 容器...
[INFO] 等待容器启动（30秒）...
[SUCCESS] 容器启动成功并已健康
[INFO] 测试 HTTP 访问...
[SUCCESS] HTTP 访问正常（状态码: 200）
[SUCCESS] 部署完成
==================================================================

[SUCCESS] ========== 🎉 所有步骤完成 ==========

[INFO] ✅ 源码已编译
[INFO] ✅ Docker 镜像已构建
[INFO] ✅ 服务已部署

[INFO] 访问地址: http://localhost:8081
[INFO] 查看状态: docker ps --filter name=metersphere
[INFO] 查看日志: docker logs -f metersphere

[INFO] ==================================================
```

---

## ⚠️ 常见问题

### 1. 编译失败：Java 版本错误

**错误信息**:
```
class file version 61.0, this version of the Java Runtime only recognizes class file versions up to 52.0
```

**解决方案**:
检查 Java 21 是否正确安装：
```bash
/opt/homebrew/Cellar/openjdk@21/21.0.9/libexec/openjdk.jdk/Contents/Home/bin/java -version
```

---

### 2. Docker 构建失败：缺少 shells 目录

**错误信息**:
```
ERROR: shells/metersphere.sh 不存在
```

**解决方案**:
确保 shells 目录和启动脚本存在：
```bash
ls -la /Users/huawen.li/IdeaProjects/metersphere_github/metersphere/shells/
```

如果不存在，脚本会自动检测并提示。

---

### 3. 容器启动失败：环境变量错误

**错误信息**:
```
Communications link failure
```

**原因**: Shell 环境变量覆盖了 docker-compose 配置

**解决方案**:
脚本已自动处理，会在启动时显式设置正确的环境变量：
```bash
MS_MYSQL_HOST=mysql \
MS_KAFKA_HOST=kafka \
MS_REDIS_HOST=redis \
MS_MINIO_HOST=minio \
MS_MINIO_ENDPOINT="http://minio:9000"
```

---

### 4. 查看详细日志

如果部署后出现问题，查看容器日志：

```bash
# 查看最近的日志
docker logs metersphere --tail 100

# 实时跟踪日志
docker logs -f metersphere

# 查看错误日志文件
docker exec metersphere cat /opt/metersphere/logs/metersphere/error.log
```

---

## 🔧 手动部署命令

如果使用 `--skip-deploy` 选项，可以稍后手动部署：

```bash
cd /opt/metersphere

# 停止旧容器
docker stop metersphere && docker rm metersphere

# 启动新容器
MS_MYSQL_HOST=mysql \
MS_KAFKA_HOST=kafka \
MS_REDIS_HOST=redis \
MS_MINIO_HOST=minio \
MS_MINIO_ENDPOINT="http://minio:9000" \
docker-compose -f docker-compose-base.yml \
               -f docker-compose-metersphere.yml \
               up -d metersphere

# 检查状态
docker ps --filter name=metersphere
```

---

## 📝 开发工作流

### 场景 1: 修改了主服务代码

```bash
# 完整流程
cd /Users/huawen.li/IdeaProjects/metersphere_github/metersphere
./build-and-deploy.sh
```

### 场景 2: 只修改了 Dockerfile

```bash
# 跳过编译，直接构建和部署
./build-and-deploy.sh --skip-compile
```

### 场景 3: 测试环境构建

```bash
# 只构建镜像，不部署
./build-and-deploy.sh --skip-deploy

# 稍后部署到测试服务器
docker save metersphere-custom:latest | gzip > metersphere-custom.tar.gz
scp metersphere-custom.tar.gz test-server:/tmp/
```

---

## 🎯 验证部署成功

### 1. 检查容器状态

```bash
docker ps --filter name=metersphere --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
```

期望输出:
```
NAMES         STATUS                    IMAGE
metersphere   Up 2 minutes (healthy)    registry.fit2cloud.com/metersphere/metersphere-ce:v3.6.3-lts
```

### 2. 测试 HTTP 访问

```bash
curl -I http://localhost:8081
```

期望输出:
```
HTTP/1.1 200 OK
```

### 3. 访问 Web 界面

浏览器访问: **http://localhost:8081**

默认登录凭据:
- 用户名: `admin`
- 密码: `metersphere`

---

## 📚 相关文档

- [UPDATE_COMPONENTS_GUIDE.md](UPDATE_COMPONENTS_GUIDE.md) - 组件更新指南
- [SOURCE_TO_DEPLOYMENT_ANALYSIS.md](SOURCE_TO_DEPLOYMENT_ANALYSIS.md) - 源码到部署分析
- [DOCKERFILE_COMPARISON.md](DOCKERFILE_COMPARISON.md) - Dockerfile 对比

---

## 💡 提示

1. **首次使用**: 建议使用完整流程 `./build-and-deploy.sh`
2. **快速迭代**: 如果只修改了前端或少量代码，使用 `--skip-compile` 可以节省时间
3. **持续集成**: 可以将此脚本集成到 CI/CD 流程中
4. **版本管理**: 建议每次构建后为镜像打上版本标签

---

**版本**: v1.0
**更新时间**: 2026-01-16
**维护者**: MeterSphere Development Team
