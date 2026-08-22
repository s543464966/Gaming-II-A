using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

public class Sys_Mall
{
    //获取数据中心
    private GameData GameData => DBCC_DataBase.Instance.GameData;   //GameData别名[因为单例原因]
    // ==========================================
    // 1. 数据核心 (Data Core)
    // ==========================================
    
    // --- 内部状态 --- (总表缓存)
    // 使用字典作为总表，Key 为 commodityId，好处：购买时 O(1) 极速校验，防止高并发或快速点击时的性能损耗
    private Dictionary<string, Commodity> allCommodityDict = new Dictionary<string, Commodity>();
    // ==========================================
    // 2. 初始化流程 (Init)
    // ==========================================

    /// <summary>
    /// 系统初始化及存档加载
    /// 负责: 1.读取存档与商品全局SO表, 2.重组动态数据(购买次数), 3.解析并引用展示预置数据
    /// </summary>
    /// <param name="_SD_Mall">商城存档数据引用</param>
    public void Init_Sys_Mall(SaveData_Mall _SD_Mall)
    {
        allCommodityDict.Clear();

        // A. 建立存档高速缓存 (List -> Dictionary)，方便后续比对
        Dictionary<string, SaveData_Commodity> sdDict = new Dictionary<string, SaveData_Commodity>();
        if (_SD_Mall != null && _SD_Mall.saveData_Commodity != null)
        {
            foreach (var sc in _SD_Mall.saveData_Commodity)
            {
                sdDict[sc.commodityId] = sc;
            }
        }

        // B. 遍历所有的商品 SO 配置
        if (GameData.All_SO_Commodities != null)
        {
            foreach (var kvp in GameData.All_SO_Commodities)
            {
                SO_Commodity SO_Commodity = kvp.Value;
                int boughtCount = 0; //购买次数，默认为 0
                // C. 注入动态数据：如果在存档里查到了这件商品，就把存档里的购买次数拿出来
                if (sdDict.TryGetValue(SO_Commodity.commodityId, out SaveData_Commodity SaveData_Commodity))
                {
                    boughtCount = SaveData_Commodity.boughtCount;
                }
                Commodity newCommodity = new Commodity(SO_Commodity, boughtCount);

                // 【核心新增】让数据自己去 GameData 解析自己的图文展示资源 (MVC彻底解耦)
                Parse_CommodityDisplayData(newCommodity);

                allCommodityDict[SO_Commodity.commodityId] = newCommodity;
            }
        }

        // D. 预留口：在这里可以调用时间戳比对，清理需要每日重置的限购商品
        // CheckAndResetPeriodicCommodities(shopSaveData);

        Debug.Log($"[Sys_Mall] 商城系统初始化完成，共上架 {allCommodityDict.Count} 件商品");
    }
    // ==========================================
    // 3. 辅助解析逻辑
    // ==========================================

    /// <summary>
    /// 【核心】底层解析封装功能
    /// 负责: 在系统层面为基础商品对象去数据库查询展示资源并建立反向赋权
    /// </summary>
    /// <param name="commodity">待解析绑定的商品实体对象</param>
    private void Parse_CommodityDisplayData(Commodity commodity)
    {
        string displayTargetId = commodity.SO_Commodity.rewardId;

        // 1. 尝试找卡牌
        if (GameData.All_SO_Heros.TryGetValue(displayTargetId, out SO_Card soCard))
        {
            commodity.commodityName = soCard.cardName;
            commodity.commoditySprite = soCard.cardImage;
            return;
        }

        // 2. 尝试找道具
        if (GameData.All_SO_Items.TryGetValue(displayTargetId, out SO_Item soItem))
        {
            commodity.commodityName = soItem.itemName;
            commodity.commoditySprite = soItem.itemSprite;
            return;
        }

        // 3. 尝试找骰子
        if (GameData.All_SO_Dices.TryGetValue(displayTargetId, out SO_Dice soDice))
        {
            commodity.commodityName = soDice.diceName;
            commodity.commoditySprite = soDice.diceSprite;
            return;
        }

        // 默认保底: 如果全没找到，名字就显示策划填的商品ID，不显示图片
        commodity.commodityName = commodity.SO_Commodity.commodityId;
        commodity.commoditySprite = null;
    }
    // ==========================================
    // 4. API 交互功能
    // ==========================================

