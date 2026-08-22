using System.Collections.Generic;
using DG.Tweening;
using UnityEngine;

/// <summary>
/// 章节对战运行时对象管理器
/// 负责: 统一管理战斗节点中的玩家/怪物运行时实例, 占位缓存和准备态交互开关
/// </summary>
public class Conflict_RuntimeBoard
{
    private readonly CC_Fight CC_Fight;
    private readonly Fight_Entry Fight_Entry;
    private readonly Fight_Effect Fight_Effect;
    private readonly GameObject fightingCard_Prefab;
    private readonly GameObject cardContainer;
    private readonly List<GameObject> monsterCardBlankList;
    private readonly List<GameObject> heroCardBlankList;
    private readonly Card_Attribute Card_Attribute;

    private readonly List<Vector2> monsterPosVectorList = new List<Vector2>();
    private readonly List<Vector2> heroPosVectorList = new List<Vector2>();
    private readonly List<GameObject> fightingMonsterObjList = new List<GameObject>();
    private readonly List<GameObject> fightingHeroObjList = new List<GameObject>();
    private List<Card> heroCardFightList; // 当前出战卡牌数据列表引用

    /// <summary>
    /// 怪物占位缓存坐标
    /// </summary>
    public List<Vector2> MonsterPosVectorList => monsterPosVectorList;

    /// <summary>
    /// 玩家占位缓存坐标
    /// </summary>
    public List<Vector2> HeroPosVectorList => heroPosVectorList;

    /// <summary>
    /// 当前怪物运行时实例列表
    /// </summary>
    public List<GameObject> FightingMonsterObjList => fightingMonsterObjList;

    /// <summary>
    /// 当前玩家运行时实例列表
    /// </summary>
    public List<GameObject> FightingHeroObjList => fightingHeroObjList;

    /// <summary>
    /// 构造运行时对象管理器
    /// </summary>
    /// <param name="_CC_Fight">单场战斗控制器</param>
    /// <param name="_Fight_Entry">战斗词条处理器</param>
    /// <param name="_Fight_Effect">战斗效果目标管理器</param>
    /// <param name="_fightingCard_Prefab">战斗卡牌预制体</param>
    /// <param name="_cardContainer">卡牌运行时对象父节点</param>
    /// <param name="_monsterCardBlankList">怪物占位符列表</param>
    /// <param name="_heroCardBlankList">英雄占位符列表</param>
    /// <param name="_Card_Attribute">卡牌属性面板</param>
    public Conflict_RuntimeBoard(
        CC_Fight _CC_Fight,
        Fight_Entry _Fight_Entry,
        Fight_Effect _Fight_Effect,
        GameObject _fightingCard_Prefab,
        GameObject _cardContainer,
        List<GameObject> _monsterCardBlankList,
        List<GameObject> _heroCardBlankList,
        Card_Attribute _Card_Attribute)
    {
        CC_Fight = _CC_Fight;
        Fight_Entry = _Fight_Entry;
        Fight_Effect = _Fight_Effect;
        fightingCard_Prefab = _fightingCard_Prefab;
        cardContainer = _cardContainer;
        monsterCardBlankList = _monsterCardBlankList;
        heroCardBlankList = _heroCardBlankList;
        Card_Attribute = _Card_Attribute;
    }

    /// <summary>
    /// 初始化占位位置数据缓存
    /// </summary>
    /// <param name="_halfScreenHeight">屏幕上半区偏移量</param>
    public void Init_BlankCache(float _halfScreenHeight)
    {
        // 重新记录占位符原始坐标, 供战斗入场和回到准备态复用。
        monsterPosVectorList.Clear();
        heroPosVectorList.Clear();

        // 怪物占位符初始放到屏幕上方, 开战时再动画进入战场。
        foreach (GameObject monsterCardBlank in monsterCardBlankList)
        {
            monsterPosVectorList.Add(monsterCardBlank.GetComponent<RectTransform>().anchoredPosition);
        }

        foreach (GameObject heroCardBlank in heroCardBlankList)
        {
            heroPosVectorList.Add(heroCardBlank.GetComponent<RectTransform>().anchoredPosition);
        }

        foreach (GameObject monsterCardBlank in monsterCardBlankList)
        {
            Vector2 temp = monsterCardBlank.GetComponent<RectTransform>().anchoredPosition;
            monsterCardBlank.GetComponent<RectTransform>().anchoredPosition = new Vector2(temp.x, temp.y + _halfScreenHeight);
        }
    }

