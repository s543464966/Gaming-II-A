# 骨架验证

从工作区根运行：

```sh
node Testing/scripts/run_godot.mjs architecture home
```

默认运行上述两组；也可单独指定。Architecture 检查真实主场景装配及页面替换后 App、服务和浮层容器的存活；Home 检查独立场景加载、可见布局和 Theme 资源。

每次将当前工程复制到 `Testing/.runtime/<run-id>/project/`，排除 Git 与缓存，先由 Godot 重新导入，再运行场景检查。成功必须同时满足退出码、无脚本或资源错误，以及每组完成标记。通过后自动清理；失败诊断保留于输出的精确目录，读取后清理。检查不读取旧账号或进度。

旧业务测试已退役，当前没有玩法、数据管线或平台 SDK 可供验证；此检查不代表平台导出或真机通过。
