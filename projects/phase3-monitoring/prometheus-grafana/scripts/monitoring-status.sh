#!/bin/bash

# 监控栈状态检查脚本

echo "=========================================="
echo "🚀 云原生监控栈集成状态"
echo "=========================================="

echo ""
echo "📊 组件状态:"
echo "----------------------------------------"

# 检查 Pod 状态
echo "Pod 状态:"
kubectl get pods -n monitoring

echo ""
echo "🌐 服务状态:"
echo "----------------------------------------"
kubectl get svc -n monitoring

echo ""
echo "📈 Prometheus 目标状态:"
echo "----------------------------------------"
curl -s "http://localhost:9090/api/v1/targets" | jq '.data.activeTargets[] | {job: .labels.job, instance: .labels.instance, health: .health}'

echo ""
echo "📊 应用指标示例:"
echo "----------------------------------------"
echo "业务操作总数:"
curl -s "http://localhost:9090/api/v1/query?query=business_operations_total" | jq '.data.result[] | {operation: .metric.operation_type, status: .metric.status, value: .value[1]}'

echo ""
echo "🎯 访问信息:"
echo "----------------------------------------"
echo "Prometheus UI: http://localhost:9090"
echo "Grafana UI: http://localhost:3000 (admin/admin123)"
echo "Demo App: http://localhost:8080"
echo ""
echo "Grafana 仪表板:"
echo "- Demo App Monitoring: http://localhost:3000/d/f869485d-b0ec-4b05-b6c2-9b690564f92c/demo-app-monitoring-dashboard"

echo ""
echo "�� 测试命令:"
echo "----------------------------------------"
echo "# 生成测试流量"
echo "curl http://localhost:8080/api/users"
echo "curl http://localhost:8080/api/orders"
echo "curl http://localhost:8080/simulate/load"
echo "curl http://localhost:8080/simulate/error"
echo ""
echo "# 查询指标"
echo "curl 'http://localhost:9090/api/v1/query?query=business_operations_total'"
echo "curl 'http://localhost:9090/api/v1/query?query=http_requests_total'"

echo ""
echo "=========================================="
echo "✅ 集成应用监控任务完成！"
echo "=========================================="
