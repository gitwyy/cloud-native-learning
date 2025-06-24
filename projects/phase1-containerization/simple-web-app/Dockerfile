# 使用官方Python 3.11 slim镜像作为基础镜像
FROM python:3.11-slim

# 设置镜像标签信息
LABEL maintainer="cloud-native-learner@example.com"
LABEL description="简单的Flask Web应用容器化示例"
LABEL version="1.0.0"

# 设置工作目录
WORKDIR /app

# 设置环境变量
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    FLASK_APP=app.py \
    FLASK_ENV=production \
    FLASK_HOST=0.0.0.0 \
    FLASK_PORT=5000

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 复制依赖文件（利用Docker层缓存优化）
COPY requirements.txt .

# 安装Python依赖
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# 复制应用代码
COPY . .

# 创建非root用户以提高安全性
RUN groupadd -r flaskuser && useradd -r -g flaskuser flaskuser && \
    chown -R flaskuser:flaskuser /app

# 切换到非root用户
USER flaskuser

# 暴露应用端口
EXPOSE 5000

# 添加健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# 使用gunicorn作为WSGI服务器运行应用
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--threads", "2", "--timeout", "60", "app:app"]