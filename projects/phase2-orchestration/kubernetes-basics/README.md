# Kubernetes基础部署学习指南

## 🎯 学习目标

本项目是云原生学习路径第二阶段的首个项目，专注于Kubernetes核心概念和基础部署技能。

### 核心学习目标
- 理解Kubernetes基本架构和核心资源对象
- 掌握Pod、Deployment、Service的创建和管理
- 学会使用kubectl进行基本操作
- 能够将第一阶段的容器化应用部署到Kubernetes集群

## 📚 Kubernetes核心概念

### Pod
Pod是Kubernetes中最小的部署单元，包含一个或多个紧密耦合的容器。

**核心特性：**
- 共享网络和存储
- 原子性调度单位
- 临时性资源（可被替换）

**生命周期阶段：**
```
Pending → Running → Succeeded/Failed
```

### Deployment
Deployment提供声明式的Pod和ReplicaSet更新。

**主要功能：**
- 副本数量控制
- 滚动更新策略
- 版本回滚
- 扩容缩容

**工作原理：**
```
Deployment → ReplicaSet → Pod
```

### Service
Service为Pod提供稳定的网络访问接口。

**服务类型：**
- **ClusterIP**：集群内部访问（默认）
- **NodePort**：通过节点端口暴露
- **LoadBalancer**：通过云提供商负载均衡器暴露
- **ExternalName**：DNS CNAME记录

**服务发现机制：**
- DNS解析
- 环境变量
- Service代理

## 🛠️ 本地环境搭建

### 方案一：Minikube
Minikube在本地运行单节点Kubernetes集群。

```bash
# macOS安装
brew install minikube

# 启动集群
minikube start --driver=docker --cpus=2 --memory=4096

# 验证集群状态
kubectl cluster-info
kubectl get nodes

# 启用常用插件
minikube addons enable dashboard
minikube addons enable ingress
```

### 方案二：Kind (Kubernetes in Docker)
Kind使用Docker容器作为节点运行Kubernetes集群。

```bash
# 安装Kind
brew install kind

# 创建集群
kind create cluster --name k8s-basics --config=manifests/kind-config.yaml

# 设置kubectl上下文
kubectl cluster-info --context kind-k8s-basics

# 验证集群
kubectl get nodes
```

### kubectl基础命令
```bash
# 查看集群信息
kubectl cluster-info
kubectl get nodes

# 资源管理
kubectl get pods
kubectl get deployments
kubectl get services

# 详细信息
kubectl describe pod <pod-name>
kubectl logs <pod-name>

# 应用配置
kubectl apply -f <yaml-file>
kubectl delete -f <yaml-file>
```

## 🎯 与容器化阶段衔接

本项目将使用第一阶段构建的Docker镜像进行Kubernetes部署练习。

### 前置条件
确保已完成第一阶段项目：
- [ ] ecommerce-basic项目的Docker镜像已构建
- [ ] 理解Docker容器基本概念
- [ ] 熟悉docker-compose多服务编排

### 镜像准备
```bash
# 构建第一阶段镜像（如果尚未构建）
cd ../phase1-containerization/ecommerce-basic
make build

# 加载镜像到Minikube（如使用Minikube）
eval $(minikube docker-env)
make build
```

## 🚀 基础练习

### 练习1：部署第一个Pod
**目标**：创建简单的nginx Pod并验证运行状态

```bash
# 1. 创建Pod
kubectl run nginx-pod --image=nginx:1.25 --port=80

# 2. 查看Pod状态
kubectl get pods
kubectl describe pod nginx-pod

# 3. 访问Pod（端口转发）
kubectl port-forward nginx-pod 8080:80

# 4. 清理资源
kubectl delete pod nginx-pod
```

### 练习2：创建Deployment
**目标**：使用YAML文件创建nginx Deployment

```bash
# 1. 应用Deployment配置
kubectl apply -f manifests/nginx-deployment.yaml

# 2. 查看Deployment状态
kubectl get deployments
kubectl get pods -l app=nginx

# 3. 扩容测试
kubectl scale deployment nginx-deployment --replicas=5

# 4. 查看滚动更新
kubectl set image deployment/nginx-deployment nginx=nginx:1.26
kubectl rollout status deployment/nginx-deployment
```

### 练习3：暴露Service
**目标**：为Deployment创建Service并进行访问测试

```bash
# 1. 创建Service
kubectl apply -f manifests/nginx-service.yaml

# 2. 查看Service
kubectl get services
kubectl describe service nginx-service

# 3. 访问测试
# NodePort方式
minikube service nginx-service --url

# 端口转发方式
kubectl port-forward service/nginx-service 8080:80
```

### 练习4：部署电商服务（进阶）
**目标**：将第一阶段的微服务部署到Kubernetes

```bash
# 1. 部署用户服务
kubectl apply -f manifests/user-service-deployment.yaml
kubectl apply -f manifests/user-service-service.yaml

# 2. 部署商品服务  
kubectl apply -f manifests/product-service-deployment.yaml
kubectl apply -f manifests/product-service-service.yaml

# 3. 验证服务间通信
kubectl exec -it <user-service-pod> -- curl http://product-service:5000/health
```

## 📝 学习目标检查表

### 基础概念理解
- [ ] 能够解释Pod、Deployment、Service的作用和区别
- [ ] 理解Kubernetes声明式配置的优势
- [ ] 掌握kubectl基本命令的使用

### 实践技能掌握
- [ ] 能够编写基本的Kubernetes YAML配置文件
- [ ] 能够创建和管理Deployment
- [ ] 能够配置不同类型的Service
- [ ] 能够进行基本的故障排查

### 进阶能力培养
- [ ] 能够将多容器应用迁移到Kubernetes
- [ ] 理解服务发现和负载均衡机制
- [ ] 掌握滚动更新和回滚操作
- [ ] 能够进行简单的资源监控

## 🔧 故障排查指南

### 常见问题及解决方案

**Pod状态为Pending**
```bash
# 查看详细信息
kubectl describe pod <pod-name>

# 常见原因：
# 1. 资源不足
# 2. 镜像拉取失败
# 3. 调度约束
```

**Service无法访问**
```bash
# 检查Endpoints
kubectl get endpoints <service-name>

# 检查标签选择器
kubectl get pods --show-labels
```

**镜像拉取失败**
```bash
# 检查镜像名称和标签
kubectl describe pod <pod-name>

# 对于本地镜像（Minikube）
eval $(minikube docker-env)
docker images
```

## 📖 参考资源

### 官方文档
- [Kubernetes官方文档](https://kubernetes.io/docs/)
- [kubectl命令参考](https://kubernetes.io/docs/reference/kubectl/)

### 学习资源
- [Kubernetes Basics Interactive Tutorial](https://kubernetes.io/docs/tutorials/kubernetes-basics/)
- [Play with Kubernetes](https://labs.play-with-k8s.com/)

### 下一步学习方向
- ConfigMap和Secret管理
- Ingress配置和使用
- 持久化存储（PV/PVC）
- Helm包管理器

## 🎉 项目完成标准

完成所有练习并通过检查表验证后，你将具备：
1. Kubernetes基础资源对象的理解和使用能力
2. 将容器化应用部署到Kubernetes的技能
3. 基本的集群操作和故障排查能力

**恭喜！你已经迈入了云原生编排技术的大门！**