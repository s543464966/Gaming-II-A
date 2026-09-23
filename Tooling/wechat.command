#!/bin/zsh -l
tool_directory=${0:A:h}
if ! command -v node >/dev/null 2>&1; then
  print -u2 '未找到 Node.js，请安装 Node.js 20.11 或更新版本。'
  read '?按回车关闭…'
  exit 1
fi
node "$tool_directory/export/wechat.mjs" "$@"
wechat_status=$?
if (( wechat_status == 0 )); then
  read '?打包完成。请在微信开发者工具点击“编译”。按回车关闭…'
else
  read '?打包失败，请查看上方诊断。按回车关闭…'
fi
exit "$wechat_status"
