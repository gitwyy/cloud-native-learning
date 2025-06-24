# 🌐 简单Web应用容器化项目

> 第一阶段第一个项目：将一个简单的Web应用进行容器化

## 🎯 项目目标

- 理解容器化的基本概念和流程
- 学会编写Dockerfile
- 掌握Docker基本命令
- 了解镜像构建和运行

## 📋 项目需求

创建一个简单的Web应用并将其容器化：

1. **应用类型**: 静态网站或简单的动态Web应用
2. **技术栈**: 可选择HTML/CSS/JS、Node.js、Python Flask等
3. **容器化**: 使用Docker进行打包
4. **部署**: 本地运行验证

## 🛠️ 项目结构

```
simple-web-app/
├── README.md              # 项目说明
├── src/                   # 应用源代码
│   ├── index.html        # 主页面
│   ├── style.css         # 样式文件
│   ├── script.js         # JavaScript代码
│   └── assets/           # 静态资源
├── Dockerfile            # Docker镜像构建文件
├── .dockerignore         # Docker忽略文件
└── docker-run.sh         # 运行脚本
```

## 📝 实施步骤

### 步骤1：创建Web应用

#### 选项A：静态网站（推荐初学者）

创建 `src/index.html`：
```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>我的第一个容器化应用</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div class="container">
        <header>
            <h1>🐳 欢迎来到我的容器化世界</h1>
            <p>这是我的第一个Docker应用！</p>
        </header>
        <main>
            <section class="info">
                <h2>应用信息</h2>
                <ul>
                    <li>运行环境: Docker容器</li>
                    <li>Web服务器: Nginx</li>
                    <li>构建时间: <span id="build-time"></span></li>
                </ul>
            </section>
            <section class="stats">
                <h2>容器统计</h2>
                <div class="stat-item">
                    <span class="label">页面访问次数:</span>
                    <span class="value" id="visit-count">0</span>
                </div>
            </section>
        </main>
    </div>
    <script src="script.js"></script>
</body>
</html>
```

创建 `src/style.css`：
```css
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: 'Arial', sans-serif;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    min-height: 100vh;
    color: white;
}

.container {
    max-width: 800px;
    margin: 0 auto;
    padding: 2rem;
}

header {
    text-align: center;
    margin-bottom: 3rem;
}

h1 {
    font-size: 2.5rem;
    margin-bottom: 1rem;
    text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
}

h2 {
    color: #f1c40f;
    margin-bottom: 1rem;
}

.info, .stats {
    background: rgba(255,255,255,0.1);
    padding: 2rem;
    margin-bottom: 2rem;
    border-radius: 10px;
    backdrop-filter: blur(10px);
}

.info ul {
    list-style: none;
}

.info li {
    padding: 0.5rem 0;
    border-bottom: 1px solid rgba(255,255,255,0.2);
}

.stat-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem;
    background: rgba(255,255,255,0.1);
    border-radius: 5px;
}

.value {
    font-size: 1.5rem;
    font-weight: bold;
    color: #f1c40f;
}
```

创建 `src/script.js`：
```javascript
document.addEventListener('DOMContentLoaded', function() {
    // 设置构建时间
    const buildTime = new Date().toLocaleString('zh-CN');
    document.getElementById('build-time').textContent = buildTime;
    
    // 访问计数器（使用localStorage模拟）
    let visitCount = localStorage.getItem('visitCount') || 0;
    visitCount = parseInt(visitCount) + 1;
    localStorage.setItem('visitCount', visitCount);
    document.getElementById('visit-count').textContent = visitCount;
    
    // 添加一些动态效果
    const statItems = document.querySelectorAll('.stat-item');
    statItems.forEach((item, index) => {
        setTimeout(() => {
            item.style.animation = 'fadeInUp 0.6s ease forwards';
        }, index * 200);
    });
});

// 添加CSS动画
const style = document.createElement('style');
style.textContent = `
    @keyframes fadeInUp {
        from {
            opacity: 0;
            transform: translateY(30px);
        }
        to {
            opacity: 1;
            transform: translateY(0);
        }
    }
`;
document.head.appendChild(style);
```

#### 选项B：Node.js应用

创建 `src/package.json`：
```json
{
  "name": "simple-web-app",
  "version": "1.0.0",
  "description": "我的第一个容器化Node.js应用",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
```

创建 `src/server.js`：
```javascript
const express = require('express');
const path = require('path');
const app = express();
const port = process.env.PORT || 3000;

// 静态文件服务
app.use(express.static(path.join(__dirname, 'public')));

// API路由
app.get('/api/info', (req, res) => {
    res.json({
        message: '这是来自容器内的API响应',
        timestamp: new Date().toISOString(),
        hostname: require('os').hostname(),
        nodeVersion: process.version,
        environment: process.env.NODE_ENV || 'development'
    });
});

// 健康检查
app.get('/health', (req, res) => {
    res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.listen(port, '0.0.0.0', () => {
    console.log(`🚀 应用已启动: http://localhost:${port}`);
    console.log(`📊 健康检查: http://localhost:${port}/health`);
    console.log(`🔧 API接口: http://localhost:${port}/api/info`);
});
```

### 步骤2：编写Dockerfile

#### 静态网站版本
```dockerfile
# 使用官方Nginx镜像作为基础镜像
FROM nginx:alpine

# 设置维护者信息
LABEL maintainer="your-email@example.com"
LABEL description="我的第一个容器化Web应用"

