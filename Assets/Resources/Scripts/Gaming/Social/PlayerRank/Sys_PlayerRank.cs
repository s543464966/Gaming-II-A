using System;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 负责本地排行榜数据读取, 价值计算与排序。
/// </summary>
public class Sys_PlayerRank
{
    
    /// <summary>
    /// 获取当前本机所有账号的排行榜数据。
    /// </summary>
    /// <returns>返回按价值降序排列的排行榜列表。</returns>
    public List<PlayerRank> Get_RankList_PlayerRank()
    {
        var playerRanks = new List<PlayerRank>();
        
        var dataBase = DBCC_DataBase.Instance;
        // 排行榜依赖DBCC提供账号系统和只读存档读取能力。
        if (dataBase == null || dataBase.Sys_Auth == null)
        {
            Debug.LogWarning("[Sys_PlayerRank] DBCC_DataBase 或 Sys_Auth 缺失。");
            return playerRanks;
        }

        // 先读取账号公开信息, 这里只会拿到排行榜需要的非敏感字段。
        if (!dataBase.Sys_Auth.Try_GetPublicAccounts_Auth(out var accounts))
        {
            Debug.LogWarning("[Sys_PlayerRank] 账号公开列表读取失败。");
            return playerRanks;
        }

        // 循环遍历公开信息生成对应的排行榜数据。
        foreach (var account in accounts)
        {
            // 单条账号记录异常时跳过, 不能阻断其他账号进入排行榜。
            if (account == null || string.IsNullOrWhiteSpace(account.userId))
            {
                continue;
            }

            // 当前已登录账号优先使用GameData运行时数据, 模拟服务器实时榜单效果。
            if (Try_CreateRuntimeRank_PlayerRank(account, dataBase, out var runtimePlayerRank))
            {
                playerRanks.Add(runtimePlayerRank);
                continue;
            }

            // 通过DBCC只读接口读取临时存档, 不切换当前登录账号。
            if (!dataBase.Try_ReadUserSaveData_DB(account.userId, account.saveFileName, out var saveData))
            {
                Debug.LogWarning($"[Sys_PlayerRank] 跳过账号排行榜数据, accountId: {account.accountId}");
                continue;
            }

            // 存档读取成功后才计算价值并加入排行榜候选列表。
            playerRanks.Add(new PlayerRank
            {
                userId = account.userId,
                accountId = account.accountId,
                playerId = Get_PlayerId_PlayerRank(saveData),
                value = Calculate_PlayerValue_PlayerRank(saveData)
            });
        }

        // 第一版排行榜按账号价值从高到低排序。
        playerRanks.Sort((left, right) => right.value.CompareTo(left.value));
        for (var i = 0; i < playerRanks.Count; i++)
        {
            // 排名从1开始, 方便后续UI需要显示名次时直接使用。
            playerRanks[i].rankIndex = i + 1;
        }

        return playerRanks;
    }

    /// <summary>
    /// 尝试使用当前登录账号的运行时数据生成排行榜条目。
    /// </summary>
    /// <param name="account">账号公开信息。</param>
    /// <param name="dataBase">数据库单例。</param>
    /// <param name="playerRank">生成的排行榜条目。</param>
    /// <returns>返回是否成功生成运行时排行榜条目。</returns>
    bool Try_CreateRuntimeRank_PlayerRank(LocalAccountPublicInfo_Auth account, DBCC_DataBase dataBase, out PlayerRank playerRank)
    {
        playerRank = null;
        if (account == null || dataBase == null || !dataBase.Is_CurrentUserDataLoaded_DB(account.userId))
        {
            return false;
        }

        var gameData = dataBase.GameData;
        if (gameData == null || gameData.Sys_User == null)
        {
            return false;
        }

        // 当前账号使用运行时系统数据计算价值, 让打开排行榜时能看到未落盘的金币/英雄等变化。
        playerRank = new PlayerRank
        {
            userId = account.userId,
            accountId = account.accountId,
            playerId = string.IsNullOrWhiteSpace(gameData.Sys_User.playerId) ? Sys_User.DefaultPlayerId : gameData.Sys_User.playerId,
            value = Calculate_PlayerValue_PlayerRank(gameData, dataBase.SaveData)
        };

        return true;
    }

