# MeterSphere 脚本快速参考

## 📚 脚本总览

| 脚本名称 | 功能 | 使用场景 |
|---------|------|----------|
| **compile-only.sh** | 仅编译源码 | 需要打包部署到远程服务器 |
| **package-for-deploy.sh** | 打包部署文件 | 准备传输到远程服务器 |
| **remote-deploy.sh** | 远程服务器部署 | 在目标服务器上执行 |
| **build-and-deploy.sh** | 一键本地部署 | 本地开发和测试 |

---

## 🎯 使用场景速查

### 场景 1: 本地开发 - 完整构建部署

**需求**: 修改了代码，想在本地测试

```bash
cd /Users/huawen.li/IdeaProjects/metersphere_github/metersphere
./build-and-deploy.sh
```

**耗时**: 7-10 分钟
**结果**: 代码编译 → 构建镜像 → 本地部署

---

### 场景 2: 本地开发 - 快速重建

**需求**: 代码未修改，只需重新打包部署

```bash
./build-and-deploy.sh --skip-compile
```

**耗时**: 2-3 分钟
**结果**: 跳过编译 → 构建镜像 → 本地部署

---

### 场景 3: 远程部署 - 完整流程

**需求**: 在本地编译，部署到远程服务器

#### 开发机器操作：

```bash
# 1. 编译源码
./compile-only.sh

# 2. 打包部署文件
./package-for-deploy.sh

# 3. 传输到远程服务器
scp metersphere-deploy-*.tar.gz user@remote-server:/tmp/
```

#### 目标服务器操作：

```bash
# 1. 解压部署包
cd /tmp && mkdir metersphere-build && cd metersphere-build
tar -xzf /tmp/metersphere-deploy-*.tar.gz

# 2. 执行部署
./remote-deploy.sh
```

**开发机耗时**: 8-10 分钟（编译 + 打包）
**传输耗时**: 5-10 分钟（取决于网络）
**部署耗时**: 2-3 分钟（构建 + 部署）

---

### 场景 4: 远程部署 - 一键打包

**需求**: 直接编译并打包，一步到位

```bash
./package-for-deploy.sh --compile
```

**耗时**: 8-10 分钟
**结果**: 编译 + 打包，生成 `.tar.gz` 文件

---

### 场景 5: 只编译不部署

**需求**: 只想编译代码，不部署

```bash
./compile-only.sh
```

**耗时**: 7-8 分钟
**结果**: 编译完成，产物在 `backend/app/target/`

---

### 场景 6: 清理重编译

**需求**: 完全清理后重新编译

```bash
./compile-only.sh --clean
```

**耗时**: 8-10 分钟
**结果**: 执行 `mvn clean` 后重新编译

---

## 📋 脚本详细参数

### compile-only.sh

```bash
./compile-only.sh              # 正常编译
./compile-only.sh --clean      # 清理后重新编译
./compile-only.sh --help       # 显示帮助信息
```

**输出**:
- `backend/app/target/app-3.x.jar` - 编译产物
- `backend/app/target/dependency/` - 解压后的文件
- `backend/app/target/DEPLOY_INFO.txt` - 部署信息

---

### package-for-deploy.sh

```bash
./package-for-deploy.sh              # 打包当前编译产物
./package-for-deploy.sh --compile    # 先编译再打包
./package-for-deploy.sh --help       # 显示帮助信息
```

**输出**:
- `metersphere-deploy-YYYYMMDD-HHMMSS.tar.gz` - 部署包
- `metersphere-deploy-YYYYMMDD-HHMMSS-deploy-commands.txt` - 部署命令

**包含内容**:
- dependency/ - 编译产物
- Dockerfile - 构建文件
- shells/ - 启动脚本
- redisson.yml - Redis 配置
- remote-deploy.sh - 部署脚本
- REMOTE_DEPLOY_GUIDE.md - 部署指南
- README.txt - 使用说明

---

### remote-deploy.sh

```bash
./remote-deploy.sh              # 完整部署（构建+部署）
./remote-deploy.sh --skip-build # 跳过构建，直接部署
./remote-deploy.sh --help       # 显示帮助信息
```

**前提条件**:
- 已解压部署包到当前目录
- Docker 和 docker-compose 已安装
- /opt/metersphere 目录已初始化

---

### build-and-deploy.sh

```bash
./build-and-deploy.sh                  # 完整流程
./build-and-deploy.sh --skip-compile   # 跳过编译
./build-and-deploy.sh --skip-deploy    # 只构建不部署
./build-and-deploy.sh --build-only     # 只构建镜像
./build-and-deploy.sh --help           # 显示帮助信息
```

---

## 🔄 工作流程图

### 本地开发流程

```
修改代码
    ↓
./build-and-deploy.sh
    ↓
┌─────────────────┐
│ 编译源码        │ (5-7分钟)
└────────┬────────┘
         ↓
┌─────────────────┐
│ 构建镜像        │ (1-2分钟)
└────────┬────────┘
         ↓
┌─────────────────┐
│ 本地部署        │ (30秒)
└────────┬────────┘
         ↓
   http://localhost:8081
```