    /// <summary>
    /// 【核心】创建当前关卡的运行时所有对象
    /// </summary>
    /// <param name="_currentLevel">当前关卡</param>
    /// <param name="_heroCardFightList">当前出战卡牌数据列表</param>
    public void Create_LevelRuntimeObjects(Level _currentLevel, List<Card> _heroCardFightList)
    {
        // 缓存出战卡牌引用, 供备战替换和运行时实例复用。
        heroCardFightList = _heroCardFightList;

        // 进入新战斗节点时只清理怪物, 英雄运行时对象在章节内复用。
        Clear_MonsterRuntimeObjects();

        // 当前关卡存在怪物配置时创建本关怪物运行时实例。
        if (_currentLevel != null && _currentLevel.monsterSO_List != null)
        {
            Create_MonsterRuntimeObjects(_currentLevel);
        }

        // 首次进入章节创建英雄对象, 后续节点复用并恢复准备态。
        if (fightingHeroObjList.Count == 0)
        {
            Create_HeroRuntimeObjects(_heroCardFightList);
        }
        else
        {
            Reset_HeroCardRuntimeState_Prepare();
        }

        // 每次进入新关卡后刷新效果系统的目标列表。
        Fight_Effect.Init_Fight_Effect(fightingMonsterObjList, fightingHeroObjList);
    }

    /// <summary>
    /// 创建怪物运行时实例
    /// </summary>
    /// <param name="_currentLevel">当前关卡</param>
    private void Create_MonsterRuntimeObjects(Level _currentLevel)
    {
        List<SO_Card> monsterSO_List = _currentLevel.monsterSO_List;
        bool isBigBlank = false;

        // Boss 优先占用大怪物位。
        foreach (SO_Card monster in monsterSO_List)
        {
            if (monster.cardType == "Mb")
            {
                isBigBlank = true;
                Create_MonsterCardRuntime(monster, 0);
            }
        }

        // 非 Boss 关中的精英怪同样优先占用大怪物位。
        foreach (SO_Card monster in monsterSO_List)
        {
            if (monster.cardType == "Me" && _currentLevel.levelType != LevelType.Mb)
            {
                isBigBlank = true;
                Create_MonsterCardRuntime(monster, 0);
            }
        }

        // 存在大怪物位时, 普通怪从后续站位开始填充。
        if (isBigBlank)
        {
            for (int i = 0; i < monsterSO_List.Count - 1; i++)
            {
                Create_MonsterCardRuntime(monsterSO_List[i], i + 1);
            }
            return;
        }

        // 无大怪物时, 所有怪物按普通站位顺序创建。
        for (int i = 0; i < monsterSO_List.Count; i++)
        {
            Create_MonsterCardRuntime(monsterSO_List[i], i + 1);
        }
    }

    /// <summary>
    /// 创建单个怪物运行时实例
    /// </summary>
    /// <param name="_SO_Card">怪物卡牌配置</param>
    /// <param name="_blankIndex">目标占位索引</param>
    private void Create_MonsterCardRuntime(SO_Card _SO_Card, int _blankIndex)
    {
        // 实例化怪物并放到对应怪物占位符位置。
        GameObject monster = UnityEngine.Object.Instantiate(fightingCard_Prefab, cardContainer.transform);
        monster.GetComponent<RectTransform>().anchoredPosition =
            monsterCardBlankList[_blankIndex].GetComponent<RectTransform>().anchoredPosition;

        // 绑定怪物战斗数据和战斗模块引用。
        C_FightCard C_FightCard = monster.GetComponent<C_FightCard>();
        C_FightCard.posIndex = _blankIndex;
        C_FightCard.Init_FightingMonsterCard(_SO_Card, monsterPosVectorList[_blankIndex], CC_Fight, Fight_Entry, Fight_Effect);
        monster.name = _SO_Card.name;

        fightingMonsterObjList.Add(monster);
    }

