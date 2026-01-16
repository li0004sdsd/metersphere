# 源码打包后可更新的组件指南

## 🎯 快速结论

**源码项目打包后，使用原始 Dockerfile 只能更新 MeterSphere 主服务，无法更新 Task Runner 和 Result Hub。**

---

## 📊 可视化对比

### 当前部署的三个组件

```
┌─────────────────────────────────────────────────────────────┐
│          运行中的 MeterSphere 系统 (v3.6.7-lts)              │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────┐  ┌──────────────────┐  ┌───────────┐ │
│  │  metersphere     │  │  task-runner     │  │result-hub │ │
│  │  容器            │  │  容器            │  │容器       │ │
│  │                  │  │                  │  │           │ │
│  │  Main Class:     │  │  Main Class:     │  │Main Class:│ │
│  │  io.metersphere  │  │  io.metersphere  │  │io.meter   │ │
│  │  .Application    │  │  .runner         │  │sphere     │ │
│  │                  │  │  .Application    │  │.result    │ │
│  │                  │  │                  │  │.Applica   │ │
│  │                  │  │                  │  │tion       │ │
│  └──────────────────┘  └──────────────────┘  └───────────┘ │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 源码项目包含的组件

```
┌─────────────────────────────────────────────────────────────┐
│     源码项目 (metersphere_github/metersphere)                │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  backend/app/src/main/java/io/metersphere/                  │
│  │                                                           │
│  ├─ Application.java  ✅ 存在                                │
│  │                                                           │
│  backend/app/src/main/java/io/metersphere/runner/           │
│  │                                                           │
│  ├─ Application.java  ❌ 不存在                              │
│  │                                                           │
│  backend/app/src/main/java/io/metersphere/result/           │
│  │                                                           │
│  └─ Application.java  ❌ 不存在                              │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔄 更新流程对比

### 方案 A：使用原始 Dockerfile

```
源码编译
    ↓
backend/app/target/app-3.x.jar
    ↓
解压 jar 包
    ↓
找到: io/metersphere/Application.class  ✅
找不到: io/metersphere/runner/Application.class  ❌
找不到: io/metersphere/result/Application.class  ❌
    ↓
docker build -f Dockerfile
    ↓
生成镜像结构:
/app/
├── io/metersphere/Application.class  ✅
├── lib/
└── static/
    ↓
可更新的组件:
✅ metersphere (主服务)
❌ task-runner (无法更新)
❌ result-hub (无法更新)
```

### 方案 B：使用 Dockerfile.multi

```
源码编译
    ↓
backend/app/target/app-3.x.jar
    ↓
解压 jar 包
    ↓
找到: io/metersphere/Application.class  ✅
    ↓
docker build -f Dockerfile.multi
    ↓
生成镜像结构:
├── /metersphere/
│   └── io/metersphere/Application.class  ✅
├── /task-runner/
│   └── io/metersphere/Application.class  ⚠️ (复制相同的类)
├── /result-hub/
│   └── io/metersphere/Application.class  ⚠️ (复制相同的类)
└── /shells/
    ├── metersphere.sh
    ├── task-runner.sh
    └── result-hub.sh
    ↓
可更新的组件:
✅ metersphere (主服务 - 完全支持)
⚠️ task-runner (容器可重建，但缺少独立 Application)
⚠️ result-hub (容器可重建，但缺少独立 Application)
```

---

## 📋 组件更新能力对照表

| 组件 | 源码中是否存在 | 原始 Dockerfile | Dockerfile.multi | 推荐方案 |
|------|---------------|----------------|------------------|---------|
| **MeterSphere 主服务** | ✅ 完整支持 | ✅ 可以更新 | ✅ 可以更新 | 使用任意方案 |
| **Task Runner** | ❌ 不存在 | ❌ 无法更新 | ⚠️ 部分支持 | 使用官方镜像 |
| **Result Hub** | ❌ 不存在 | ❌ 无法更新 | ⚠️ 部分支持 | 使用官方镜像 |

---

## 🎯 使用建议

### 场景 1：只修改了主服务代码

**示例**：修改了 API 接口、前端页面、业务逻辑