---

### 远程部署流程

```
┌────────────────────────────────────────┐
│           开发机器                      │
│                                        │
│  ./compile-only.sh                    │
│       ↓                               │
│  ./package-for-deploy.sh              │
│       ↓                               │
│  metersphere-deploy-*.tar.gz          │
└───────────────┬────────────────────────┘
                │ scp/rsync 传输
                ↓
┌────────────────────────────────────────┐
│           目标服务器                    │
│                                        │
│  tar -xzf metersphere-deploy-*.tar.gz │
│       ↓                               │
│  ./remote-deploy.sh                   │
│       ↓                               │
│  http://服务器IP:8081                 │
└────────────────────────────────────────┘
```

---

## 💡 最佳实践

### 1. 开发阶段

**推荐**: 使用 `build-and-deploy.sh`

```bash
# 首次使用
./build-and-deploy.sh

# 后续快速迭代
./build-and-deploy.sh --skip-compile
```

---

### 2. 生产部署

**推荐**: 使用打包脚本 + 远程部署

```bash
# 开发机
./package-for-deploy.sh --compile
scp metersphere-deploy-*.tar.gz prod-server:/tmp/

# 生产服务器
cd /tmp/metersphere-build
tar -xzf /tmp/metersphere-deploy-*.tar.gz
./remote-deploy.sh
```

---

### 3. 持续集成

**推荐**: 分离编译和部署

```bash
# CI 阶段 1: 编译
./compile-only.sh

# CI 阶段 2: 打包
./package-for-deploy.sh

# CD 阶段: 部署
# 传输到目标服务器后执行
./remote-deploy.sh
```

---

## 📁 文件结构

执行完所有脚本后的文件结构：

```
metersphere/
├── compile-only.sh              # 编译脚本
├── package-for-deploy.sh        # 打包脚本
├── remote-deploy.sh             # 远程部署脚本
├── build-and-deploy.sh          # 本地一键部署脚本
│
├── backend/app/target/
│   ├── app-3.x.jar             # 编译产物 (336MB)
│   ├── dependency/             # 解压的文件
│   └── DEPLOY_INFO.txt         # 部署信息
│
├── metersphere-deploy-*.tar.gz         # 部署包 (300-400MB)
├── metersphere-deploy-*-commands.txt   # 部署命令
│
└── REMOTE_DEPLOY_GUIDE.md      # 远程部署指南
```

---

## ⏱️ 时间估算

| 操作 | 时间 | 备注 |
|------|------|------|
| 编译源码 | 5-8 分钟 | 取决于机器性能 |
| 解压 jar | 10-20 秒 | |
| 构建镜像 | 1-2 分钟 | Docker 缓存影响 |
| 打包部署文件 | 30-60 秒 | |
| 传输部署包 | 5-15 分钟 | 取决于网络速度 |
| 远程构建部署 | 2-3 分钟 | |

**总计**:
- 本地完整部署: 7-10 分钟
- 远程完整部署: 13-25 分钟

---

## 🔍 故障排查

### 问题 1: 编译失败

```bash
# 检查 Java 版本
java -version  # 应该是 Java 21

# 清理后重新编译
./compile-only.sh --clean
```

---

### 问题 2: 镜像构建失败

```bash
# 检查 Dockerfile 和依赖文件是否存在
ls -la Dockerfile shells/ redisson.yml

# 检查 dependency 目录
ls -la backend/app/target/dependency/BOOT-INF/
```

---

### 问题 3: 部署失败

```bash
# 查看容器日志
docker logs metersphere

# 检查环境变量
docker exec metersphere env | grep -E "(MYSQL|REDIS|KAFKA|MINIO)"

# 检查网络连接
docker exec metersphere ping -c 2 mysql
```

---

### 问题 4: 文件传输中断

```bash
# 使用 rsync 支持断点续传
rsync -avz --progress --partial metersphere-deploy-*.tar.gz user@remote:/tmp/
```

---

## 📞 获取帮助

每个脚本都支持 `--help` 参数：

```bash
./compile-only.sh --help
./package-for-deploy.sh --help
./remote-deploy.sh --help
./build-and-deploy.sh --help
```

---

## 📚 相关文档

- [BUILD_DEPLOY_README.md](BUILD_DEPLOY_README.md) - 本地部署详细指南
- [REMOTE_DEPLOY_GUIDE.md](REMOTE_DEPLOY_GUIDE.md) - 远程部署详细指南
- [UPDATE_COMPONENTS_GUIDE.md](UPDATE_COMPONENTS_GUIDE.md) - 组件更新指南

---

## 🎓 快速记忆

**本地开发**: `./build-and-deploy.sh`
**远程部署**: `./package-for-deploy.sh --compile` + 传输 + `./remote-deploy.sh`
**只编译**: `./compile-only.sh`
**帮助信息**: `./脚本名 --help`

---

**版本**: v1.0
**更新时间**: 2026-01-16
**维护者**: MeterSphere Development Team