    /// <summary>
    /// 创建玩家运行时实例
    /// </summary>
    /// <param name="_heroCardFightList">当前出战卡牌逻辑列表</param>
    private void Create_HeroRuntimeObjects(List<Card> _heroCardFightList)
    {
        if (_heroCardFightList == null)
        {
            return;
        }

        // 只为已设置出战站位的卡牌创建运行时对象。
        foreach (Card card in _heroCardFightList)
        {
            if (card == null || card.posIndex < 0)
            {
                continue;
            }

            Create_HeroCardRuntime(card);
        }
    }

    /// <summary>
    /// 创建单个玩家运行时实例
    /// </summary>
    /// <param name="_card">目标卡牌</param>
    /// <returns>创建完成的运行时对象</returns>
    private GameObject Create_HeroCardRuntime(Card _card)
    {
        // 实例化英雄并放到卡牌数据记录的站位。
        GameObject hero = UnityEngine.Object.Instantiate(fightingCard_Prefab, cardContainer.transform);
        hero.GetComponent<RectTransform>().anchoredPosition =
            heroCardBlankList[_card.posIndex].GetComponent<RectTransform>().anchoredPosition;

        // 绑定英雄战斗数据和战斗模块引用。
        C_FightCard C_FightCard = hero.GetComponent<C_FightCard>();
        C_FightCard.posIndex = _card.posIndex;
        C_FightCard.Init_FightingHeroCard(_card, heroPosVectorList[_card.posIndex], CC_Fight, Fight_Entry, Fight_Effect);
        hero.name = _card.SO_Card.cardName;

        // 准备态需要挂接属性表交互。
        Init_HeroPrepareInteraction(hero);
        fightingHeroObjList.Add(hero);
        return hero;
    }

    /// <summary>
    /// 新增玩家出战实例
    /// </summary>
    /// <param name="_card">目标卡牌</param>
    /// <param name="_targetPosIndex">目标出战站位</param>
    public void Deploy_HeroCardRuntime(Card _card, int _targetPosIndex)
    {
        if (_card == null)
        {
            return;
        }

        // 先更新卡牌数据站位, 再同步出战列表和运行时对象。
        _card.posIndex = _targetPosIndex;

        if (heroCardFightList != null && !heroCardFightList.Contains(_card))
        {
            heroCardFightList.Add(_card);
        }

        GameObject hero = Create_HeroCardRuntime(_card);
        hero.SetActive(true);
    }

    /// <summary>
    /// 替换玩家出战实例
    /// </summary>
    /// <param name="_card">用于替换的新卡牌</param>
    /// <param name="_targetPosIndex">目标出战站位</param>
    public void Replace_HeroCardRuntime(Card _card, int _targetPosIndex)
    {
        if (_card == null)
        {
            return;
        }

        // 目标站位没有运行时对象时, 替换退化为新增出战。
        GameObject targetHeroObj = Get_HeroRuntimeObjectByPosIndex(_targetPosIndex);
        if (targetHeroObj == null)
        {
            Deploy_HeroCardRuntime(_card, _targetPosIndex);
            return;
        }

        // 旧卡牌退出出战站位。
        C_FightCard targetFightCard = targetHeroObj.GetComponent<C_FightCard>();
        Card oldCard = targetFightCard.Card;
        if (oldCard != null)
        {
            oldCard.posIndex = -1;
        }

        // 将新卡牌写入目标站位和出战列表。
        _card.posIndex = _targetPosIndex;

        if (heroCardFightList != null)
        {
            int oldIndex = oldCard == null ? -1 : heroCardFightList.IndexOf(oldCard);
            if (oldIndex >= 0)
            {
                heroCardFightList[oldIndex] = _card;
            }
            else if (!heroCardFightList.Contains(_card))
            {
                heroCardFightList.Add(_card);
            }
        }

        // 复用原运行时对象并重新绑定新卡牌数据。
        targetFightCard.posIndex = _targetPosIndex;
        targetFightCard.Init_FightingHeroCard(_card, heroPosVectorList[_targetPosIndex], CC_Fight, Fight_Entry, Fight_Effect);
        targetHeroObj.name = _card.SO_Card.cardName;
        Init_HeroPrepareInteraction(targetHeroObj);
    }