    /// <summary>
    /// 根据账号存档计算本地排行榜价值。
    /// </summary>
    /// <param name="saveData">账号存档数据。</param>
    /// <returns>返回账号价值。</returns>
    int Calculate_PlayerValue_PlayerRank(SaveData saveData)
    {
        if (saveData == null)
        {
            return 0;
        }

        // 基础资源来自用户存档, 空用户数据按0处理。
        var userData = saveData.SD_User;
        var gold = userData != null ? userData.gold : 0;
        var starStone = userData != null ? userData.starStone : 0;

        // 收集类数据只按数量计分, 不在排行榜系统中加载SO配置。
        var heroCount = saveData.SD_HeroCards != null ? saveData.SD_HeroCards.Count : 0;
        var diceCount = saveData.SD_Dices != null ? saveData.SD_Dices.Count : 0;
        var diceLevelTotal = Get_DiceLevelTotal_PlayerRank(saveData);
        var itemCountTotal = Get_ItemCountTotal_PlayerRank(saveData);

        // 第一版固定权重算法, 后续调整战力公式时只改这里。
        return gold
               + starStone * 100
               + heroCount * 500
               + diceCount * 300
               + diceLevelTotal * 100
               + saveData.completedChapterCount * 2000
               + saveData.currentLevelIndex * 200
               + itemCountTotal * 20;
    }

    /// <summary>
    /// 根据当前账号运行时数据计算本地排行榜价值。
    /// </summary>
    /// <param name="gameData">当前账号运行时数据。</param>
    /// <param name="fallbackSaveData">当前账号存档数据, 用于补充暂未运行时化的字段。</param>
    /// <returns>返回账号价值。</returns>
    int Calculate_PlayerValue_PlayerRank(GameData gameData, SaveData fallbackSaveData)
    {
        if (gameData == null || gameData.Sys_User == null)
        {
            return fallbackSaveData != null ? Calculate_PlayerValue_PlayerRank(fallbackSaveData) : 0;
        }

        // 金币/魔石直接读取运行时用户系统, 能反映购买和消耗后的即时变化。
        var gold = gameData.Sys_User.gold;
        var starStone = gameData.Sys_User.starStone;

        // 英雄和物品通过各系统导出接口读取运行时状态, 但不写回SaveData或磁盘。
        var heroSaveDataList = gameData.Sys_Card != null ? gameData.Sys_Card.Export_HeroCardSaveData() : null;
        var itemSaveDataList = gameData.Sys_Inventory != null ? gameData.Sys_Inventory.Export_ItemSaveData() : null;
        var heroCount = heroSaveDataList != null ? heroSaveDataList.Count : 0;
        var diceCount = gameData.heroDiceDict != null ? gameData.heroDiceDict.Count : 0;
        var diceLevelTotal = Get_DiceLevelTotal_PlayerRank(gameData);
        var itemCountTotal = Get_ItemCountTotal_PlayerRank(itemSaveDataList);

        // completedChapterCount 目前只存在SaveData字段, 暂用当前内存SaveData补充。
        var completedChapterCount = fallbackSaveData != null ? fallbackSaveData.completedChapterCount : 0;
        var currentLevelIndex = Get_CurrentLevelIndex_PlayerRank(gameData, fallbackSaveData);

        return gold
               + starStone * 100
               + heroCount * 500
               + diceCount * 300
               + diceLevelTotal * 100
               + completedChapterCount * 2000
               + currentLevelIndex * 200
               + itemCountTotal * 20;
    }

