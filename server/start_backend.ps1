# 启动后端服务器（强制使用 Python 3.9）
Write-Host "启动后端服务器..."
# 切换到 Sync 目录
Set-Location -Path "$PSScriptRoot\Sync"
# 使用 Python 3.9 运行服务器
& "d:\python39\python.exe" "manage.py" runserver 0.0.0.0:8000
Write-Host "后端服务器已停止"
Read-Host "按 Enter 键继续..."