    /// <summary>
    /// 重置玩家实例为准备态
    /// </summary>
    public void Reset_HeroCardRuntimeState_Prepare()
    {
        foreach (GameObject heroObj in fightingHeroObjList)
        {
            if (heroObj == null)
            {
                continue;
            }

            heroObj.SetActive(true);
            C_FightCard fightCard = heroObj.GetComponent<C_FightCard>();
            if (fightCard != null)
            {
                fightCard.Reset_HeroRuntimeForPrepare();
            }

            Init_HeroPrepareInteraction(heroObj);
        }
    }

    /// <summary>
    /// 统一切换玩家准备态交互
    /// </summary>
    /// <param name="_enabled">是否启用</param>
    public void Set_HeroCardInteraction(bool _enabled)
    {
        foreach (GameObject heroObj in fightingHeroObjList)
        {
            if (heroObj == null)
            {
                continue;
            }

            Card_Interaction interaction = heroObj.GetComponent<Card_Interaction>();
            if (interaction == null)
            {
                continue;
            }

            interaction.Set_PrepareInteractionEnabled(_enabled);
        }
    }

    /// <summary>
    /// 统一切换玩家占位符显示状态
    /// </summary>
    /// <param name="_isVisible">是否显示</param>
    public void Set_HeroCardBlankVisible(bool _isVisible)
    {
        Set_BlankVisible(heroCardBlankList, _isVisible);
    }

    /// <summary>
    /// 统一切换怪物占位符显示状态
    /// </summary>
    /// <param name="_isVisible">是否显示</param>
    public void Set_MonsterCardBlankVisible(bool _isVisible)
    {
        Set_BlankVisible(monsterCardBlankList, _isVisible);
    }

    /// <summary>
    /// 统一切换玩家运行时实例显示状态
    /// </summary>
    /// <param name="_isVisible">是否显示</param>
    public void Set_HeroCardVisible_Runtime(bool _isVisible)
    {
        foreach (GameObject heroObj in fightingHeroObjList)
        {
            if (heroObj == null)
            {
                continue;
            }

            heroObj.SetActive(_isVisible);
        }
    }

    /// <summary>
    /// 【核心】将存活英雄运行时数据同步回卡牌数据
    /// </summary>
    public void Update_AliveHeroCardData()
    {
        // 只同步当前仍存活并存在运行时对象的英雄。
        foreach (GameObject heroObj in fightingHeroObjList)
        {
            if (heroObj == null)
            {
                continue;
            }

            C_FightCard fightCard = heroObj.GetComponent<C_FightCard>();
            if (fightCard != null)
            {
                fightCard.Update_HeroCard();
            }
        }
    }

    /// <summary>
    /// 播放怪物运行时实例入场移动动画
    /// </summary>
    /// <param name="_deltaDistance">纵向移动距离</param>
    /// <param name="_moveDuration">移动时长</param>
    /// <returns>怪物移动动画序列</returns>
    public Sequence Move_MonsterRuntimeEntry(float _deltaDistance, float _moveDuration)
    {
        Sequence sequence = DOTween.Sequence();
        foreach (GameObject fightingMonsterObj in fightingMonsterObjList)
        {
            if (fightingMonsterObj == null)
            {
                continue;
            }

            RectTransform fightingMonsterRect = fightingMonsterObj.GetComponent<RectTransform>();
            Tween prepare_Move = fightingMonsterRect
                .DOAnchorPosY(fightingMonsterRect.anchoredPosition.y + _deltaDistance, _moveDuration)
                .SetEase(Ease.OutQuad);
            sequence.Join(prepare_Move);
        }

        return sequence;
    }

