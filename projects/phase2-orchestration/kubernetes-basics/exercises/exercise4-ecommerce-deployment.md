# 练习4：电商微服务Kubernetes部署（进阶整合）

## 🎯 学习目标

- 将第一阶段的电商微服务迁移到Kubernetes
- 理解微服务间的网络通信配置
- 掌握ConfigMap和Secret的使用
- 学会数据库和有状态应用的部署

## 📋 前置条件

- 完成练习1-3的所有基础训练
- 第一阶段ecommerce-basic项目已构建完成
- 理解微服务架构基本概念
- 熟悉Docker镜像构建流程

## 🚀 练习步骤

### 步骤1：准备镜像环境

```bash
# 切换到第一阶段项目目录
cd ../../phase1-containerization/ecommerce-basic

# 对于Minikube环境，切换到Minikube的Docker环境
eval $(minikube docker-env)

# 构建所有服务镜像
make build

# 验证镜像是否存在
docker images | grep -E "(user-service|product-service|order-service|notification-service)"
```

### 步骤2：创建命名空间

```bash
# 返回Kubernetes项目目录
cd ../../phase2-orchestration/kubernetes-basics

# 创建专用命名空间
kubectl create namespace ecommerce

# 设置默认命名空间（可选）
kubectl config set-context --current --namespace=ecommerce

# 验证命名空间
kubectl get namespaces
```

### 步骤3：部署PostgreSQL数据库

```yaml
# manifests/postgres-deployment.yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: ecommerce
type: Opaque
data:
  username: cG9zdGdyZXM=  # postgres (base64)
  password: cGFzc3dvcmQ=  # password (base64)
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: ecommerce
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: ecommerce
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:13
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        - name: POSTGRES_DB
          value: ecommerce
        volumeMounts:
        - mountPath: /var/lib/postgresql/data
          name: postgres-storage
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: postgres-storage
        persistentVolumeClaim:
          claimName: postgres-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
  namespace: ecommerce
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
  type: ClusterIP
```

```bash
# 部署PostgreSQL
kubectl apply -f manifests/postgres-deployment.yaml

# 验证部署
kubectl get pods,services,pvc -n ecommerce
```

### 步骤4：创建应用配置

```yaml
# manifests/app-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: ecommerce
data:
  database_url: "postgresql://postgres:password@postgres-service:5432/ecommerce"
  redis_url: "redis://redis-service:6379"
  flask_env: "production"
  log_level: "INFO"
---
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
  namespace: ecommerce
type: Opaque
data:
  jwt_secret: "bXktc2VjcmV0LWtleQ=="  # my-secret-key (base64)
  api_key: "bXktYXBpLWtleQ=="         # my-api-key (base64)
```

```bash
# 创建配置
kubectl apply -f manifests/app-config.yaml

# 验证配置
kubectl get configmaps,secrets -n ecommerce
```

### 步骤5：部署Redis缓存

```yaml
# manifests/redis-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: ecommerce
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:6-alpine
        ports:
        - containerPort: 6379
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        command: ["redis-server"]
        args: ["--appendonly", "yes"]
---
apiVersion: v1
kind: Service
metadata:
  name: redis-service
  namespace: ecommerce
spec:
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
  type: ClusterIP
```

```bash
# 部署Redis
kubectl apply -f manifests/redis-deployment.yaml

# 验证Redis部署
kubectl get pods,services -l app=redis -n ecommerce
```

### 步骤6：部署用户服务

```yaml
# manifests/user-service-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: ecommerce
spec:
  replicas: 2
  selector:
    matchLabels:
      app: user-service
      tier: backend
  template:
    metadata:
      labels:
        app: user-service
        tier: backend
        version: v1
    spec:
      containers:
      - name: user-service
        image: user-service:1.0
        imagePullPolicy: Never  # 使用本地镜像
        ports:
        - containerPort: 5000
          name: http
        env:
        - name: DATABASE_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: database_url
        - name: REDIS_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: redis_url
        - name: FLASK_ENV
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: flask_env
        - name: JWT_SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: app-secret
              key: jwt_secret
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        readinessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 15
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 30
          periodSeconds: 15
---
apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: ecommerce
spec:
  selector:
    app: user-service
  ports:
  - name: http
    port: 80
    targetPort: 5000
  type: ClusterIP
```

```bash
# 部署用户服务
kubectl apply -f manifests/user-service-deployment.yaml

# 验证部署
kubectl get pods,services -l app=user-service -n ecommerce
kubectl logs -f deployment/user-service -n ecommerce
```

### 步骤7：部署其他微服务

```yaml
# manifests/product-service-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: product-service
  namespace: ecommerce
spec:
  replicas: 2
  selector:
    matchLabels:
      app: product-service
  template:
    metadata:
      labels:
        app: product-service
        tier: backend
    spec:
      containers:
      - name: product-service
        image: product-service:1.0
        imagePullPolicy: Never
        ports:
        - containerPort: 5000
        envFrom:
        - configMapRef:
            name: app-config
        - secretRef:
            name: app-secret
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: product-service
  namespace: ecommerce
spec:
  selector:
    app: product-service
  ports:
  - port: 80
    targetPort: 5000
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  namespace: ecommerce
spec:
  replicas: 2
  selector:
    matchLabels:
      app: order-service
  template:
    metadata:
      labels:
        app: order-service
        tier: backend
    spec:
      containers:
      - name: order-service
        image: order-service:1.0
        imagePullPolicy: Never
        ports:
        - containerPort: 5000
        envFrom:
        - configMapRef:
            name: app-config
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: order-service
  namespace: ecommerce
spec:
  selector:
    app: order-service
  ports:
  - port: 80
    targetPort: 5000
```

