class_name ContentTypes
extends RefCounted
## 静态内容的稳定枚举，数值保持现有数据和存档语义。

enum Currency { Gold, StarStone, RMB }
enum ShopTab { Recommend, Hero, Minion, Item, Relic }
enum Payment { Gold, StarStone, Fragments }
enum BuyResult { Success, SoldOut, NotEnoughCurrency, InventoryFull, ItemNotFound, PaymentUnavailable, AlreadyOwned, SaveFailed, Busy }
enum Item { None, Material, Prop }
# 旧治疗效果的整数 1 已退役，不能复用为新效果。
enum NodeEffect { None = 0, GrantCurrency = 2, ExchangeCurrency = 3, AuroraChoice = 4, BlackMarket = 5, Encounter = 6 }
## 星能奖励类别独立于战斗能力与骰子奖励。
enum AuroraReward { StarStone, MinionFragments, RelicFragments, HeroFragment, Stamina, Gold, CardUpgrade, Relic }
## 奇遇收获与代价分别保存，随机组合不依赖玩家当前资格。
enum EncounterReward { Dice, StarStone, Relic, Card }
enum EncounterCost { Stamina, TeamDebuff, Card, Dice }
enum MonsterRole { None, Normal, Elite, Boss }
enum DiceKind { Relic = 0, Card = 1, StarStone = 2, Treasure = 3 }
## 已退役奖励的整数身份留空，不复用于新内容。
enum DiceReward { Relic = 0, Minion = 4, ItemCard = 5, StarStone = 6, Fragment = 7, HeroGrowth = 8 }
enum RelicUsage { Persistent, Consumable }
enum Difficulty { Normal = 1, Hard = 2, Hell = 3 }
# 营地整数 4 仅由旧存档迁移识别，其余节点保持原编号。
enum NodeType { Start = 0, NormalBattle = 1, EliteBattle = 2, BossBattle = 3, Relic = 5, BlackMarket = 6, Adventure = 7 }

const DEFAULT_HERO = "H001"
## 账号商城的遗物解锁与本章获得的实际遗物分别保存。
static func shop_tab(record: Dictionary) -> int:
	if record.get("card_kind") == CardTypes.Kind.CoreHero: return ShopTab.Hero
	if record.get("card_kind") == CardTypes.Kind.Minion: return ShopTab.Minion
	if record.get("card_kind") == CardTypes.Kind.ItemCard: return ShopTab.Item
	if record.has("usage"): return ShopTab.Relic
	return ShopTab.Recommend
