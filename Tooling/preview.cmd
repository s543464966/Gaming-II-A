@echo off
setlocal
chcp 65001 >nul

node.exe --version >nul 2>&1
if errorlevel 1 (
  echo 未找到 Node.js，请安装 Node.js 20 或更新版本后重试。
  pause
  exit /b 1
)

node.exe "%~dp0preview\preview.mjs" %*
set "preview_status=%errorlevel%"
if "%preview_status%"=="0" exit /b 0
if "%preview_status%"=="130" exit /b 130

echo 预览失败，请查看上方诊断。
echo 如果未找到 Godot，请将 Godot 加入 PATH，或用 GODOT_BIN 指定可执行文件的完整路径。
pause
exit /b %preview_status%