    /// <summary>
    /// 获取玩家名称, 存档缺省时使用新手默认名称。
    /// </summary>
    /// <param name="saveData">账号存档数据。</param>
    /// <returns>返回玩家名称。</returns>
    string Get_PlayerId_PlayerRank(SaveData saveData)
    {
        // 旧存档或异常存档缺少玩家名时, 使用新账号默认名称保证UI可显示。
        if (saveData == null || saveData.SD_User == null || string.IsNullOrWhiteSpace(saveData.SD_User.playerId))
        {
            return Sys_User.DefaultPlayerId;
        }

        return saveData.SD_User.playerId;
    }

    /// <summary>
    /// 统计玩家拥有骰子的总数量。
    /// </summary>
    /// <param name="saveData">账号存档数据。</param>
    /// <returns>返回骰子数量总和。</returns>
    int Get_DiceLevelTotal_PlayerRank(SaveData saveData)
    {
        if (saveData == null || saveData.SD_Dices == null)
        {
            return 0;
        }

        var total = 0;
        foreach (var dicePair in saveData.SD_Dices)
        {
            // getNum 是玩家持有数量, 负数异常值按0处理。
            if (dicePair.Value != null)
            {
                total += Math.Max(0, dicePair.Value.getNum);
            }
        }

        return total;
    }

    /// <summary>
    /// 统计当前运行时玩家拥有骰子的总数量。
    /// </summary>
    /// <param name="gameData">当前账号运行时数据。</param>
    /// <returns>返回骰子数量总和。</returns>
    int Get_DiceLevelTotal_PlayerRank(GameData gameData)
    {
        if (gameData == null || gameData.heroDiceDict == null)
        {
            return 0;
        }

        var total = 0;
        foreach (var dicePair in gameData.heroDiceDict)
        {
            if (dicePair.Value != null)
            {
                total += Math.Max(0, dicePair.Value.getNum);
            }
        }

        return total;
    }

    /// <summary>
    /// 统计玩家拥有物品的总数量。
    /// </summary>
    /// <param name="saveData">账号存档数据。</param>
    /// <returns>返回物品数量总和。</returns>
    int Get_ItemCountTotal_PlayerRank(SaveData saveData)
    {
        if (saveData == null || saveData.SD_Items == null)
        {
            return 0;
        }

        var total = 0;
        foreach (var item in saveData.SD_Items)
        {
            // itemCount 是玩家物品持有数量, 负数异常值按0处理。
            if (item != null)
            {
                total += Math.Max(0, item.itemCount);
            }
        }

        return total;
    }

    /// <summary>
    /// 统计运行时导出的物品总数量。
    /// </summary>
    /// <param name="items">运行时导出的物品存档列表。</param>
    /// <returns>返回物品数量总和。</returns>
    int Get_ItemCountTotal_PlayerRank(List<SaveData_Item> items)
    {
        if (items == null)
        {
            return 0;
        }

        var total = 0;
        foreach (var item in items)
        {
            if (item != null)
            {
                total += Math.Max(0, item.itemCount);
            }
        }

        return total;
    }

    /// <summary>
    /// 获取当前运行时关卡索引。
    /// </summary>
    /// <param name="gameData">当前账号运行时数据。</param>
    /// <param name="fallbackSaveData">当前账号存档数据。</param>
    /// <returns>返回当前关卡索引。</returns>
    int Get_CurrentLevelIndex_PlayerRank(GameData gameData, SaveData fallbackSaveData)
    {
        if (gameData != null &&
            gameData.Sys_Chapter != null &&
            gameData.Sys_Chapter.currentChapter != null &&
            gameData.Sys_Chapter.currentChapter.level_List != null &&
            gameData.Sys_Chapter.CurrentLevel != null)
        {
            var currentLevelIndex = gameData.Sys_Chapter.currentChapter.level_List.IndexOf(gameData.Sys_Chapter.CurrentLevel);
            if (currentLevelIndex >= 0)
            {
                return currentLevelIndex;
            }
        }

        return fallbackSaveData != null ? fallbackSaveData.currentLevelIndex : 0;
    }
}
