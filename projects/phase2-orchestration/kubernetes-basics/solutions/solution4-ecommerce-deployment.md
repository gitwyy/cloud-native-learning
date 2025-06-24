# 练习4解答：电商微服务Kubernetes部署

## 📋 解答要点

### 步骤1：准备镜像环境

```bash
# 切换到第一阶段项目目录
cd ../../phase1-containerization/ecommerce-basic

# 对于Minikube环境，配置Docker环境
eval $(minikube docker-env)

# 构建所有微服务镜像
make build

# 验证镜像构建结果
docker images | grep -E "(user-service|product-service|order-service|notification-service)"
# 应显示：
# ecommerce-basic-user-service         latest
# ecommerce-basic-product-service      latest
# ecommerce-basic-order-service        latest
# ecommerce-basic-notification-service latest

# 为镜像打标签以便Kubernetes使用
docker tag ecommerce-basic-user-service:latest user-service:1.0
docker tag ecommerce-basic-product-service:latest product-service:1.0
docker tag ecommerce-basic-order-service:latest order-service:1.0
docker tag ecommerce-basic-notification-service:latest notification-service:1.0
```

### 步骤2：创建命名空间和基础配置

```bash
# 返回Kubernetes项目目录
cd ../../phase2-orchestration/kubernetes-basics

# 创建专用命名空间
kubectl create namespace ecommerce

# 设置默认命名空间（可选）
kubectl config set-context --current --namespace=ecommerce

# 验证命名空间创建
kubectl get namespaces | grep ecommerce
# 应显示：ecommerce    Active   1m
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
  username: cG9zdGdyZXM=  # postgres
  password: ZWNvbW1lcmNlMTIz  # ecommerce123
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
      storage: 2Gi
  storageClassName: standard  # 使用默认存储类
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: ecommerce
  labels:
    app: postgres
    tier: database
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
        tier: database
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        ports:
        - containerPort: 5432
          name: postgres
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
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - postgres
            - -d
            - ecommerce
          initialDelaySeconds: 15
          periodSeconds: 5
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - postgres
            - -d
            - ecommerce
          initialDelaySeconds: 30
          periodSeconds: 10
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
  labels:
    app: postgres
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
    name: postgres
  type: ClusterIP
```

```bash
# 部署PostgreSQL
kubectl apply -f manifests/postgres-deployment.yaml

# 验证部署状态
kubectl get pods,services,pvc -n ecommerce
# 等待Pod状态变为Running

# 验证数据库连接
kubectl exec -n ecommerce -it deployment/postgres -- psql -U postgres -d ecommerce -c "\l"
# 应显示数据库列表，包含ecommerce数据库
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
  # 数据库配置
  database_url: "postgresql://postgres:ecommerce123@postgres-service:5432/ecommerce_users"
  product_database_url: "postgresql://postgres:ecommerce123@postgres-service:5432/ecommerce_products"
  order_database_url: "postgresql://postgres:ecommerce123@postgres-service:5432/ecommerce_orders"
  notification_database_url: "postgresql://postgres:ecommerce123@postgres-service:5432/ecommerce_notifications"
  
  # Redis配置
  redis_url: "redis://:redis123@redis-service:6379/0"
  redis_product_url: "redis://:redis123@redis-service:6379/1"
  redis_order_url: "redis://:redis123@redis-service:6379/2"
  redis_notification_url: "redis://:redis123@redis-service:6379/3"
  
  # RabbitMQ配置
  rabbitmq_url: "amqp://admin:rabbitmq123@rabbitmq-service:5672/"
  
  # 应用配置
  flask_env: "production"
  log_level: "INFO"
  
  # 服务间通信
  user_service_url: "http://user-service:80"
  product_service_url: "http://product-service:80"
  order_service_url: "http://order-service:80"
  notification_service_url: "http://notification-service:80"
---
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
  namespace: ecommerce
type: Opaque
data:
  jwt_secret: "dXNlci1zZXJ2aWNlLXNlY3JldC1rZXk="  # user-service-secret-key
  api_key: "YXBpLWtleS0xMjM="                      # api-key-123
  email_password: "ZW1haWwtcGFzc3dvcmQ="            # email-password
  sms_api_key: "c21zLWFwaS1rZXk="                   # sms-api-key
```