    /// <summary>
    /// 获取指定页签下的所有商品列表 (并按策划配置排序)
    /// 负责: 根据传入的页签枚举条件执行LINQ筛选
    /// </summary>
    /// <param name="_targetTab">目标查询页签</param>
    /// <returns>返回筛选完成的商品列表集合</returns>
    public List<Commodity> Get_DisplayCommodities(MallTabType _targetTab)
    {
        return allCommodityDict.Values
            .Where(c => c.SO_Commodity.tabType == _targetTab)
            //.OrderBy(c => c.SO_Commodity.sortOrder) // 假设 SO 里面有 sortOrder
            .ToList();
    }
    /// <summary>
    /// 【核心】原子交易操作
    /// 负责: 1.校验存量、价格与资产, 2.扣款记账, 3.跨模块联动发货(解锁卡牌/入账道具)
    /// </summary>
    /// <param name="commodityId">交易商品的唯一标识码</param>
    /// <returns>返回交易结果枚举以供前端处理判断</returns>
    public MallBuyResult Buy_Commodity(string commodityId)
    {
        // ------------------------------------------
        // 第一阶段：前置严格校验 (Check)
        // ------------------------------------------
        if (!allCommodityDict.TryGetValue(commodityId, out Commodity targetCommodity))
        {
            return MallBuyResult.ItemNotFound;
        }

        SO_Commodity SO_Commodity = targetCommodity.SO_Commodity;

        // 1. 售罄拦截
        if (targetCommodity.IsSoldOut) return MallBuyResult.SoldOut;

        // 2. 价格与资产校验
        int finalPrice = targetCommodity.GetFinalPrice();
        if (!GameData.Sys_User.Has_EnoughCurrency(SO_Commodity.currencyType, finalPrice))
        {
            return MallBuyResult.NotEnoughCurrency;
        }

        // 3. 背包容量校验 (按需启用)
        // if (so.rewardType == RewardType.Item && GameData.Sys_Inventory.IsFull()) 
        //     return ShopBuyResult.InventoryFull;

        // ------------------------------------------
        // 第二阶段：执行交易与记账 (Execute)
        // ------------------------------------------

        // A. 扣款
        GameData.Sys_User.Deduct_Currency(SO_Commodity.currencyType, finalPrice);

        // B. 跨部门发货路由
        switch (SO_Commodity.tabType)   //等待奖励确认
        {
            case MallTabType.Hero:
                // 通知卡牌系统解锁卡牌
                GameData.Sys_Card.Unlock_Card(SO_Commodity.rewardId);
                break;
            case MallTabType.Minion:
                break;
            case MallTabType.Item:
                // 通知背包系统添加道具
                GameData.Sys_Inventory.Add_Item(SO_Commodity.rewardId, SO_Commodity.rewardAmount);
                break;
                // case MallTabType.Dice:
                //     // GameData.Sys_Dice.UnlockDice(so.rewardId);
                //     break;
        }

        // C. 本部门记账
        targetCommodity.boughtCount++;

        // // D. 强制即时落盘存档 (防退游白嫖)
        // DBCC_DataBase.Instance.SaveGameData(); 

        Debug.Log($"[Sys_Shop] 交易成功！花费 {finalPrice} {SO_Commodity.currencyType} 购买了 {SO_Commodity.rewardAmount} 个 {SO_Commodity.rewardId}");

        return MallBuyResult.Success;
    }
    /// <summary>
    /// 数据导出
    /// 负责: 重构化精简保存, 只将有变动的交易记录存入档案
    /// </summary>
    /// <returns>返回生成的最新商城存档对象</returns>
    public SaveData_Mall Export_MallSaveData()
    {
        //  存入新的
        SaveData_Mall SD_Mall = new SaveData_Mall();

        foreach (var kvp in allCommodityDict)
        {
            Commodity Commodity = kvp.Value;

            // 【核心优化】：只有产生过购买行为的商品才存入存档！
            // 极大地减小了存档文件的体积，完全去冗余。
            if (Commodity.boughtCount > 0)
            {
                SaveData_Commodity saveData_Commodity = new SaveData_Commodity(Commodity.SO_Commodity.commodityId, Commodity.boughtCount);
                SD_Mall.saveData_Commodity.Add(saveData_Commodity);
            }
        }

        // 导出系统级状态
        // exportData.lastDailyRefreshTime = GameData.CurrentTimeStamp; 

        return SD_Mall;
    }
}
