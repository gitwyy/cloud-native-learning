# 多阶段构建的Dockerfile
# 第一阶段：构建阶段
FROM node:18-alpine AS builder

# 设置工作目录
WORKDIR /app

# 复制package文件
COPY package*.json ./

# 安装依赖（包括开发依赖，用于运行测试）
RUN npm ci --only=production && npm cache clean --force

# 第二阶段：运行阶段
FROM node:18-alpine AS runtime

# 创建非root用户
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# 设置工作目录
WORKDIR /app

# 从构建阶段复制node_modules
COPY --from=builder /app/node_modules ./node_modules

# 复制应用代码
COPY --chown=nodejs:nodejs src/ ./src/
COPY --chown=nodejs:nodejs package*.json ./

# 设置环境变量
ENV NODE_ENV=production
ENV PORT=3000

# 暴露端口
EXPOSE 3000

# 切换到非root用户
USER nodejs

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })"

# 启动应用
CMD ["node", "src/app.js"]