```bash
# 创建配置
kubectl apply -f manifests/app-config.yaml

# 验证配置创建
kubectl get configmaps,secrets -n ecommerce
kubectl describe configmap app-config -n ecommerce
```

### 步骤5：部署Redis缓存

```yaml
# manifests/redis-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: ecommerce
  labels:
    app: redis
    tier: cache
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
        tier: cache
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
          name: redis
        command: ["redis-server"]
        args: 
        - --appendonly
        - "yes"
        - --requirepass
        - "redis123"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        readinessProbe:
          exec:
            command:
            - redis-cli
            - -a
            - redis123
            - ping
          initialDelaySeconds: 5
          periodSeconds: 5
        livenessProbe:
          exec:
            command:
            - redis-cli
            - -a
            - redis123
            - ping
          initialDelaySeconds: 30
          periodSeconds: 30
---
apiVersion: v1
kind: Service
metadata:
  name: redis-service
  namespace: ecommerce
  labels:
    app: redis
spec:
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
    name: redis
  type: ClusterIP
```

```bash
# 部署Redis
kubectl apply -f manifests/redis-deployment.yaml

# 验证Redis部署
kubectl get pods,services -l app=redis -n ecommerce

# 测试Redis连接
kubectl exec -n ecommerce -it deployment/redis -- redis-cli -a redis123 ping
# 应返回：PONG
```

### 步骤6：部署RabbitMQ消息队列

```yaml
# manifests/rabbitmq-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rabbitmq
  namespace: ecommerce
  labels:
    app: rabbitmq
    tier: queue
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rabbitmq
  template:
    metadata:
      labels:
        app: rabbitmq
        tier: queue
    spec:
      containers:
      - name: rabbitmq
        image: rabbitmq:3.12-management-alpine
        ports:
        - containerPort: 5672
          name: amqp
        - containerPort: 15672
          name: management
        env:
        - name: RABBITMQ_DEFAULT_USER
          value: "admin"
        - name: RABBITMQ_DEFAULT_PASS
          value: "rabbitmq123"
        - name: RABBITMQ_DEFAULT_VHOST
          value: "/"
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        readinessProbe:
          exec:
            command:
            - rabbitmq-diagnostics
            - ping
          initialDelaySeconds: 20
          periodSeconds: 10
        livenessProbe:
          exec:
            command:
            - rabbitmq-diagnostics
            - ping
          initialDelaySeconds: 60
          periodSeconds: 30
---
apiVersion: v1
kind: Service
metadata:
  name: rabbitmq-service
  namespace: ecommerce
  labels:
    app: rabbitmq
spec:
  selector:
    app: rabbitmq
  ports:
  - port: 5672
    targetPort: 5672
    name: amqp
  - port: 15672
    targetPort: 15672
    name: management
  type: ClusterIP
```

```bash
# 部署RabbitMQ
kubectl apply -f manifests/rabbitmq-deployment.yaml

# 验证RabbitMQ部署
kubectl get pods,services -l app=rabbitmq -n ecommerce

# 测试RabbitMQ连接
kubectl exec -n ecommerce -it deployment/rabbitmq -- rabbitmq-diagnostics ping
# 应返回：Ping succeeded
```

### 步骤7：部署用户服务

```yaml
# manifests/user-service-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: ecommerce
  labels:
    app: user-service
    tier: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: user-service
  template:
    metadata:
      labels:
        app: user-service
        tier: backend
        version: v1.0
    spec:
      containers:
      - name: user-service
        image: user-service:1.0
        imagePullPolicy: Never
        ports:
        - containerPort: 5001
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
        - name: RABBITMQ_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: rabbitmq_url
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
            port: 5001
          initialDelaySeconds: 15
          periodSeconds: 10
          timeoutSeconds: 5
        livenessProbe:
          httpGet:
            path: /health
            port: 5001
          initialDelaySeconds: 30
          periodSeconds: 15
          timeoutSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: ecommerce
  labels:
    app: user-service
spec:
  selector:
    app: user-service
  ports:
  - name: http
    port: 80
    targetPort: 5001
  type: ClusterIP
```