# 复制网站文件到Nginx默认目录
COPY src/ /usr/share/nginx/html/

# 暴露80端口
EXPOSE 80

# 启动Nginx（默认命令，可以省略）
CMD ["nginx", "-g", "daemon off;"]
```

#### Node.js版本
```dockerfile
# 使用官方Node.js镜像作为基础镜像
FROM node:18-alpine

# 设置工作目录
WORKDIR /app

# 复制package.json文件（利用Docker缓存）
COPY src/package*.json ./

# 安装依赖
RUN npm ci --only=production

# 复制应用代码
COPY src/ .

# 创建非root用户
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# 切换到非root用户
USER nodejs

# 暴露应用端口
EXPOSE 3000

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })"

# 启动应用
CMD ["npm", "start"]
```

### 步骤3：创建.dockerignore文件

```gitignore
# Node.js相关
node_modules
npm-debug.log
.npm

# 开发文件
.git
.gitignore
README.md
.env
.env.local

# IDE文件
.vscode
.idea
*.swp
*.swo

# 操作系统文件
.DS_Store
Thumbs.db

# 临时文件
*.tmp
*.temp
```

### 步骤4：构建和运行

创建 `docker-run.sh`：
```bash
#!/bin/bash

# 构建Docker镜像
echo "🔨 构建Docker镜像..."
docker build -t simple-web-app:latest .

# 检查构建是否成功
if [ $? -eq 0 ]; then
    echo "✅ 镜像构建成功！"
    
    # 显示镜像信息
    echo "📋 镜像信息:"
    docker images simple-web-app:latest
    
    # 运行容器
    echo "🚀 启动容器..."
    docker run -d \
        --name simple-web-app-container \
        -p 8080:80 \
        --restart unless-stopped \
        simple-web-app:latest
    
    # 检查容器状态
    sleep 2
    if docker ps | grep -q simple-web-app-container; then
        echo "✅ 容器启动成功！"
        echo "🌐 访问地址: http://localhost:8080"
        echo "📊 容器状态:"
        docker ps | grep simple-web-app-container
    else
        echo "❌ 容器启动失败！"
        echo "📋 查看日志:"
        docker logs simple-web-app-container
    fi
else
    echo "❌ 镜像构建失败！"
    exit 1
fi
```

给脚本执行权限：
```bash
chmod +x docker-run.sh
```

## 🧪 测试验证

### 1. 构建镜像
```bash
# 运行构建脚本
./docker-run.sh

# 或手动构建
docker build -t simple-web-app:latest .
```

### 2. 运行容器
```bash
# 后台运行
docker run -d --name simple-web-app -p 8080:80 simple-web-app:latest

# 前台运行（查看日志）
docker run --name simple-web-app -p 8080:80 simple-web-app:latest
```

### 3. 验证功能
```bash
# 测试HTTP访问
curl http://localhost:8080

# 在浏览器中访问
open http://localhost:8080  # macOS
xdg-open http://localhost:8080  # Linux

# 查看容器日志
docker logs simple-web-app

# 查看容器状态
docker ps
docker stats simple-web-app
```

### 4. 管理容器
```bash
# 停止容器
docker stop simple-web-app

# 重启容器
docker restart simple-web-app

# 删除容器
docker rm simple-web-app

# 删除镜像
docker rmi simple-web-app:latest
```

## 📚 学习要点

### Docker核心概念
1. **镜像（Image）**: 只读的模板，包含运行应用所需的所有内容
2. **容器（Container）**: 镜像的运行实例
3. **Dockerfile**: 构建镜像的指令文件
4. **分层存储**: Docker镜像采用分层存储结构

### 最佳实践
1. **多阶段构建**: 对于复杂应用，使用多阶段构建减小镜像大小
2. **缓存优化**: 合理安排Dockerfile指令顺序，提高构建效率
3. **安全性**: 使用非root用户运行应用
4. **健康检查**: 添加健康检查确保容器正常运行

## 🎓 扩展练习

### 初级扩展
1. **修改应用内容**: 更改HTML内容，重新构建并运行
2. **添加环境变量**: 通过环境变量配置应用
3. **挂载数据卷**: 将日志或数据持久化存储

### 中级扩展
1. **多阶段构建**: 实现构建和运行阶段分离
2. **镜像优化**: 减小镜像大小，提高安全性
3. **CI/CD集成**: 编写自动构建脚本

### 高级扩展
1. **跨平台构建**: 支持多架构镜像（AMD64、ARM64）
2. **私有仓库**: 推送镜像到私有Docker仓库
3. **容器编排**: 为下一阶段学习做准备

## ✅ 完成检查清单

- [ ] 成功创建Web应用源代码
- [ ] 编写合适的Dockerfile
- [ ] 配置.dockerignore文件
- [ ] 成功构建Docker镜像
- [ ] 运行容器并验证功能
- [ ] 理解镜像分层存储概念
- [ ] 掌握基本的Docker命令
- [ ] 能够排查常见问题

## 🔗 相关资源

- [Docker官方文档](https://docs.docker.com/)
- [Dockerfile最佳实践](https://docs.docker.com/develop/dev-best-practices/)
- [Docker镜像优化指南](https://docs.docker.com/develop/dev-best-practices/)

---

**🎉 恭喜！** 完成这个项目后，您已经掌握了容器化的基础知识。准备好进入下一个项目：[多服务应用编排](../multi-service-app/) 了吗？