@echo off
REM 启动后端服务器（强制使用 Python 3.9）
echo 启动后端服务器...
cd "%~dp0Sync"
d:\python39\python.exe manage.py runserver 0.0.0.0:8000
echo 后端服务器已停止
pause