```bash
# ✅ 推荐方案：使用原始 Dockerfile
cd /Users/huawen.li/IdeaProjects/metersphere_github/metersphere

# 编译
./mvnw clean package -DskipTests

# 构建镜像
docker build -f Dockerfile -t metersphere-custom:latest .

# 只更新主服务容器
docker stop metersphere && docker rm metersphere
cd /opt/metersphere
docker-compose -f docker-compose-base.yml \
  -f docker-compose-metersphere.yml \
  ... \
  up -d metersphere

# task-runner 和 result-hub 保持使用官方镜像 ✅
```

**结果**：
- ✅ 主服务使用最新代码
- ✅ Task Runner 和 Result Hub 保持稳定
- ✅ 最安全的方案

---

### 场景 2：修改了框架代码

**示例**：修改了 backend/framework/ 中的公共代码

```bash
# ⚠️ 慎用方案：使用 Dockerfile.multi
cd /Users/huawen.li/IdeaProjects/metersphere_github/metersphere

# 使用智能更新脚本
./update-deploy.sh --compile

# 或手动执行
./mvnw clean package -DskipTests
./build-multi-component.sh --skip-compile
cd /opt/metersphere
docker-compose ... up -d --force-recreate metersphere task-runner result-hub
```

**结果**：
- ✅ 所有组件都使用新代码
- ⚠️ task-runner 和 result-hub 可能缺少官方特殊逻辑
- ⚠️ 建议在测试环境验证后再部署到生产

---

### 场景 3：生产环境稳定部署

**推荐**：混合部署

```yaml
# docker-compose 配置
services:
  metersphere:
    image: metersphere-custom:latest  # 自定义镜像（源码编译）

  task-runner:
    image: registry.fit2cloud.com/metersphere/metersphere-ce:v3.6.7-lts  # 官方镜像

  result-hub:
    image: registry.fit2cloud.com/metersphere/metersphere-ce:v3.6.7-lts  # 官方镜像
```

**优点**：
- ✅ 主服务灵活更新
- ✅ 其他组件保持稳定
- ✅ 风险最低

---

## ⚠️ 重要警告

### 问题 1：源码中没有 runner 和 result 的 Application

```bash
# 验证：在源码中搜索
$ cd /Users/huawen.li/IdeaProjects/metersphere_github/metersphere
$ find backend -name "Application.java"
backend/app/src/main/java/io/metersphere/Application.java  # ← 只有这一个

$ find backend -path "*/runner/Application.java"
# 无结果 ❌

$ find backend -path "*/result/Application.java"
# 无结果 ❌
```

**结论**：源码不包含 task-runner 和 result-hub 的独立启动类。

---

### 问题 2：官方镜像的特殊构建

官方镜像包含三个独立的 Application 类：

```bash
# 在运行中的容器里验证
$ docker exec metersphere find /metersphere /task-runner /result-hub -name "Application.class"

/metersphere/io/metersphere/Application.class
/task-runner/io/metersphere/runner/Application.class      # ← 官方有
/result-hub/io/metersphere/result/Application.class       # ← 官方有
```

**结论**：官方使用了特殊的构建流程，这个流程未在开源代码中体现。

---

## 📚 相关文档

- [SOURCE_TO_DEPLOYMENT_ANALYSIS.md](SOURCE_TO_DEPLOYMENT_ANALYSIS.md) - 详细技术分析
- [DOCKERFILE_COMPARISON.md](DOCKERFILE_COMPARISON.md) - Dockerfile 对比
- [SOLUTION_OVERVIEW.md](SOLUTION_OVERVIEW.md) - 完整解决方案
- [update-deploy.sh](update-deploy.sh) - 智能更新脚本

---

## 💡 快速决策树

```
修改了代码？
    ├─ 是主服务代码 (backend/services/, frontend/)
    │     └─→ 使用原始 Dockerfile ✅
    │         只更新 metersphere 容器
    │
    ├─ 是框架代码 (backend/framework/)
    │     └─→ 使用 Dockerfile.multi ⚠️
    │         更新所有容器（测试环境）
    │         或只更新主服务（生产环境）
    │
    └─ 需要更新 task-runner 或 result-hub 的特定逻辑
          └─→ 无法从源码更新 ❌
              使用官方镜像
```

---

**版本**: v1.0 | **更新**: 2026-01-16