```bash
# 部署用户服务
kubectl apply -f manifests/user-service-deployment.yaml

# 验证部署状态
kubectl get pods,services -l app=user-service -n ecommerce

# 查看用户服务日志
kubectl logs -f deployment/user-service -n ecommerce

# 测试用户服务健康检查
kubectl exec -n ecommerce -it deployment/user-service -- curl http://localhost:5001/health
```

### 步骤8：部署其他微服务

```yaml
# manifests/product-service-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: product-service
  namespace: ecommerce
  labels:
    app: product-service
    tier: backend
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
        version: v1.0
    spec:
      containers:
      - name: product-service
        image: product-service:1.0
        imagePullPolicy: Never
        ports:
        - containerPort: 5002
          name: http
        env:
        - name: DATABASE_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: product_database_url
        - name: REDIS_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: redis_product_url
        - name: RABBITMQ_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: rabbitmq_url
        - name: FLASK_ENV
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: flask_env
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
            port: 5002
          initialDelaySeconds: 15
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: 5002
          initialDelaySeconds: 30
          periodSeconds: 15
---
apiVersion: v1
kind: Service
metadata:
  name: product-service
  namespace: ecommerce
  labels:
    app: product-service
spec:
  selector:
    app: product-service
  ports:
  - name: http
    port: 80
    targetPort: 5002
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  namespace: ecommerce
  labels:
    app: order-service
    tier: backend
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
        version: v1.0
    spec:
      containers:
      - name: order-service
        image: order-service:1.0
        imagePullPolicy: Never
        ports:
        - containerPort: 5003
          name: http
        env:
        - name: DATABASE_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: order_database_url
        - name: REDIS_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: redis_order_url
        - name: RABBITMQ_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: rabbitmq_url
        - name: USER_SERVICE_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: user_service_url
        - name: PRODUCT_SERVICE_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: product_service_url
        - name: FLASK_ENV
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: flask_env
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
            port: 5003
          initialDelaySeconds: 15
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: 5003
          initialDelaySeconds: 30
          periodSeconds: 15
---
apiVersion: v1
kind: Service
metadata:
  name: order-service
  namespace: ecommerce
  labels:
    app: order-service
spec:
  selector:
    app: order-service
  ports:
  - name: http
    port: 80
    targetPort: 5003
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notification-service
  namespace: ecommerce
  labels:
    app: notification-service
    tier: backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: notification-service
  template:
    metadata:
      labels:
        app: notification-service
        tier: backend
        version: v1.0
    spec:
      containers:
      - name: notification-service
        image: notification-service:1.0
        imagePullPolicy: Never
        ports:
        - containerPort: 5004
          name: http
        env:
        - name: DATABASE_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: notification_database_url
        - name: REDIS_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: redis_notification_url
        - name: RABBITMQ_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: rabbitmq_url
        - name: EMAIL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secret
              key: email_password
        - name: SMS_API_KEY
          valueFrom:
            secretKeyRef:
              name: app-secret
              key: sms_api_key
        - name: FLASK_ENV
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: flask_env
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
            port: 5004
          initialDelaySeconds: 15
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: 5004
          initialDelaySeconds: 30
          periodSeconds: 15
---
apiVersion: v1
kind: Service
metadata:
  name: notification-service
  namespace: ecommerce
  labels:
    app: notification-service
spec:
  selector:
    app: notification-service
  ports:
  - name: http
    port: 80
    targetPort: 5004
  type: ClusterIP
```

```bash
# 部署所有微服务
kubectl apply -f manifests/product-service-deployment.yaml

# 验证所有服务部署状态
kubectl get all -n ecommerce

# 检查所有Pod状态
kubectl get pods -n ecommerce

# 等待所有Pod就绪
kubectl wait --for=condition=ready pod -l tier=backend -n ecommerce --timeout=300s
```

