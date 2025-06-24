# 🔧 开发环境和工具安装指南

> 从零开始搭建完整的云原生开发环境

## 📋 目录

- [系统要求](#系统要求)
- [基础工具安装](#基础工具安装)
- [容器化工具](#容器化工具)
- [Kubernetes工具](#kubernetes工具)
- [监控工具](#监控工具)
- [CI/CD工具](#cicd工具)
- [开发工具](#开发工具)
- [验证安装](#验证安装)

---

## 💻 系统要求

### 最低硬件配置
- **CPU**: 4核心以上
- **内存**: 16GB以上（推荐32GB）
- **存储**: 100GB可用空间
- **网络**: 稳定的互联网连接

### 支持的操作系统
- **macOS**: 10.15+
- **Windows**: Windows 10/11 + WSL2
- **Linux**: Ubuntu 18.04+, CentOS 7+, RHEL 7+

---

## 🛠️ 基础工具安装

### 1. 包管理器

#### macOS - Homebrew
```bash
# 安装Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 验证安装
brew --version
```

#### Ubuntu/Debian - APT
```bash
# 更新包索引
sudo apt update && sudo apt upgrade -y

# 安装必要工具
sudo apt install -y curl wget git vim build-essential
```

#### CentOS/RHEL - YUM/DNF
```bash
# CentOS 7
sudo yum update -y
sudo yum install -y curl wget git vim gcc make

# CentOS 8+/RHEL 8+
sudo dnf update -y
sudo dnf install -y curl wget git vim gcc make
```

### 2. Git版本控制
```bash
# macOS
brew install git

# Ubuntu/Debian
sudo apt install -y git

# CentOS/RHEL
sudo yum install -y git  # CentOS 7
sudo dnf install -y git  # CentOS 8+

# 配置Git
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### 3. 代码编辑器

#### Visual Studio Code
```bash
# macOS
brew install --cask visual-studio-code

# Ubuntu/Debian
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
sudo apt update
sudo apt install -y code
```

**推荐VSCode插件**：
```bash
# 安装云原生相关插件
code --install-extension ms-vscode.vscode-yaml
code --install-extension ms-kubernetes-tools.vscode-kubernetes-tools
code --install-extension ms-vscode.vscode-docker
code --install-extension hashicorp.terraform
code --install-extension redhat.vscode-yaml
```

---

## 🐳 容器化工具

### 1. Docker Engine

#### macOS
```bash
# 使用Homebrew安装Docker Desktop
brew install --cask docker

# 或者手动下载安装
# 访问: https://docs.docker.com/desktop/mac/install/
```

#### Ubuntu
```bash
# 卸载旧版本Docker
sudo apt remove -y docker docker-engine docker.io containerd runc

# 安装依赖
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# 添加Docker官方GPG密钥
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# 设置稳定版本仓库
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 安装Docker Engine
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# 将用户添加到docker组
sudo usermod -aG docker $USER
newgrp docker
```

#### CentOS/RHEL
```bash
# 卸载旧版本
sudo yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine

# 安装依赖
sudo yum install -y yum-utils device-mapper-persistent-data lvm2

# 添加Docker仓库
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# 安装Docker
sudo yum install -y docker-ce docker-ce-cli containerd.io

# 启动Docker服务
sudo systemctl start docker
sudo systemctl enable docker

# 将用户添加到docker组
sudo usermod -aG docker $USER
```

### 2. Docker Compose

#### 官方安装方法
```bash
# 下载Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# 添加执行权限
sudo chmod +x /usr/local/bin/docker-compose

# 创建软链接（可选）
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
```

#### 使用包管理器（推荐）
```bash
# macOS
brew install docker-compose

# Ubuntu
sudo apt install -y docker-compose

# CentOS/RHEL
sudo yum install -y docker-compose  # 需要EPEL仓库
```

### 3. 验证Docker安装
```bash
# 检查Docker版本
docker --version
docker-compose --version

# 运行Hello World容器
docker run hello-world

# 查看Docker信息
docker info
```

---

## ⚙️ Kubernetes工具

### 1. kubectl - Kubernetes CLI

#### 官方安装方法
```bash
# macOS
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

#### 使用包管理器
```bash
# macOS
brew install kubectl

# Ubuntu
sudo snap install kubectl --classic

# CentOS/RHEL
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
sudo yum install -y kubectl
```

### 2. Minikube - 本地Kubernetes集群

```bash
# macOS
brew install minikube

# Linux
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
chmod +x minikube
sudo mv minikube /usr/local/bin/

# 启动Minikube集群
minikube start --driver=docker --cpus=4 --memory=8192

# 验证集群状态
kubectl cluster-info
kubectl get nodes
```

### 3. Kind - Docker中的Kubernetes

```bash
# macOS
brew install kind

# Linux
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.17.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# 创建集群
kind create cluster --name dev-cluster

# 验证集群
kubectl cluster-info --context kind-dev-cluster
```

### 4. Helm - Kubernetes包管理器

```bash
# macOS
brew install helm

# Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 验证安装
helm version

# 添加常用Chart仓库
helm repo add stable https://charts.helm.sh/stable
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

### 5. 其他Kubernetes工具

#### kubectx & kubens - 上下文切换工具
```bash
# macOS
brew install kubectx

# Linux
sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens
```

#### k9s - Kubernetes Dashboard
```bash
# macOS
brew install k9s

# Linux
curl -sS https://webinstall.dev/k9s | bash
```

---

## 📊 监控工具

### 1. Prometheus

#### 使用Helm安装
```bash
# 添加Prometheus Helm仓库
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 创建监控命名空间
kubectl create namespace monitoring

# 安装Prometheus Stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false
```

### 2. Grafana访问配置

```bash
# 获取Grafana密码
kubectl get secret --namespace monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

# 端口转发访问Grafana
kubectl port-forward --namespace monitoring svc/prometheus-grafana 3000:80

# 访问: http://localhost:3000
# 用户名: admin
# 密码: 上面获取的密码
```

### 3. 日志管理 - ELK Stack

#### Elasticsearch
```bash
# 添加Elastic Helm仓库
helm repo add elastic https://helm.elastic.co
helm repo update

# 安装Elasticsearch
helm install elasticsearch elastic/elasticsearch \
  --namespace logging \
  --create-namespace \
  --set replicas=1 \
  --set minimumMasterNodes=1
```

#### Kibana
```bash
# 安装Kibana
helm install kibana elastic/kibana \
  --namespace logging \
  --set elasticsearchHosts="http://elasticsearch-master:9200"
```

#### Fluentd
```bash
# 安装Fluentd
helm install fluentd bitnami/fluentd \
  --namespace logging \
  --set aggregator.enabled=true \
  --set forwarder.enabled=true
```

---

## 🔄 CI/CD工具

### 1. GitLab Runner

```bash
# 添加GitLab Helm仓库
helm repo add gitlab https://charts.gitlab.io
helm repo update

# 安装GitLab Runner
helm install gitlab-runner gitlab/gitlab-runner \
  --namespace gitlab-runner \
  --create-namespace \
  --set gitlabUrl=https://gitlab.com/ \
  --set runnerRegistrationToken="YOUR_REGISTRATION_TOKEN"
```

### 2. ArgoCD - GitOps工具

```bash
# 创建ArgoCD命名空间
kubectl create namespace argocd

# 安装ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 获取初始管理员密码
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# 端口转发访问ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 访问: https://localhost:8080
# 用户名: admin
# 密码: 上面获取的密码
```

### 3. Jenkins in Kubernetes

```bash
# 添加Jenkins Helm仓库
helm repo add jenkins https://charts.jenkins.io
helm repo update

# 创建Jenkins命名空间
kubectl create namespace jenkins

# 安装Jenkins
helm install jenkins jenkins/jenkins \
  --namespace jenkins \
  --set controller.serviceType=LoadBalancer \
  --set controller.adminPassword=admin123
```

---

## 🧰 开发工具

### 1. 多版本Node.js管理 - nvm

```bash
# 安装nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# 重新加载shell配置
source ~/.bashrc

# 安装最新LTS版本Node.js
nvm install --lts
nvm use --lts

# 验证安装
node --version
npm --version
```

### 2. Python环境管理 - pyenv

```bash
# macOS
brew install pyenv

# Ubuntu/Debian
sudo apt install -y make build-essential libssl-dev zlib1g-dev \
  libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
  libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
  libffi-dev liblzma-dev

curl https://pyenv.run | bash

# 添加到shell配置
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(pyenv init -)"' >> ~/.bashrc

# 安装Python
pyenv install 3.9.16
pyenv global 3.9.16
```

### 3. Go语言环境

```bash
# macOS
brew install go

# Linux - 手动安装
wget https://go.dev/dl/go1.19.5.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.19.5.linux-amd64.tar.gz

# 添加到PATH
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc

# 验证安装
go version
```

### 4. Terraform

```bash
# macOS
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Ubuntu/Debian
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# 验证安装
terraform --version
```

---

## ✅ 验证安装

### 创建验证脚本

```bash
# 创建验证脚本
cat > verify-installation.sh << 'EOF'
#!/bin/bash

echo "🔍 验证云原生工具安装状态..."
echo "=================================="

# 基础工具
echo "📦 基础工具:"
command -v git >/dev/null 2>&1 && echo "✅ Git: $(git --version)" || echo "❌ Git: 未安装"
command -v docker >/dev/null 2>&1 && echo "✅ Docker: $(docker --version)" || echo "❌ Docker: 未安装"
command -v docker-compose >/dev/null 2>&1 && echo "✅ Docker Compose: $(docker-compose --version)" || echo "❌ Docker Compose: 未安装"

echo ""
echo "☸️ Kubernetes工具:"
command -v kubectl >/dev/null 2>&1 && echo "✅ kubectl: $(kubectl version --client --short)" || echo "❌ kubectl: 未安装"
command -v minikube >/dev/null 2>&1 && echo "✅ Minikube: $(minikube version --short)" || echo "❌ Minikube: 未安装"
command -v helm >/dev/null 2>&1 && echo "✅ Helm: $(helm version --short)" || echo "❌ Helm: 未安装"

echo ""
echo "🛠️ 开发工具:"
command -v node >/dev/null 2>&1 && echo "✅ Node.js: $(node --version)" || echo "❌ Node.js: 未安装"
command -v python3 >/dev/null 2>&1 && echo "✅ Python: $(python3 --version)" || echo "❌ Python: 未安装"
command -v go >/dev/null 2>&1 && echo "✅ Go: $(go version | cut -d' ' -f3)" || echo "❌ Go: 未安装"
command -v terraform >/dev/null 2>&1 && echo "✅ Terraform: $(terraform --version | head -n1)" || echo "❌ Terraform: 未安装"

echo ""
echo "🔄 集群状态检查:"
if kubectl cluster-info >/dev/null 2>&1; then
    echo "✅ Kubernetes集群: 运行中"
    echo "   节点数量: $(kubectl get nodes --no-headers | wc -l)"
    echo "   集群版本: $(kubectl version --short | grep Server | cut -d' ' -f3)"
else
    echo "❌ Kubernetes集群: 未连接"
    echo "   提示: 请启动Minikube或连接到现有集群"
fi

echo ""
echo "🐋 Docker状态检查:"
if docker info >/dev/null 2>&1; then
    echo "✅ Docker守护进程: 运行中"
    echo "   版本: $(docker --version | cut -d' ' -f3 | cut -d',' -f1)"
else
    echo "❌ Docker守护进程: 未运行"
    echo "   提示: 请启动Docker服务"
fi

echo ""
echo "=================================="
echo "✨ 验证完成！"
EOF

chmod +x verify-installation.sh
./verify-installation.sh
```

### 快速环境测试

```bash
# 测试Docker
docker run --rm hello-world

# 测试Kubernetes（如果集群运行中）
kubectl run test-pod --image=nginx --restart=Never
kubectl get pods
kubectl delete pod test-pod

# 测试Helm
helm list

# 测试端口转发
kubectl port-forward svc/kubernetes 8080:443 &
curl -k https://localhost:8080/version
kill %1
```

---

## 🔧 故障排除

### 常见问题及解决方案

#### 1. Docker权限问题
```bash
# 错误: permission denied while trying to connect to the Docker daemon socket
sudo usermod -aG docker $USER
newgrp docker
# 或者重新登录系统
```

#### 2. Minikube启动失败
```bash
# 检查系统资源
minikube status
minikube logs

# 重置Minikube
minikube delete
minikube start --driver=docker --cpus=4 --memory=8192
```

#### 3. kubectl连接失败
```bash
# 检查配置文件
kubectl config view
kubectl config current-context

# 设置正确的上下文
kubectl config use-context minikube
```

#### 4. Helm安装失败
```bash
# 检查仓库状态
helm repo list
helm repo update

# 清理失败的安装
helm uninstall RELEASE_NAME
```

### 性能优化建议

1. **Docker优化**
   - 增加Docker内存限制
   - 使用本地镜像缓存
   - 清理未使用的镜像和容器

2. **Kubernetes优化**
   - 调整集群资源配额
   - 使用多节点集群
   - 优化网络插件配置

3. **开发环境优化**
   - 使用SSD存储
   - 增加系统可用内存
   - 优化网络连接

---

## 📚 后续步骤

安装完成后，建议按以下顺序进行学习：

1. **熟悉基础工具** - 练习Docker和kubectl命令
2. **启动本地集群** - 使用Minikube或Kind
3. **部署第一个应用** - 运行简单的Nginx或Hello World
4. **学习配置文件** - 编写和应用YAML配置
5. **监控和日志** - 访问Grafana和Kibana界面

---

**🎉 恭喜！您已经成功搭建了完整的云原生开发环境！**

现在可以开始 [云原生学习路线图](./learning-path.md) 的第一阶段学习了。记住，实践是掌握云原生技术的关键，祝您学习愉快！ 🚀