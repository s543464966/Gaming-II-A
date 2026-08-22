using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

[System.Serializable] // 关键：加上它，GameData在Inspector里才能看见详情
public class Sys_Card
{
    // --- 内部状态 --- (数据源)
    private GameData GameData => DBCC_DataBase.Instance.GameData; // GameData别名[因为单例原因]
    
    // ==========================================
    // 1. 数据核心 (Data Core)
    // ==========================================
    
    // --- 内部状态 --- (存放集合)
    [SerializeField] private List<Card> heroCardList = new List<Card>(); // 英雄列表(包含已解锁和未解锁的)
    [SerializeField] private List<Card> minionCardList = new List<Card>(); // 随从列表(包含已解锁和未解锁的)
    private List<Card> fightCardList = new List<Card>(); // 出战列表 (只存储引用，指向上面列表里的对象) 暂时未做存储
    
    // ==========================================
    // 2. 初始化
    // ==========================================
    
    /// <summary>
    /// 【核心】初始化卡牌总系统
    /// 负责: 1.接收存档卡牌数据构造查找表, 2.重构全栈英雄与随从SO配置列表, 3.激活历史持有卡牌的解锁标志与战斗数据
    /// </summary>
    /// <param name="_SD_HeroCards">存档里的所有已拥有英雄卡牌数据</param>
    public void Init_Sys_Card(List<SaveData_HeroCard> _SD_HeroCards)
    {  
        heroCardList.Clear();
        fightCardList.Clear();

        // 1. 将存档数据转为字典，方便 O(1) 快速查找
        // Key: CardID, Value: SaveData对象
        Dictionary<string, SaveData_HeroCard> SD_HeroCardDict = new Dictionary<string, SaveData_HeroCard>();
        if (_SD_HeroCards != null)
        {
            foreach (var sd in _SD_HeroCards) SD_HeroCardDict[sd.cardID] = sd;
        }
        // 2. 核心逻辑：遍历 GameData 里的所有 SO (由 GameData 统一加载好的)
        foreach (var kvp in GameData.All_SO_Heros)
        {
            // 新建Card数据
            SO_Card SO_Card = kvp.Value;
            Card newHeroCard = new Card(SO_Card);
            // 3. 检查存档里是否有这张卡
            if (SD_HeroCardDict.TryGetValue(SO_Card.cardId, out SaveData_HeroCard SaveData_HeroCard))
            {
                // A. 存档里有 -> 解锁并赋值
                newHeroCard.Init_HeroCard(SaveData_HeroCard.hp, SaveData_HeroCard.posIndex);
                
                //给已解锁卡牌寻找其技能SO
                Load_AbilityForCard(newHeroCard);

                // 处理出战
                if (newHeroCard.posIndex != -1) fightCardList.Add(newHeroCard);
            }
            else
            {
                // B. 存档里没有 -> 保持 isUnlocked = false
                // 这里什么都不用做，因为构造函数里默认就是 false
            }
            // 加入总表
            heroCardList.Add(newHeroCard);
        }

        Debug.Log("完成仓库系统数据初始化加载");
    }
    // ==========================================
    // 3. 辅助逻辑
    // ==========================================
    
    /// <summary>
    /// 【核心】给卡牌加载附着对应技能逻辑
    /// 负责: 验证SO_Card中是否挂载对应的技能ID, 然后在Resources中反射并实例化附魔该SO_Ability组件
    /// </summary>
    /// <param name="_card">即将被赋予技能对象的卡牌实例</param>
    private void Load_AbilityForCard(Card _card)
    {
        if (string.IsNullOrEmpty(_card.SO_Card.skillId)) return;
        //技能SO文件夹路径
        string pathFolder = "Ability/AbilityCard/"; 
        string scriptName = _card.SO_Card.skillId;
        SO_Ability SO_Ability = Resources.Load<SO_Ability>(pathFolder + scriptName);
        if (SO_Ability == null) return;
        _card.SO_Ability = SO_Ability;
    }
    // ==========================================
    // 4. 核心 API (供 UI 调用)
    // ==========================================

