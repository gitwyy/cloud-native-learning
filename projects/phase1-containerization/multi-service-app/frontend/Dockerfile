# ==============================================================================
# Vue.js 前端应用 Dockerfile
# ==============================================================================

# 构建阶段
FROM node:18-alpine AS builder

# 设置工作目录
WORKDIR /app

# 复制package文件
COPY package*.json ./
COPY pnpm-lock.yaml ./

# 安装pnpm
RUN npm install -g pnpm

# 安装依赖
RUN pnpm install

# 复制源代码
COPY . .

# 构建应用
RUN pnpm build

# 调试：检查构建结果
RUN ls -la /app/
RUN ls -la /app/dist/ || echo "dist目录不存在"

# 生产阶段
FROM nginx:alpine

# 安装curl用于健康检查
RUN apk add --no-cache curl

# 复制构建后的文件
COPY --from=builder /app/dist /usr/share/nginx/html

# 复制public目录中的静态文件（如果dist中没有包含）
COPY --from=builder /app/public/favicon.ico /usr/share/nginx/html/

# 复制Nginx配置
COPY nginx.conf /etc/nginx/nginx.conf

# 创建健康检查页面
RUN echo "healthy" > /usr/share/nginx/html/health

# 调试：检查最终文件
RUN ls -la /usr/share/nginx/html/

# 暴露端口
EXPOSE 80

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# 启动nginx
CMD ["nginx", "-g", "daemon off;"]