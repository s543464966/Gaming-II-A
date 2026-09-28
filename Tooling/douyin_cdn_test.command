#!/bin/zsh -l
tool_directory=${0:A:h}
if ! command -v node >/dev/null 2>&1; then
  print -u2 '未找到 Node.js，请安装 Node.js 20.11 或更新版本。'
  read '?按回车关闭…'
  exit 1
fi
node "$tool_directory/export/douyin.mjs" --delivery cloudflare-cdn "$@"
cdn_status=$?
if (( cdn_status != 0 )); then
  read '?CDN 测试失败，请查看上方诊断。按回车关闭…'
fi
exit "$cdn_status"
