# 缺氧行星

[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat)](http://makeapullrequest.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

简介

## 环境
[Unity 2022.3.13f1c1 (LTS)](https://unity.cn/release-notes/full/2022/2022.3.13f1)

## 游戏逻辑和功能

## 规范
文件 | 文件内容
-|-
Maps | 地图集合，父物体，存放场景中所有子地形类物体
View | 镜头集合，父物体，存放场景中所有镜头类物体
Character| 角色集合，父物体，存放场景中所有角色类物体

名称 | 作用
-|-
Monster | 怪物名称
Players | 探险家名称的前缀
zzz | 项目未使用到的素材用前缀标记

层级结构 | 层次内容
-|-
-CcTempStorages | 临时存储中心，用于短生命物体存储，如子弹
-CcDamages | 伤害处理中心，用于汇总计算单位伤害
-CcAutoMow | 自动割草中心，用于玩家及怪物自动攻击