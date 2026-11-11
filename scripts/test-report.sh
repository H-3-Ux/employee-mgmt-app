#!/bin/bash
API=localhost:8080/api
TOKEN=$(curl -s -X POST $API/auth/login -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' | python3 -c "import sys,json;print(json.load(sys.stdin)['token'])")
H="Authorization: Bearer $TOKEN"; FROM=$(date +%Y-%m-01); TO=$(date +%F)

echo "== 1. Summary (current month) =="
curl -s "$API/reports/summary?from=$FROM&to=$TO" -H "$H" | python3 -m json.tool
echo "== 2. Report list (3 rows) =="
curl -s "$API/reports/employees?size=3" -H "$H" | python3 -m json.tool | grep -E '"name"|totalElements'
echo "== 3. Invalid date range =="
curl -s "$API/reports/summary?from=2026-12-01&to=2026-01-01" -H "$H"; echo
echo "== 4. Exports =="
curl -s "$API/reports/export/excel" -H "$H" -o /tmp/report.xlsx
curl -s "$API/reports/export/pdf" -H "$H" -o /tmp/report.pdf
file /tmp/report.xlsx /tmp/report.pdf