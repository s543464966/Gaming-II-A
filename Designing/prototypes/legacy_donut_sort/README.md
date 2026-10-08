# 早期局内交互原型

2026-09-30 随策划资料迁入。保留 `index.html`、`styles.css`、`main.mjs` 和 `engine.mjs`，供查阅早期交互设计；这是旧 4×4 演示关，不是当前 Godot 游戏，不承接新关卡或正式功能开发。

旧测试迁至 [Testing/planning/legacy_donut_sort_test.mjs](../../../Testing/planning/legacy_donut_sort_test.mjs)，从仓库根执行：

```text
node --test Testing/planning/legacy_donut_sort_test.mjs
```

旧服务器源码仅作为 [历史文本](../../history/prototype_server.cjs.txt) 保留，不作为启动入口；不得占用正式游戏的 4173 端口。实际游戏开发、运行和验证见 [工程说明](../../../Coding/godot/README.md) 与 [工作区工具](../../../Tooling/README.md)。
