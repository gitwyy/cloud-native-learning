# 📄 项目模板和配置文件

> 云原生学习路线图中使用的各种模板和配置文件

## 📁 目录结构

```
templates/
├── README.md              # 本文件：模板说明
├── docker/               # Docker相关模板
│   ├── Dockerfile.nodejs     # Node.js应用Dockerfile模板
│   ├── Dockerfile.python     # Python应用Dockerfile模板
│   ├── Dockerfile.golang     # Go应用Dockerfile模板
│   ├── Dockerfile.nginx      # Nginx静态站点模板
│   └── docker-compose.yml   # Docker Compose模板
├── kubernetes/           # Kubernetes配置模板
│   ├── deployment.yaml      # Deployment资源模板
│   ├── service.yaml         # Service资源模板
│   ├── ingress.yaml         # Ingress资源模板
│   ├── configmap.yaml       # ConfigMap模板
│   ├── secret.yaml          # Secret模板
│   └── namespace.yaml       # Namespace模板
├── monitoring/           # 监控配置模板
│   ├── prometheus/          # Prometheus配置
│   ├── grafana/            # Grafana仪表板
│   └── alertmanager/       # 告警配置
└── cicd/                # CI/CD流水线模板
    ├── gitlab-ci.yml       # GitLab CI配置
    ├── github-actions.yml  # GitHub Actions配置
    └── jenkins/           # Jenkins流水线
```

## 🐳 Docker模板

### Node.js应用Dockerfile模板

**文件名**: `docker/Dockerfile.nodejs`

```dockerfile
# 多阶段构建：构建阶段
FROM node:18-alpine AS builder

# 设置工作目录
WORKDIR /app

# 复制package文件
COPY package*.json ./

# 安装依赖（包括开发依赖）
RUN npm ci

# 复制源代码
COPY . .

# 构建应用（如果需要）
RUN npm run build

# 生产阶段
FROM node:18-alpine AS production

# 安装dumb-init
RUN apk add --no-cache dumb-init

# 创建非root用户
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# 设置工作目录
WORKDIR /app

# 复制package文件
COPY package*.json ./

# 只安装生产依赖
RUN npm ci --only=production && npm cache clean --force

# 从构建阶段复制应用文件
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
COPY --from=builder --chown=nodejs:nodejs /app/public ./public

# 切换到非root用户
USER nodejs

# 暴露端口
EXPOSE 3000

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node healthcheck.js

# 使用dumb-init启动应用
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/server.js"]
```

### Python应用Dockerfile模板

**文件名**: `docker/Dockerfile.python`

```dockerfile
# 多阶段构建：构建阶段
FROM python:3.11-slim AS builder

# 设置环境变量
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /app

# 复制requirements文件
COPY requirements.txt .

# 安装Python依赖
RUN pip install --user -r requirements.txt

# 生产阶段
FROM python:3.11-slim AS production

# 设置环境变量
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/home/appuser/.local/bin:$PATH"

# 创建非root用户
RUN useradd --create-home --shell /bin/bash appuser

# 设置工作目录
WORKDIR /app

# 从构建阶段复制安装的包
COPY --from=builder /root/.local /home/appuser/.local

# 复制应用代码
COPY --chown=appuser:appuser . .

# 切换到非root用户
USER appuser

# 暴露端口
EXPOSE 8000

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import requests; requests.get('http://localhost:8000/health', timeout=2)"

# 启动应用
CMD ["python", "app.py"]
```

### Docker Compose模板

**文件名**: `docker/docker-compose.yml`

```yaml
version: '3.8'

services:
  # Web应用服务
  web:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: "${PROJECT_NAME:-myapp}-web"
    ports:
      - "${WEB_PORT:-3000}:3000"
    environment:
      - NODE_ENV=${NODE_ENV:-production}
      - DATABASE_URL=postgresql://postgres:${DB_PASSWORD:-password}@db:5432/${DB_NAME:-myapp}
      - REDIS_URL=redis://redis:6379
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    volumes:
      - ./logs:/app/logs
    networks:
      - app-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  # 数据库服务
  db:
    image: postgres:15-alpine
    container_name: "${PROJECT_NAME:-myapp}-db"
    environment:
      - POSTGRES_DB=${DB_NAME:-myapp}
      - POSTGRES_USER=${DB_USER:-postgres}
      - POSTGRES_PASSWORD=${DB_PASSWORD:-password}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    networks:
      - app-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER:-postgres}"]
      interval: 30s
      timeout: 10s
      retries: 5

  # Redis缓存服务
  redis:
    image: redis:7-alpine
    container_name: "${PROJECT_NAME:-myapp}-redis"
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    networks:
      - app-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Nginx反向代理
  nginx:
    image: nginx:alpine
    container_name: "${PROJECT_NAME:-myapp}-nginx"
    ports:
      - "${NGINX_PORT:-80}:80"
      - "${NGINX_SSL_PORT:-443}:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - web
    networks:
      - app-network
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:

networks:
  app-network:
    driver: bridge
```

## ☸️ Kubernetes模板

### Deployment模板

**文件名**: `kubernetes/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: default
  labels:
    app: myapp
    version: v1.0.0
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
        version: v1.0.0
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        fsGroup: 1001
      containers:
      - name: myapp
        image: myapp:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 3000
          name: http
        env:
        - name: NODE_ENV
          value: "production"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: myapp-secrets
              key: database-url
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
        volumeMounts:
        - name: config
          mountPath: /app/config
          readOnly: true
        - name: logs
          mountPath: /app/logs
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
      volumes:
      - name: config
        configMap:
          name: myapp-config
      - name: logs
        emptyDir: {}
      nodeSelector:
        kubernetes.io/os: linux
      tolerations:
      - key: "app"
        operator: "Equal"
        value: "myapp"
        effect: "NoSchedule"
```

