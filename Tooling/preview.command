#!/bin/zsh -l
tool_directory=${0:A:h}
if ! command -v node >/dev/null 2>&1; then
  print -u2 '未找到 Node.js，请安装 Node.js 20 或更新版本。'
  read '?按回车关闭…'
  exit 1
fi
node "$tool_directory/preview/preview.mjs" "$@"
preview_status=$?
if (( preview_status != 0 && preview_status != 130 )); then
  read '?预览失败，请查看上方诊断。按回车关闭…'
fi
exit "$preview_status"
