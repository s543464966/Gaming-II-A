#!/bin/zsh -l
tool_directory=${0:A:h}
if ! command -v node >/dev/null 2>&1; then
  print -u2 '未找到 Node.js，请安装 Node.js 20.11 或更新版本。'
  read '?按回车关闭…'
  exit 1
fi
node "$tool_directory/export/douyin.mjs" "$@"
douyin_status=$?
if (( douyin_status == 0 )); then
  read '?抖音打包完成，文件已更新到固定目录。按回车关闭…'
else
  read '?打包失败，请查看上方诊断。按回车关闭…'
fi
exit "$douyin_status"
