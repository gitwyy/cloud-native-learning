# 🚀 云原生学习环境 - 自动化脚本集合

> 一键式环境设置、集群管理、监控部署的完整脚本工具集

## 📋 脚本概览

| 脚本 | 功能 | 用途 |
|------|------|------|
| `setup-environment.sh` | 🛠️ 环境安装 | 全平台云原生工具自动安装 |
| `setup-kubernetes.sh` | ⚙️ 集群管理 | Kubernetes集群创建和管理 |
| `setup-monitoring.sh` | 📊 监控部署 | Prometheus+Grafana监控栈 |
| `validate-setup.sh` | ✅ 环境验证 | 全面环境检查和测试 |
| `quick-start.sh` | 🚀 快速开始 | 第一阶段项目快速启动 |

## 🎯 快速开始

### 1. 全新环境安装
```bash
# 完整环境安装（推荐）
./scripts/setup-environment.sh

# 或者分步安装
./scripts/setup-environment.sh -m basic          # 基础工具
./scripts/setup-environment.sh -m kubernetes     # K8s工具
./scripts/setup-environment.sh -m monitoring     # 监控工具
```

### 2. 创建Kubernetes集群
```bash
# 创建Minikube集群（默认）
./scripts/setup-kubernetes.sh create

# 创建Kind集群
./scripts/setup-kubernetes.sh -t kind create

# 创建多节点Kind集群
./scripts/setup-kubernetes.sh -t kind --nodes 3 create
```

### 3. 部署监控系统
```bash
# 部署完整监控栈
./scripts/setup-monitoring.sh deploy

# 启动端口转发访问
./scripts/setup-monitoring.sh port-forward
```

### 4. 验证环境
```bash
# 完整环境验证
./scripts/validate-setup.sh

# 快速检查
./scripts/validate-setup.sh --quick
```

### 5. 开始第一个项目
```bash
# 启动简单Web应用
./scripts/quick-start.sh

# 启动Docker Compose版本
./scripts/quick-start.sh -m compose
```

## 📖 详细使用指南

### 🛠️ setup-environment.sh - 环境安装脚本

**支持系统**: macOS, Ubuntu/Debian, CentOS/RHEL

**功能特性**:
- ✅ 自动检测操作系统
- ✅ 多平台包管理器支持
- ✅ Docker和Docker Compose安装
- ✅ Kubernetes工具链安装
- ✅ 开发工具安装
- ✅ 国内镜像源配置

**使用示例**:
```bash
# 查看帮助
./scripts/setup-environment.sh --help

# 完整安装
./scripts/setup-environment.sh

# 仅安装基础工具
./scripts/setup-environment.sh -m basic

# 跳过Docker安装
./scripts/setup-environment.sh --skip-docker

# 跳过开发工具
./scripts/setup-environment.sh --skip-dev
```

**安装的工具**:
- **基础**: Git, curl, wget, 包管理器
- **容器**: Docker, Docker Compose
- **Kubernetes**: kubectl, minikube, kind, helm
- **监控**: k9s, kubectx, kubens
- **开发**: Node.js, Python3, Go(可选)

### ⚙️ setup-kubernetes.sh - 集群管理脚本

**支持集群类型**: Minikube, Kind, k3s

**功能特性**:
- ✅ 多种集群类型支持
- ✅ 自定义集群配置
- ✅ 基础组件自动安装
- ✅ 示例应用部署
- ✅ 开发环境配置

**使用示例**:
```bash
# 查看帮助
./scripts/setup-kubernetes.sh --help

# 创建默认Minikube集群
./scripts/setup-kubernetes.sh create

# 创建Kind集群
./scripts/setup-kubernetes.sh -t kind create

# 自定义配置
./scripts/setup-kubernetes.sh \
  -t kind \
  -n my-cluster \
  --nodes 3 \
  --memory 4096 \
  create

# 查看集群状态
./scripts/setup-kubernetes.sh status

# 部署示例应用
./scripts/setup-kubernetes.sh deploy-samples

# 删除集群
./scripts/setup-kubernetes.sh delete
```

**集群配置**:
- **Minikube**: 适合日常开发，功能丰富
- **Kind**: 轻量级，适合CI/CD和测试
- **k3s**: 生产级轻量版，适合边缘计算

### 📊 setup-monitoring.sh - 监控部署脚本

**监控栈**: Prometheus + Grafana + AlertManager

**功能特性**:
- ✅ 一键部署完整监控栈
- ✅ 预配置Grafana仪表板
- ✅ 示例告警规则
- ✅ 端口转发自动化
- ✅ ServiceMonitor示例