    /// <summary>
    /// 【核心】尝试接入战斗模块
    /// </summary>
    /// <param name="_CC_Conflict">章节流程控制器</param>
    /// <param name="_currentLevel">当前关卡</param>
    /// <returns>是否成功接入战斗</returns>
    public bool Try_StartRuntimeFight(CC_Conflict _ccConflict, Level _currentLevel)
    {
        // 没有玩家出战实例时不允许移交给战斗模块。
        if (fightingHeroObjList.Count == 0)
        {
            Debug.Log("玩家出战卡牌列表为空");
            return false;
        }

        // 初始化骰子锚点并将双方运行时对象交给单场战斗控制器。
        CC_Fight.Init_DiceAnchoredPosition(fightingCard_Prefab, _currentLevel);
        CC_Fight.Init_Fighting(
            fightingHeroObjList,
            fightingMonsterObjList,
            _ccConflict,
            monsterPosVectorList,
            heroPosVectorList);
        return true;
    }

    /// <summary>
    /// 清理所有怪物运行时实例
    /// </summary>
    public void Clear_MonsterRuntimeObjects()
    {
        // 章节内切换关卡时, 怪物对象每关重新创建。
        foreach (GameObject monsterObj in fightingMonsterObjList)
        {
            if (monsterObj == null)
            {
                continue;
            }

            UnityEngine.Object.Destroy(monsterObj);
        }

        // 清空运行时列表, 避免下一关引用旧怪物对象。
        fightingMonsterObjList.Clear();
    }

    /// <summary>
    /// 安全移除死亡运行时对象
    /// </summary>
    /// <param name="_deadCardObj">死亡对象</param>
    /// <param name="_Fight_Dice">骰子管理器</param>
    public void Remove_DeadRuntimeObjectSafe(GameObject _deadCardObj, Fight_Dice _Fight_Dice)
    {
        if (_deadCardObj == null)
        {
            return;
        }

        // 怪物死亡时先回收其意图骰子, 再从怪物运行时列表移除。
        if (_deadCardObj.CompareTag("Monster"))
        {
            C_FightCard deadFightCard = _deadCardObj.GetComponent<C_FightCard>();
            if (deadFightCard != null && deadFightCard.diceIntentionObjList.Count > 0)
            {
                foreach (GameObject diceObj in deadFightCard.diceIntentionObjList)
                {
                    if (diceObj != null)
                    {
                        _Fight_Dice.Dice_Reset(diceObj);
                    }
                }
            }

            fightingMonsterObjList.Remove(_deadCardObj);
            UnityEngine.Object.Destroy(_deadCardObj);
            return;
        }

        // 英雄死亡只移除本场运行时对象, 失败后的卡牌数据由 Sys_Card 统一结算。
        if (_deadCardObj.CompareTag("Hero"))
        {
            fightingHeroObjList.Remove(_deadCardObj);
            UnityEngine.Object.Destroy(_deadCardObj);
        }
    }

    /// <summary>
    /// 查找指定站位的玩家运行时实例
    /// </summary>
    /// <param name="_posIndex">目标站位</param>
    /// <returns>命中的运行时对象</returns>
    private GameObject Get_HeroRuntimeObjectByPosIndex(int _posIndex)
    {
        foreach (GameObject heroObj in fightingHeroObjList)
        {
            if (heroObj == null)
            {
                continue;
            }

            C_FightCard fightCard = heroObj.GetComponent<C_FightCard>();
            if (fightCard == null || fightCard.Card == null)
            {
                continue;
            }

            if (fightCard.Card.posIndex == _posIndex)
            {
                return heroObj;
            }
        }

        return null;
    }

    /// <summary>
    /// 确保玩家实例带有准备态交互组件
    /// </summary>
    /// <param name="_heroObj">目标实例</param>
    private void Init_HeroPrepareInteraction(GameObject _heroObj)
    {
        Card_Interaction interaction = _heroObj.GetComponent<Card_Interaction>();
        if (interaction == null)
        {
            interaction = _heroObj.AddComponent<Card_Interaction>();
        }

        interaction.Card_Attribute = Card_Attribute;
        interaction.Set_PrepareInteractionEnabled(true);
    }

    /// <summary>
    /// 统一切换占位符显示状态
    /// </summary>
    /// <param name="blankList">目标占位符列表</param>
    /// <param name="isVisible">是否显示</param>
    private void Set_BlankVisible(List<GameObject> blankList, bool isVisible)
    {
        foreach (GameObject blankObj in blankList)
        {
            if (blankObj == null)
            {
                continue;
            }

            blankObj.SetActive(isVisible);
        }
    }
}
