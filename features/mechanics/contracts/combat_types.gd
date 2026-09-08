class_name CombatTypes
extends RefCounted
## 稳定的战斗枚举契约；不持有状态、计算数值或装配内容。

enum Event {
	BattleStarted, MainAbilityCooldownReady, BeforeMainAbilityCast, AfterMainAbilityCast,
	AdjacentMainAbilityCast, DamageResolved, ShieldGained, HealingResolved,
	StatusApplied, PollutionChanged, PollutionThresholdReached, CoreDamaged,
	MinionDefeated, AlliedMinionDefeated, LastMinionDefeated, ItemDisabled, BattleCompleted,
	HasteGained, ActionReleased, CounterChanged, CounterThresholdReached,
	UnitDefeated, DamageGuarded, LinkedMainAbilityCast, MarkApplied, MechanicResolved, TimeLimitResolved
}
enum AbilityExecution { CooldownMain, TriggeredPassive, PersistentBonus, ConditionalPassive }
## 内容分类不同于执行方式；来源与作用范围不参与分类。
enum AbilityCategory { Main, Passive, Bonus }
## 触发词条是事件与必要身份过滤的简写，不是能力分类或执行器。
enum TriggerKeyword { BattleStart, Kill, Deathrattle }
## 队伍常驻贡献随成员资格保留，战场光环仍依赖存活与范围。
enum ContributionLifetime { Battlefield, TeamMembership }
enum CombatAction { PhysicalDamage, Heal, GrantShield, ApplyStatus, ChangePollution, Charge, DelayCooldown, GrantMainAbility, Haste, RefillAmmo, ExpandAmmo, Witchcraft, Accumulate, Detonate, Mark, Empower, Guard, Link, Convert, Transfer, CopyMainAbility, Transform, Overload, Chain, Echo, Sacrifice }
enum Status { None, Burn, Poison, Freeze, Slow, Stun }
enum Target { Self, EventSource, EventTarget, NearestEnemy, FarthestEnemy, LowestHealthAlly, AllEnemies, AllAllies, AdjacentAllies, RandomEnemy, AllUnits, NearestAlly, MarkedEnemy, LinkedAlly, AlliedMinion }
enum Condition { Always, OwnerHealthAtMostPercent, PollutionAtLeast, PollutionAtMost, EventSourceIsOwner, EventTargetIsOwner, EventSourceIsMinion, EventTargetIsCore, OwnerHasStatus, EventSourceIsAdjacent, EventSourceIsAlly, EventSourceIsEnemy, EventIsCritical, EventSourceHasAmmo, OwnerCounterAtLeast, EventCounterKey, EventTargetMarked, EventSourceIsLinked, EventTargetStatusStacksAtLeast, OwnerHasTags, EventSourceHasTags, EventTargetHasTags, EventIsPrimary, EventTargetIsEnemy, EventHasKillCredit }
enum Completion { Victory, Defeat, Timeout, InvalidRequest, Draw }

## 六种数值输出与无顶部数值的特殊类；不决定能力的触发方式。
enum Output { Physical, Witchcraft, Burn, Poison, Healing, Shield, Special }
const OUTPUT_STATS = ["physical_damage", "witchcraft_damage", "burn_damage", "poison_damage", "healing_power", "shield_power"]

## 主能力由冷却驱动，事件和条件归被动，独立常驻数值归增益。
static func ability_category(execution_kind: int) -> int:
	match execution_kind:
		AbilityExecution.CooldownMain: return AbilityCategory.Main
		AbilityExecution.TriggeredPassive, AbilityExecution.ConditionalPassive: return AbilityCategory.Passive
		AbilityExecution.PersistentBonus: return AbilityCategory.Bonus
	return -1

## 数值效果只读取自己的属性，控制与功能效果没有主数值。
static func output_kind(action: Dictionary) -> int:
	match int(action.kind):
		CombatAction.PhysicalDamage: return Output.Physical
		CombatAction.Witchcraft: return Output.Witchcraft
		CombatAction.Heal: return Output.Healing
		CombatAction.GrantShield: return Output.Shield
		CombatAction.ApplyStatus:
			if action.get("status") == Status.Burn: return Output.Burn
			if action.get("status") == Status.Poison: return Output.Poison
	return Output.Special

## 特殊类返回空属性名，不能退回通用攻击力。
static func output_stat(kind: int) -> String:
	return OUTPUT_STATS[kind] if kind >= 0 and kind < OUTPUT_STATS.size() else ""
