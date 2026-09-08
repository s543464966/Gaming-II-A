class_name CardTypes
extends RefCounted
## 卡牌只区分内容载体类别，敌我关系由本场队伍身份决定。

enum Kind { CoreHero = 0, Minion = 1, ItemCard = 2, Monster = 4 }