### Service模板

**文件名**: `kubernetes/service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
  namespace: default
  labels:
    app: myapp
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 3000
    protocol: TCP
    name: http
  selector:
    app: myapp
---
apiVersion: v1
kind: Service
metadata:
  name: myapp-headless
  namespace: default
  labels:
    app: myapp
spec:
  type: ClusterIP
  clusterIP: None
  ports:
  - port: 3000
    targetPort: 3000
    protocol: TCP
    name: http
  selector:
    app: myapp
```

## 📊 监控模板

### Prometheus配置模板

**文件名**: `monitoring/prometheus/prometheus.yml`

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "rules/*.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  # Prometheus自身
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Kubernetes API Server
  - job_name: 'kubernetes-apiservers'
    kubernetes_sd_configs:
      - role: endpoints
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    relabel_configs:
      - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
        action: keep
        regex: default;kubernetes;https

  # Kubernetes节点
  - job_name: 'kubernetes-nodes'
    kubernetes_sd_configs:
      - role: node
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)

  # Kubernetes Pods
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: kubernetes_namespace
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: kubernetes_pod_name
```

## 🔄 CI/CD模板

### GitLab CI模板

**文件名**: `cicd/gitlab-ci.yml`

```yaml
stages:
  - build
  - test
  - security
  - deploy-dev
  - deploy-staging
  - deploy-prod

variables:
  DOCKER_DRIVER: overlay2
  DOCKER_TLS_CERTDIR: "/certs"
  IMAGE_TAG: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
  KUBECTL_VERSION: "1.25.0"

# 构建阶段
build:
  stage: build
  image: docker:20.10.16
  services:
    - docker:20.10.16-dind
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
  script:
    - docker build -t $IMAGE_TAG .
    - docker push $IMAGE_TAG
  rules:
    - if: $CI_COMMIT_BRANCH

# 测试阶段
test:unit:
  stage: test
  image: node:18-alpine
  script:
    - npm ci
    - npm run test:unit
    - npm run test:coverage
  coverage: '/All files[^|]*\|[^|]*\s+([\d\.]+)/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml
  rules:
    - if: $CI_COMMIT_BRANCH

test:integration:
  stage: test
  image: docker:20.10.16
  services:
    - docker:20.10.16-dind
  script:
    - docker-compose -f docker-compose.test.yml up --build --abort-on-container-exit
    - docker-compose -f docker-compose.test.yml down
  rules:
    - if: $CI_COMMIT_BRANCH

# 安全扫描
security:container:
  stage: security
  image: aquasec/trivy:latest
  script:
    - trivy image --exit-code 0 --severity HIGH,CRITICAL $IMAGE_TAG
  rules:
    - if: $CI_COMMIT_BRANCH

security:sast:
  stage: security
  include:
    - template: Security/SAST.gitlab-ci.yml
  rules:
    - if: $CI_COMMIT_BRANCH

# 部署到开发环境
deploy:dev:
  stage: deploy-dev
  image: bitnami/kubectl:$KUBECTL_VERSION
  script:
    - kubectl config use-context $KUBE_CONTEXT_DEV
    - envsubst < k8s/deployment.yaml | kubectl apply -f -
    - kubectl rollout status deployment/myapp -n development
  environment:
    name: development
    url: https://dev.example.com
  rules:
    - if: $CI_COMMIT_BRANCH == "develop"

# 部署到预生产环境
deploy:staging:
  stage: deploy-staging
  image: bitnami/kubectl:$KUBECTL_VERSION
  script:
    - kubectl config use-context $KUBE_CONTEXT_STAGING
    - envsubst < k8s/deployment.yaml | kubectl apply -f -
    - kubectl rollout status deployment/myapp -n staging
  environment:
    name: staging
    url: https://staging.example.com
  when: manual
  rules:
    - if: $CI_COMMIT_BRANCH == "main"

# 部署到生产环境
deploy:prod:
  stage: deploy-prod
  image: bitnami/kubectl:$KUBECTL_VERSION
  script:
    - kubectl config use-context $KUBE_CONTEXT_PROD
    - envsubst < k8s/deployment.yaml | kubectl apply -f -
    - kubectl rollout status deployment/myapp -n production
  environment:
    name: production
    url: https://app.example.com
  when: manual
  rules:
    - if: $CI_COMMIT_TAG
```

## 📝 使用说明

### 如何使用模板

1. **复制模板文件**：根据项目需求复制相应的模板文件
2. **修改配置**：根据实际应用修改配置参数
3. **环境变量**：设置必要的环境变量
4. **测试验证**：在开发环境中测试配置

### 自定义建议

1. **镜像优化**：根据应用特点优化Docker镜像大小
2. **安全加固**：添加必要的安全配置和扫描
3. **监控集成**：集成应用特定的监控指标
4. **备份策略**：为数据服务添加备份配置

### 注意事项

1. **敏感信息**：不要在模板中硬编码敏感信息
2. **版本兼容**：注意工具和镜像版本的兼容性
3. **资源限制**：合理设置资源请求和限制
4. **标签管理**：使用一致的标签和注解规范

---

**💡 提示**：这些模板是学习的起点，实际使用时需要根据具体需求进行调整和优化。建议先在开发环境中测试，确认无误后再应用到生产环境。