    /// <summary>
    /// 【核心】获取用于显示的列表
    /// 负责: 根据类型和解锁状态筛选特定的数组给UI端拉取展示用
    /// </summary>
    /// <param name="_isUnLocked">true=取已解锁, false=取未解锁</param>
    /// <returns>条件过滤出来的Card只读实例结合</returns>
    public List<Card> Get_DisplayCardList(bool _isUnLocked) // (CardType targetType, bool getUnlocked) (待改进，先用英雄的，类型后续再加)
    {
        // 1. 确定源列表
        List<Card> sourceList = heroCardList;//(targetType == CardType.Hero) ? _allHeroCards : _allMinionCards;

        // 2. 筛选 (使用 Linq)
        // 返回：源列表中 (是否解锁 == 目标状态) 的所有元素
        return sourceList.Where(c => c.isUnlocked == _isUnLocked).ToList();
    }
    /// <summary>
    /// 获取整个卡牌逻辑数据表
    /// 负责: 暴露完整的集合以供外存或大体扫描逻辑使用
    /// </summary>
    /// <returns>英雄卡牌逻辑数据表</returns>
    public List<Card> Get_CardList() => heroCardList;
    /// <summary>
    /// 获取出战卡牌逻辑数据表
    /// </summary>
    /// <returns>当前出战卡牌逻辑数据表</returns>
    public List<Card> Get_FightCardList() => fightCardList;

    /// <summary>
    /// 【核心】处理关卡失败后的出战卡牌数据
    /// </summary>
    /// <param name="_hpMaxRatio">恢复到生命上限的比例</param>
    public void Process_LevelDefeat(float _hpMaxRatio)
    {
        // 失败恢复基于出战卡牌数据列表, 不依赖可能已销毁的战斗运行时对象。
        foreach (Card heroCard in fightCardList)
        {
            if (heroCard == null || heroCard.SO_Card == null)
            {
                continue;
            }

            // 将出战英雄恢复到配置生命上限的指定比例。
            heroCard.Update_HeroCard(heroCard.SO_Card.hpMax * _hpMaxRatio);
        }
    }
    
    /// <summary>
    /// 【核心】卡牌解锁逻辑
    /// 负责: 1.遍历查找对应的卡牌对象, 2.设置其为拥有状态激活游戏内交互权限
    /// </summary>
    /// <param name="_cardID">配置SO设定的特定String</param>
    public void Unlock_Card(string _cardID)
    {
        // 先找英雄
        var card = heroCardList.FirstOrDefault(h => h.SO_Card.cardId == _cardID);
        // 没找到找随从
        if (card == null) card = minionCardList.FirstOrDefault(m => m.SO_Card.cardId == _cardID);

        if (card != null)
        {
            card.isUnlocked = true;
            // 初始化卡牌
            card.Init_HeroCard(card.SO_Card.hpMax, -1); // 默认满血，且不出战（位置-1）
            Debug.Log($"解锁卡牌: {card.SO_Card.cardName}");
            // 这里还可以加个判断是否解锁，已解锁的可以转为碎片或者其他东西
        }
    }
    // ==========================================
    // 5. 导出数据 API (自己打包)
    // ==========================================
    
    /// <summary>
    /// 【核心】导出所有的可存储英雄卡牌数据
    /// 负责: 将运行时的 Card 对象精简提取成 ID 与基础属性参数的字典/列表存档内容
    /// </summary>
    /// <returns>返回一个新的列表供 GameData 保存</returns>
    public List<SaveData_HeroCard> Export_HeroCardSaveData()
    {
        // 申请新空间来存储
        List<SaveData_HeroCard> SD_HeroCards = new List<SaveData_HeroCard>();

        foreach (var hero in heroCardList)
        {
            // 只保存已解锁的
            if (hero.isUnlocked)
            {
                // 将运行时对象转为存档数据对象
                SaveData_HeroCard saveData_HeroCard = new SaveData_HeroCard(hero.SO_Card.cardId, hero.hp, hero.posIndex);
                SD_HeroCards.Add(saveData_HeroCard);
            }
        }
        // 返回英雄卡牌数据
        return SD_HeroCards;
    }
}
