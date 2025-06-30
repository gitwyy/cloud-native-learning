const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

// 中间件
app.use(express.json());

// 请求日志中间件
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// 根路径
app.get('/', (req, res) => {
  res.json({
    message: 'Hello from GitHub Actions CI/CD Pipeline! 🚀',
    version: process.env.APP_VERSION || '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    timestamp: new Date().toISOString(),
    hostname: require('os').hostname()
  });
});

// 健康检查端点
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'healthy',
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  });
});

// 就绪检查端点
app.get('/ready', (req, res) => {
  // 这里可以添加数据库连接检查等逻辑
  res.status(200).json({ 
    status: 'ready',
    timestamp: new Date().toISOString()
  });
});

// API信息端点
app.get('/api/info', (req, res) => {
  res.json({
    name: 'Sample CI/CD App',
    version: process.env.APP_VERSION || '1.0.0',
    description: 'A sample application for CI/CD pipeline practice',
    endpoints: [
      'GET /',
      'GET /health',
      'GET /ready',
      'GET /api/info',
      'GET /api/users',
      'POST /api/users'
    ]
  });
});

// 模拟用户API
let users = [
  { id: 1, name: 'Alice', email: 'alice@example.com' },
  { id: 2, name: 'Bob', email: 'bob@example.com' }
];

app.get('/api/users', (req, res) => {
  res.json(users);
});

app.post('/api/users', (req, res) => {
  const { name, email } = req.body;
  
  if (!name || !email) {
    return res.status(400).json({ error: 'Name and email are required' });
  }
  
  const newUser = {
    id: users.length + 1,
    name,
    email
  };
  
  users.push(newUser);
  res.status(201).json(newUser);
});

// 错误处理中间件
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Something went wrong!' });
});

// 404处理
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

const server = app.listen(port, () => {
  console.log(`🚀 App listening on port ${port}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Version: ${process.env.APP_VERSION || '1.0.0'}`);
});

// 优雅关闭处理
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(() => {
    console.log('Process terminated');
  });
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  server.close(() => {
    console.log('Process terminated');
  });
});

module.exports = app;
