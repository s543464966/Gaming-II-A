using System;
using System.Collections.Generic;
using UnityEngine;

//======游戏运行时临时数据类======//
// [Serializable]  //可序列化
public class GameData   //游戏运行时临时数据类
{
    // ----------------------------------------------------------------------------------------------------------
    //====== 动态数据 ======//
    public string userId; // 当前运行时账号ID

    //模块: CC_Card
    public Dictionary<string, Card> heroCardDict; // 玩家卡牌列字典
    //public List<Card> heroCardFightList; // 玩家出战卡牌 ->可能归到临时数据
    public Dictionary<string, Card> LockHeroCardDict; // 未解锁卡牌

    //模块: CC_Dice
    public Dictionary<string, Dice> heroDiceDict; // 玩家拥有的骰子字典
    public List<Dice> heroDiceFightList; // 玩家出战的骰子列表
    public Dictionary<string, Dice> lockDiceDict; // 玩家未拥有的骰子字典
    // public List<int> heroDiceList; // 骰子类型: 0=攻击, 1=释放技能, 2=回血, 10=群体攻击, 11=群体释放技能, 12=群体回复
    public int heroDiceCount; // 玩家可用骰子数

    //模块: CC_Equip
    public Dictionary<string, Equip> heroEquipDict; // 玩家拥有的装备字典
    public Dictionary<string, Equip> lockEquipDict; // 玩家未拥有的装备字典

    //模块: CC_Fight
    // 是否自动化 (已被移交至 Sys_User 管理)
    // ----------------------------------------------------------------------------------------------------------
    //====== 临时数据 ======//

    //模块: CC_Home
    public bool isCC_HomeInit_GameData = false; // 是否在主界面初始化游戏基本数据

    // ==========================================
    // 1. 静态配置数据库 (全服共享, 只读)
    // ==========================================
    // 所有人想查 SO, 都来这里查(字典查找速度快 O(1) )
    public Dictionary<string, SO_Card> All_SO_Heros = new Dictionary<string, SO_Card>();
    public Dictionary<string, SO_Item> All_SO_Items = new Dictionary<string, SO_Item>();
    public Dictionary<string, SO_Dice> All_SO_Dices = new Dictionary<string, SO_Dice>();
    public Dictionary<string, SO_Commodity> All_SO_Commodities = new Dictionary<string, SO_Commodity>();
    public Dictionary<int, SO_Chapter> All_SO_Chapters = new Dictionary<int, SO_Chapter>();

    // ==========================================
    // 2. 子系统 (部门经理)
    // ==========================================
    // 负责具体的业务逻辑和运行时数据的各个系统
    public Sys_Inventory Sys_Inventory = new Sys_Inventory(); // 库存子系统
    public Sys_Card Sys_Card = new Sys_Card(); // 卡牌子系统
    public Sys_Mall Sys_Mall = new Sys_Mall();  // 商城子系统
    public Sys_User Sys_User = new Sys_User(); // 用户系统
    public Sys_Chapter Sys_Chapter = new Sys_Chapter(); // 章节选择系统

    // ==========================================
    // 3. 数据与初始化逻辑
    // ==========================================

    /// <summary>
    /// 加载所有系统共用的 SO 静态配置。
    /// 这里负责: 从 Resources 加载英雄, 物品, 骰子, 商品和章节数据并建立索引。
    /// </summary>
    void LoadAllSO()
    {
        // 加载 HeroCard SO
        var heros = Resources.LoadAll<SO_Card>("Card/Hero");    //Assets/Resources/Card/Hero
        foreach (var h in heros) All_SO_Heros[h.cardId] = h;

        // 加载 Item SO
        var items = Resources.LoadAll<SO_Item>("Item/Prop");    //Assets/Resources/Item/Prop
        foreach (var i in items) All_SO_Items[i.itemId] = i;

        // 加载 Dice SO
        var dices = Resources.LoadAll<SO_Dice>("Item/Dice");    //Assets/Resources/Item/Dice
        foreach (var d in dices) All_SO_Dices[d.diceId] = d;

        // 加载 Commodity SO
        var commodities = Resources.LoadAll<SO_Commodity>("Commodity");    //Assets/Resources/Commodity
        foreach (var c in commodities) All_SO_Commodities[c.commodityId] = c;

        // 加载 Chapter SO (普通难度)
        var normalChapters = Resources.LoadAll<SO_Chapter>("Chapter/Normal"); //Assets/Resources/Chapter/Normal
        foreach (var n in normalChapters) All_SO_Chapters[n.chapterIndex] = n;
    }
    /// <summary>
    /// 【核心】根据当前账号存档初始化游戏运行时数据。
    /// 这里负责: 1.记录账号归属, 2.加载静态配置, 3.将存档数据分发给各子系统。
    /// </summary>
    /// <param name="_saveData">当前账号对应的存档数据。</param>
    public void Init_GameData(SaveData _saveData) // 接收存档数据来初始化游戏数据
    {
        userId = _saveData.userId;  //账号归属

        // 加载静态数据看
        LoadAllSO();

        // 初始化各系统(把 SaveData 给它们)
        Sys_Inventory.Init_Sys_Inventory(_saveData.SD_Items);
        Sys_Card.Init_Sys_Card(_saveData.SD_HeroCards);
        Sys_Mall.Init_Sys_Mall(_saveData.SD_Mall);
        Sys_User.Init_Sys_User(_saveData.SD_User);
        Sys_Chapter.Init_Sys_Chapter(_saveData);
    }
}