**使用示例**:
```bash
# 查看帮助
./scripts/setup-monitoring.sh --help

# 部署监控栈
./scripts/setup-monitoring.sh deploy

# 自定义密码部署
./scripts/setup-monitoring.sh -p mypassword deploy

# 启动端口转发
./scripts/setup-monitoring.sh port-forward

# 查看状态
./scripts/setup-monitoring.sh status

# 清理监控栈
./scripts/setup-monitoring.sh cleanup
```

**访问地址** (端口转发模式):
- **Grafana**: http://localhost:3000 (admin/admin123)
- **Prometheus**: http://localhost:9090
- **AlertManager**: http://localhost:9093

### ✅ validate-setup.sh - 环境验证脚本

**检查项目**:
- ✅ 系统要求检查
- ✅ 基础工具验证
- ✅ 容器功能测试
- ✅ Kubernetes连接测试
- ✅ 网络连接检查
- ✅ 功能性测试

**使用示例**:
```bash
# 查看帮助
./scripts/validate-setup.sh --help

# 完整验证
./scripts/validate-setup.sh

# 快速检查
./scripts/validate-setup.sh --quick

# 静默模式
./scripts/validate-setup.sh --report-only
```

**验证结果**:
- ✅ **通过**: 功能正常
- ⚠️ **警告**: 可选功能缺失
- ❌ **失败**: 必需功能故障

### 🚀 quick-start.sh - 项目快速启动

**支持模式**: 单容器、Docker Compose

**功能特性**:
- ✅ 自动镜像构建
- ✅ 健康检查验证
- ✅ 详细启动信息
- ✅ 管理命令提示

**使用示例**:
```bash
# 查看帮助
./scripts/quick-start.sh --help

# 单容器模式
./scripts/quick-start.sh

# Docker Compose模式
./scripts/quick-start.sh -m compose

# 清理后启动
./scripts/quick-start.sh -c -m compose
```

## 🔧 脚本权限设置

确保所有脚本有执行权限：
```bash
chmod +x scripts/*.sh
```

## 📊 使用流程建议

### 🆕 新用户完整流程
```bash
# 1. 环境安装
./scripts/setup-environment.sh

# 2. 验证安装
./scripts/validate-setup.sh

# 3. 创建集群
./scripts/setup-kubernetes.sh create

# 4. 部署监控
./scripts/setup-monitoring.sh deploy

# 5. 启动第一个项目
./scripts/quick-start.sh
```

### 🎯 快速验证流程
```bash
# 快速检查环境
./scripts/validate-setup.sh --quick

# 查看集群状态
./scripts/setup-kubernetes.sh status

# 查看监控状态
./scripts/setup-monitoring.sh status
```

### 🧹 环境清理流程
```bash
# 停止监控端口转发
~/stop-monitoring-ports.sh

# 清理监控栈
./scripts/setup-monitoring.sh cleanup

# 删除集群
./scripts/setup-kubernetes.sh delete

# 清理Docker资源
docker system prune -a
```

## ⚠️ 注意事项

### 系统要求
- **内存**: 最低8GB，推荐16GB+
- **磁盘**: 最低50GB，推荐100GB+
- **CPU**: 推荐4核心+
- **网络**: 稳定的互联网连接

### 权限要求
- **macOS**: 需要管理员密码安装工具
- **Linux**: 需要sudo权限
- **Docker**: 需要将用户加入docker组

### 网络配置
- 脚本会自动配置Docker国内镜像源
- 如有代理需求，请预先配置环境变量
- 某些企业网络可能需要额外配置

### 版本兼容性
- **Docker**: 20.10+
- **Kubernetes**: 1.25+
- **Helm**: 3.0+
- **Node.js**: 16+
- **Python**: 3.8+

## 🚨 故障排除

### 常见问题

1. **Docker权限问题**
```bash
sudo usermod -aG docker $USER
newgrp docker
```

2. **Minikube启动失败**
```bash
minikube delete
minikube start --driver=docker
```

3. **kubectl连接失败**
```bash
kubectl config view
kubectl config use-context minikube
```

4. **Helm仓库问题**
```bash
helm repo update
helm repo list
```

### 获取帮助
- 📖 查看文档: `docs/troubleshooting.md`
- 🔍 运行验证: `./scripts/validate-setup.sh`
- 📝 查看日志: `/tmp/cloud-native-setup.log`

## 📚 学习资源

- **📖 概念学习**: `docs/concepts.md`
- **🛠️ 工具设置**: `docs/tools-setup.md`
- **📋 学习路径**: `docs/learning-path.md`
- **📖 资源推荐**: `docs/resources.md`

## 🤝 贡献指南

欢迎提交PR改进脚本：
1. Fork项目
2. 创建特性分支
3. 提交变更
4. 发起Pull Request

---

**🎉 祝您云原生学习愉快！** 

如有问题，请查看 `docs/troubleshooting.md` 或提交Issue。