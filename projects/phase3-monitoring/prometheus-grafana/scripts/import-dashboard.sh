#!/bin/bash

# 导入 Grafana 仪表板脚本

set -e

# 配置变量
GRAFANA_URL=${GRAFANA_URL:-"http://localhost:3000"}
GRAFANA_USER=${GRAFANA_USER:-"admin"}
GRAFANA_PASSWORD=${GRAFANA_PASSWORD:-"admin123"}
DASHBOARD_FILE=${1:-"dashboards/demo-app-monitoring.json"}

echo "导入仪表板: $DASHBOARD_FILE"

# 检查文件是否存在
if [ ! -f "$DASHBOARD_FILE" ]; then
    echo "错误: 仪表板文件不存在: $DASHBOARD_FILE"
    exit 1
fi

# 导入仪表板
echo "正在导入仪表板..."

response=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
  -d @"$DASHBOARD_FILE" \
  "$GRAFANA_URL/api/dashboards/db")

echo "响应: $response"

echo "仪表板导入完成！"
echo "访问 Grafana: $GRAFANA_URL"
echo "用户名: $GRAFANA_USER"
echo "密码: $GRAFANA_PASSWORD"
