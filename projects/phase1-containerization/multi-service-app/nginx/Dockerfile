# ==============================================================================
# Nginx反向代理Dockerfile
# ==============================================================================

FROM nginx:alpine

# 安装必要工具
RUN apk add --no-cache \
    curl \
    wget \
    openssl \
    && rm -rf /var/cache/apk/*

# 复制配置文件
COPY nginx.conf /etc/nginx/nginx.conf
COPY conf.d/ /etc/nginx/conf.d/

# 创建日志目录
RUN mkdir -p /var/log/nginx \
    && touch /var/log/nginx/access.log \
    && touch /var/log/nginx/error.log

# 创建SSL目录
RUN mkdir -p /etc/nginx/ssl

# 创建静态文件目录
RUN mkdir -p /var/www/static

# 设置权限
RUN chown -R nginx:nginx /var/www/static \
    && chmod -R 755 /var/www/static

# 暴露端口
EXPOSE 80 443

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# 启动Nginx
CMD ["nginx", "-g", "daemon off;"]