### 步骤9：创建API网关

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
    
    upstream notification_service {
        server notification-service:80;
    }
    
    server {
        listen 80;
        server_name localhost;
        
        # 健康检查端点
        location /health {
            access_log off;
            return 200 "API Gateway is healthy\n";
            add_header Content-Type text/plain;
        }
        
        # 用户服务路由
        location /api/v1/register {
            proxy_pass http://user_service;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
        
        location /api/v1/login {
            proxy_pass http://user_service;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
        
        location ~ ^/api/v1/(profile|logout|users) {
            proxy_pass http://user_service;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
        
        # 商品服务路由
        location ~ ^/api/v1/(products|categories) {
            proxy_pass http://product_service;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
        
        # 订单服务路由
        location ~ ^/api/v1/orders {
            proxy_pass http://order_service;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
        
        # 通知服务路由
        location ~ ^/api/v1/(notifications|templates) {
            proxy_pass http://notification_service;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
        
        # 健康检查路由
        location /health/user {
            proxy_pass http://user_service/health;
            proxy_set_header Host $host;
        }
        
        location /health/product {
            proxy_pass http://product_service/health;
            proxy_set_header Host $host;
        }
        
        location /health/order {
            proxy_pass http://order_service/health;
            proxy_set_header Host $host;
        }
        
        location /health/notification {
            proxy_pass http://notification_service/health;
            proxy_set_header Host $host;
        }
        
        # 默认路由
        location / {
            return 200 '
<!DOCTYPE html>
<html>
<head>
    <title>电商微服务 API Gateway</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; }
        h1 { color: #333; text-align: center; }
        .service { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .endpoint { font-family: monospace; background: #f8f8f8; padding: 5px; margin: 5px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🛒 电商微服务 API Gateway</h1>
        <p>Kubernetes部署版本 - 微服务架构</p>
        
        <div class="service">
            <h3>👤 用户服务</h3>
            <div class="endpoint">POST /api/v1/register - 用户注册</div>
            <div class="endpoint">POST /api/v1/login - 用户登录</div>
            <div class="endpoint">GET /api/v1/profile - 用户信息</div>
            <div class="endpoint">健康检查: <a href="/health/user">/health/user</a></div>
        </div>
        
        <div class="service">
            <h3>📦 商品服务</h3>
            <div class="endpoint">GET /api/v1/products - 商品列表</div>
            <div class="endpoint">GET /api/v1/categories - 分类列表</div>
            <div class="endpoint">健康检查: <a href="/health/product">/health/product</a></div>
        </div>
        
        <div class="service">
            <h3>📋 订单服务</h3>
            <div class="endpoint">POST /api/v1/orders - 创建订单</div>
            <div class="endpoint">GET /api/v1/orders - 订单列表</div>
            <div class="endpoint">健康检查: <a href="/health/order">/health/order</a></div>
        </div>
        
        <div class="service">
            <h3>📬 通知服务</h3>
            <div class="endpoint">POST /api/v1/notifications - 发送通知</div>
            <div class="endpoint">GET /api/v1/templates - 通知模板</div>
            <div class="endpoint">健康检查: <a href="/health/notification">/health/notification</a></div>
        </div>
        
        <p style="text-align: center; margin-top: 30px;">
            <strong>系统状态:</strong> 
            <a href="/health">网关健康检查</a>
        </p>
    </div>
</body>
</html>
            ';
            add_header Content-Type text/html;
        }
        
        # 错误页面
        error_page 404 = @404;
        location @404 {
            return 404 '{"error": "Resource not found", "status": 404}';
            add_header Content-Type application/json;
        }
        
        error_page 500 502 503 504 = @50x;
        location @50x {
            return 500 '{"error": "Internal server error", "status": 500}';
            add_header Content-Type application/json;
        }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  namespace: ecommerce
  labels:
    app: api-gateway
    tier: frontend
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
        version: v1.0
    spec:
      containers:
      - name: nginx
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
          name: http
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
        readinessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
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
  labels:
    app: api-gateway
spec:
  selector:
    app: api-gateway
  ports:
  - name: http
    port: 80
    targetPort: 80
    nodePort: 30080
  type: NodePort
```

```bash
# 部署API网关
kubectl apply -f manifests/api-gateway.yaml

# 验证API网关部署
kubectl get pods,services -l app=api-gateway -n ecommerce

# 获取API网关访问地址
minikube service api-gateway -n ecommerce --url
# 或对于其他环境：
kubectl get service api-gateway -n ecommerce
```

## 🧪 测试和验证解答

### 系统健康检查

```bash
# 检查所有Pod状态
kubectl get pods -n ecommerce
# 所有Pod应该处于Running状态

# 检查所有Service
kubectl get services -n ecommerce
# 应显示所有服务的ClusterIP

# 检查Endpoints
kubectl get endpoints -n ecommerce
# 每个Service应该有对应的Pod IP地址

# 全面健康检查
for service in user-service product-service order-service notification-service; do
  echo "Testing $service..."
  kubectl exec -n ecommerce -it deployment/api-gateway -- curl -f http://$service/health || echo "FAILED"
done
```

### 服务间通信测试

```bash
# 测试数据库连接
kubectl exec -n ecommerce -it deployment/postgres -- psql -U postgres -d ecommerce -c "
  CREATE DATABASE IF NOT EXISTS ecommerce_users;
  CREATE DATABASE IF NOT EXISTS ecommerce_products;
  CREATE DATABASE IF NOT EXISTS ecommerce_orders;
  CREATE DATABASE IF NOT EXISTS ecommerce_notifications;
  \l"

# 测试Redis连接
kubectl exec -n ecommerce -it deployment/redis -- redis-cli -a redis123 info server

# 测试RabbitMQ连接
kubectl exec -n ecommerce -it deployment/rabbitmq -- rabbitmqctl status

# 测试微服务间调用
kubectl exec -n ecommerce -it deployment/order-service -- curl http://user-service/health
kubectl exec -n ecommerce -it deployment/order-service -- curl http://product-service/health
```

### API网关功能测试

```bash
# 获取网关地址
GATEWAY_URL=$(minikube service api-gateway -n ecommerce --url)

# 测试网关首页
curl $GATEWAY_URL

# 测试健康检查路由
curl $GATEWAY_URL/health
curl $GATEWAY_URL/health/user
curl $GATEWAY_URL/health/product
curl $GATEWAY_URL/health/order
curl $GATEWAY_URL/health/notification

# 测试API路由（需要等待服务完全启动）
curl -X GET $GATEWAY_URL/api/v1/products
curl -X GET $GATEWAY_URL/api/v1/categories
```

### 负载测试

```bash
# 创建测试客户端
kubectl run load-test -n ecommerce --image=busybox --rm -it --restart=Never -- sh

# 在测试容器内执行压力测试：
for i in {1..100}; do
  wget -qO- http://api-gateway/health/user && echo " - Request $i success"
done

# 测试负载均衡
for i in {1..20}; do
  wget -qO- http://api-gateway/health/product
done
```

## 📊 监控和管理解答

### 资源监控

```bash
# 查看Pod资源使用
kubectl top pods -n ecommerce

# 查看节点资源使用
kubectl top nodes

# 查看持久化存储状态
kubectl get pvc -n ecommerce

# 查看存储使用情况
kubectl exec -n ecommerce -it deployment/postgres -- df -h /var/lib/postgresql/data
```

### 日志管理

```bash
# 查看各服务日志
kubectl logs -f deployment/user-service -n ecommerce
kubectl logs -f deployment/product-service -n ecommerce
kubectl logs -f deployment/order-service -n ecommerce
kubectl logs -f deployment/notification-service -n ecommerce

# 查看API网关访问日志
kubectl logs -f deployment/api-gateway -n ecommerce

# 查看所有服务的最近日志
kubectl logs --tail=50 -l tier=backend -n ecommerce

# 查看Pod事件
kubectl describe pods -n ecommerce | grep -A 10 Events
```

### 故障排查

```bash
# 检查Pod状态异常
kubectl describe pod <pod-name> -n ecommerce

# 检查Service Endpoints
kubectl describe svc <service-name> -n ecommerce

# 检查ConfigMap和Secret
kubectl describe configmap app-config -n ecommerce
kubectl describe secret app-secret -n ecommerce

# 网络连通性测试
kubectl run network-test -n ecommerce --image=busybox --rm -it --restart=Never -- sh
# 在容器内测试：
# nslookup user-service
# wget -qO- http://user-service/health
```

## 🔧 扩容和更新解答

### 水平扩容

```bash
# 扩容用户服务
kubectl scale deployment user-service --replicas=5 -n ecommerce

# 扩容商品服务
kubectl scale deployment product-service --replicas=3 -n ecommerce

# 扩容API网关
kubectl scale deployment api-gateway --replicas=3 -n ecommerce

# 验证扩容结果
kubectl get pods -l tier=backend -n ecommerce
kubectl get pods -l tier=frontend -n ecommerce

# 测试负载分发
for i in {1..10}; do
  curl $GATEWAY_URL/health/user
done
```

### 滚动更新

```bash
# 假设有新版本镜像
# 首先构建新版本（在第一阶段项目目录）
cd ../../phase1-containerization/ecommerce-basic
eval $(minikube docker-env)
docker tag user-service:1.0 user-service:1.1

cd ../../phase2-orchestration/kubernetes-basics

# 执行滚动更新
kubectl set image deployment/user-service user-service=user-service:1.1 -n ecommerce

# 观察更新过程
kubectl rollout status deployment/user-service -n ecommerce

# 查看更新历史
kubectl rollout history deployment/user-service -n ecommerce

# 如需回滚
kubectl rollout undo deployment/user-service -n ecommerce
```

## 📝 检查清单验证

| 检查项 | 验证命令 | 预期结果 |
|--------|----------|----------|
| 命名空间创建 | `kubectl get ns ecommerce` | Active状态 |
| 数据库部署 | `kubectl get pods -l app=postgres -n ecommerce` | Running状态 |
| 缓存部署 | `kubectl get pods -l app=redis -n ecommerce` | Running状态 |
| 消息队列部署 | `kubectl get pods -l app=rabbitmq -n ecommerce` | Running状态 |
| 微服务部署 | `kubectl get pods -l tier=backend -n ecommerce` | 所有Pod Running |
| 配置管理 | `kubectl get configmaps,secrets -n ecommerce` | 配置和密钥存在 |
| 服务发现 | `kubectl get endpoints -n ecommerce` | 所有Service有Endpoints |
| API网关 | `curl $(minikube service api-gateway -n ecommerce --url)` | 返回首页 |
| 健康检查 | `curl $GATEWAY_URL/health/user` | 所有服务健康 |
| 服务间通信 | `kubectl exec -n ecommerce deployment/order-service -- curl user-service/health` | 成功调用 |

## 💡 关键概念总结

### 微服务部署模式

```
API Gateway (Nginx)
    ↓ 路由请求
微服务层 (User, Product, Order, Notification)
    ↓ 数据访问
数据层 (PostgreSQL, Redis, RabbitMQ)
```

### 配置管理最佳实践

1. **ConfigMap**：存储非敏感配置
2. **Secret**：存储敏感信息（密码、密钥）
3. **环境变量**：注入配置到容器
4. **Volume挂载**：挂载配置文件

### 服务发现机制

```
DNS解析: service-name.namespace.svc.cluster.local
简化形式: service-name (同命名空间内)
环境变量: {SERVICE_NAME}_SERVICE_HOST/PORT
```

### 健康检查策略

```yaml
readinessProbe:  # 就绪检查 - 决定是否接收流量
  httpGet:
    path: /health
    port: 5001
  initialDelaySeconds: 15
  periodSeconds: 10

livenessProbe:   # 存活检查 - 决定是否重启容器
  httpGet:
    path: /health
    port: 5001
  initialDelaySeconds: 30
  periodSeconds: 15
```

## 🎯 学习成果总结

完成本练习后，你已经成功：

1. **完整迁移**：将Docker Compose应用完全迁移到Kubernetes
2. **微服务治理**：实现了服务发现、负载均衡、健康检查
3. **配置管理**：使用ConfigMap和Secret管理应用配置
4. **数据持久化**：使用PVC实现数据库数据持久化
5. **网络架构**：通过API网关实现统一的服务入口
6. **可观测性**：实现了日志收集和监控机制
7. **扩容能力**：掌握了水平扩容和滚动更新

**技能掌握程度**：
- ✅ Kubernetes资源对象的综合运用
- ✅ 微服务架构在Kubernetes中的实现
- ✅ 生产级部署的配置和管理
- ✅ 故障排查和性能调优能力

**下一步发展方向**：
1. 学习Helm进行包管理
2. 集成监控和日志收集系统
3. 实现CI/CD自动化部署
4. 学习服务网格（Istio）
5. 实现多环境部署策略

**恭喜！你已经具备了在Kubernetes中部署和管理复杂企业级微服务应用的能力！** 🎉