```bash
# 部署其他服务
kubectl apply -f manifests/product-service-deployment.yaml

# 验证所有服务
kubectl get all -n ecommerce
```

### 步骤8：创建API网关（Nginx）

```yaml
# manifests/api-gateway.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: ecommerce
data:
  default.conf: |
    upstream user_service {
        server user-service:80;
    }
    upstream product_service {
        server product-service:80;
    }
    upstream order_service {
        server order-service:80;
    }
    
    server {
        listen 80;
        server_name localhost;
        
        location /api/users/ {
            proxy_pass http://user_service/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
        
        location /api/products/ {
            proxy_pass http://product_service/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
        
        location /api/orders/ {
            proxy_pass http://order_service/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
        
        location / {
            return 200 'eCommerce API Gateway\n';
            add_header Content-Type text/plain;
        }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  namespace: ecommerce
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-gateway
  template:
    metadata:
      labels:
        app: api-gateway
        tier: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/conf.d
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
      volumes:
      - name: nginx-config
        configMap:
          name: nginx-config
---
apiVersion: v1
kind: Service
metadata:
  name: api-gateway
  namespace: ecommerce
spec:
  selector:
    app: api-gateway
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
  type: NodePort
```

```bash
# 部署API网关
kubectl apply -f manifests/api-gateway.yaml

# 获取访问地址
minikube service api-gateway -n ecommerce --url
```

## 🧪 测试和验证

### 步骤1：健康检查

```bash
# 检查所有Pod状态
kubectl get pods -n ecommerce

# 检查服务连通性
kubectl exec -n ecommerce -it deployment/user-service -- curl http://product-service/health

# 检查数据库连接
kubectl exec -n ecommerce -it deployment/postgres -- psql -U postgres -d ecommerce -c "\dt"
```

### 步骤2：功能测试

```bash
# 获取API网关地址
GATEWAY_URL=$(minikube service api-gateway -n ecommerce --url)

# 测试API网关
curl $GATEWAY_URL

# 测试用户服务
curl $GATEWAY_URL/api/users/health

# 测试产品服务
curl $GATEWAY_URL/api/products/health
```

### 步骤3：负载测试

```bash
# 创建测试Pod
kubectl run test-client -n ecommerce --image=busybox --rm -it --restart=Never -- sh

# 在测试Pod中执行：
# 压力测试API网关
for i in {1..100}; do
  wget -qO- http://api-gateway/api/users/health
done
```

## 📊 监控和日志

### 查看应用日志

```bash
# 查看用户服务日志
kubectl logs -f deployment/user-service -n ecommerce

# 查看数据库日志
kubectl logs -f deployment/postgres -n ecommerce

# 查看API网关日志
kubectl logs -f deployment/api-gateway -n ecommerce
```

### 资源监控

```bash
# 查看Pod资源使用
kubectl top pods -n ecommerce

# 查看服务状态
kubectl get services -n ecommerce

# 查看持久化存储
kubectl get pvc -n ecommerce
```

## 🔧 扩容和更新

### 水平扩容

```bash
# 扩容用户服务
kubectl scale deployment user-service --replicas=5 -n ecommerce

# 扩容产品服务
kubectl scale deployment product-service --replicas=3 -n ecommerce

# 验证扩容结果
kubectl get pods -l tier=backend -n ecommerce
```

### 滚动更新

```bash
# 假设有新版本镜像user-service:1.1
kubectl set image deployment/user-service user-service=user-service:1.1 -n ecommerce

# 观察更新过程
kubectl rollout status deployment/user-service -n ecommerce

# 如需回滚
kubectl rollout undo deployment/user-service -n ecommerce
```

## 📝 练习检查表

完成练习后，确保你能够：

- [ ] 在Kubernetes中部署有状态服务（PostgreSQL）
- [ ] 使用ConfigMap和Secret管理配置
- [ ] 部署多个相互依赖的微服务
- [ ] 配置服务间网络通信
- [ ] 创建API网关进行路由转发
- [ ] 使用PVC管理持久化存储
- [ ] 执行应用的扩容和更新操作
- [ ] 监控应用状态和资源使用
- [ ] 排查微服务间的连接问题

## 🎯 进阶挑战

1. **添加Ingress配置**：使用Ingress替代NodePort
2. **实施蓝绿部署**：配置蓝绿部署策略
3. **添加监控**：集成Prometheus和Grafana
4. **配置自动扩容**：使用HPA进行自动扩缩容
5. **添加服务网格**：集成Istio进行流量管理

## 🎉 小结

通过本练习，你已经成功：

1. **完整迁移**：将Docker Compose应用迁移到Kubernetes
2. **微服务管理**：掌握了微服务在Kubernetes中的部署模式
3. **配置管理**：学会了使用ConfigMap和Secret
4. **网络配置**：理解了服务发现和负载均衡
5. **存储管理**：使用了持久化卷存储数据

**恭喜！你已经具备了在Kubernetes中部署和管理复杂微服务应用的能力！**