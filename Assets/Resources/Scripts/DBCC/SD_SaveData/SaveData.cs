using System;
using System.Collections.Generic;
using UnityEngine;

//======存档数据类======//
[Serializable]  //可序列化
public class SaveData   //这里所有的初始值都为玩家新手设定值
{
    //======动态数据======//
    public string userId; // 当前存档所属账号ID
    public SaveData_User SD_User = new SaveData_User(); // 用户系统数据

    // public List<SaveData_HeroCard> saveData_HeroCards = new List<SaveData_HeroCard>();
    public Dictionary<string, SaveData_HeroCard> SD_Cards = new Dictionary<string, SaveData_HeroCard>(); // 全部卡牌字典
    public List<SaveData_HeroCard> SD_HeroCards = new List<SaveData_HeroCard>(); // 拥有的卡牌列表
    // public List<SaveData_HeroCard> SD_FightCards = new List<SaveData_HeroCard>(); // 玩家出战的卡牌列表

    public Dictionary<string, SaveData_Dices> SD_Dices = new Dictionary<string, SaveData_Dices>(); // 拥有骰子字典
    public List<SaveData_Dices> SD_FightDices = new List<SaveData_Dices>(); // 玩家出战的骰子列表

    public Dictionary<int, SaveData_Chapter> SD_NormalChapters = new Dictionary<int, SaveData_Chapter>(); // 章节普通难度字典
    public Dictionary<int, SaveData_Chapter> SD_HardChapters = new Dictionary<int, SaveData_Chapter>(); // 章节困难难度字典
    public Dictionary<int, SaveData_Chapter> SD_HellChapters = new Dictionary<int, SaveData_Chapter>(); // 章节地狱难度字典

    public List<int> heroDiceFaceList = new List<int> { 0, 1, 10 }; // 骰子类型: 0=攻击, 1=释放技能, 2=回血, 10=群体攻击, 11=群体释放技能, 12=群体回复

    public List<SaveData_Item> SD_Items = new List<SaveData_Item>(); // 玩家拥有的物品列表
    public SaveData_Mall SD_Mall = new SaveData_Mall(); // 商店系统数据

    public Dictionary<string, SaveData_Equips> SD_Equips = new Dictionary<string, SaveData_Equips>(); // 玩家已解锁的装备字典

    public int selectedChapterIndex; // 选择确认后的章节索引
    public int currentLevelIndex; // 当前章节的关卡索引
    public ChapterEntryState currentChapterEntryState = ChapterEntryState.NodeContent; // 当前章节入口恢复状态
    public int completedChapterCount; // 玩家最大通关章节数

    // 新增字段示例(版本迭代)
    //public int starPower = 0;  // 新版本新增字段

    // ==========================================
    // 1. 初始化模块 (Initial)
    // ==========================================

    /// <summary>
    /// 【核心】初始化新账号的默认存档数据。
    /// 这里负责: 1.基础资源与状态设定, 2.英雄卡牌初始化, 3.骰子初始化, 4.章节关卡初始化, 5.道具初始化。
    /// </summary>
    public void Init_NewSaveData()//初始化新手玩家数据
    {
        Debug.Log("正在初始化新手玩家数据");
        // ==========================================
        // 1.1 基础资源与状态设定
        // ==========================================
        SD_User.playerId = Sys_User.DefaultPlayerId;      // 默认玩家名称
        SD_User.stamina = 50;          // 初始体力 
        SD_User.gold = 3000;            // 初始金币 
        SD_User.lastStaminaUpdateTime = DateTime.UtcNow.ToString("o"); // 初始体力结算时间
        //starPower = 0;          // 初始星力
        SD_User.playerDiceMax = 2;      // 初始骰子上限 

        SD_User.isCompleted_NewLevel = false; // 新手引导未完成
        SD_User.isAutoPlay = false;           // 自动战斗关闭

        selectedChapterIndex = 1;     // 默认选中第一章
        currentLevelIndex = 0;        // 第一关
        currentChapterEntryState = ChapterEntryState.NodeContent; // 默认进入第一关节点内容页面
        completedChapterCount = 0;    // 玩家最大通关章节数

        // ==========================================
        // 1.2 英雄卡牌初始化 (库存 + 出战)
        // ==========================================
        // 定义新手送的卡牌 ID 列表
        string[] newPlayerHeroIDs = new string[] { "H001", "H002" };

        foreach (string cardId in newPlayerHeroIDs)
        {
            // 动态加载资源, 确保数值是策划配置的最新值
            string path = "Card/Hero/" + cardId;
            SO_Card newPlayerHero = Resources.Load<SO_Card>(path);

            if (newPlayerHero != null)
            {
                // 创建存档数据实例
                SaveData_HeroCard newCard = new SaveData_HeroCard(cardId, newPlayerHero.hpMax, -1);

                // 加入卡牌表
                SD_HeroCards.Add(newCard);
            }
            else
            {
                Debug.LogError($"[Init_NewSaveData] 找不到初始卡牌资源, 路径: {path}");
            }
        }

        // ==========================================
        // 1.3 骰子初始化 (库存 + 出战)
        // ==========================================
        // 定义新手送的骰子
        string[] newPlayerDiceIDs = new string[] { "D001", "D002" };

        foreach (string diceId in newPlayerDiceIDs)
        {
            // 创建存档数据实例
            SaveData_Dices newDice = new SaveData_Dices(diceId, 1, true);

            // 加入骰子字典表
            SD_Dices.Add(diceId, newDice);

            // // 自动加入出战列表 (需要控制数量不超过 playerDiceMax)
            // if (SD_FightDices.Count < playerDiceMax)
            // {
            //     SD_FightDices.Add(newDice);
            // }
        }

        // ==========================================
        // 1.4 章节与关卡初始化
        // ==========================================
        // 解锁第一章
        SD_NormalChapters.Add(1, new SaveData_Chapter(1, true, false));

        // ==========================================
        // 1.5 道具初始化
        // ==========================================
        // 定义新手送的道具
        string[] newPlayerItemIDs = new string[] { "I001" };

        foreach (string itemId in newPlayerItemIDs)
        {
            // 创建存档数据实例
            SaveData_Item newItem = new SaveData_Item(itemId, 40);

            // 加入物品列表
            SD_Items.Add(newItem);
        }
        Debug.Log("新手数据初始化完成！");
    }
}
