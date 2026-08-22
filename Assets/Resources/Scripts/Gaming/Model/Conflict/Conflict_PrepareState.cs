using System;
[Serializable]
/// <summary>
/// 章节入口恢复枚举
/// </summary>
public enum ChapterEntryState
{
    NodeContent = 0,   // 进入节点内容页面
    RouteSelection = 1 // 进入路线选择页面
}
/// <summary>
/// 备战席当前流程模式
/// </summary>
public enum PrepareFlowMode
{
    None = 0, // 无备战席操作流程
    Deploy = 1, // 出战流程
    Replace = 2 // 替换流程
}

/// <summary>
/// 关卡结算结果
/// </summary>
public enum LevelCompletionResult
{
    Defeat = 0, // 关卡挑战失败
    Victory = 1 // 关卡挑战胜利
}

/// <summary>
/// 属性表当前操作模式
/// </summary>
public enum CardAttributeActionMode
{
    Buy = 0, // 购买卡牌
    Intensify = 1, // 强化卡牌
    Deploy = 2, // 设置卡牌出战
    ConfirmReplace = 3, // 确认替换出战卡牌
    SelectReplace = 4 // 选择替换用卡牌
}
