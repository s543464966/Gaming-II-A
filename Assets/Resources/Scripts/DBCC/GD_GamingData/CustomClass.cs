using System.Collections.Generic;
using Unity.Mathematics;
using UnityEngine;

// 商城系统：
public enum CurrencyType { Gold, StarStone, RMB }  // 货币类型
public enum MallTabType // 商店大分页
{ 
    Recommend,  // 推荐区
    Hero,       // 英雄区
    Minion,     // 随从区
    Item        // 道具区
}
public enum ShopRefreshType // 刷新周期 (属于哪个特惠池，或者是否是常驻商品)
{ 
    Permanent,  // 常驻 (固定上架，不刷新)
    Daily,      // 每日特惠池
    Weekly,     // 每周特惠池
    Monthly     // 每月特惠池
}
public enum MallBuyResult   // 购买结果枚举
{
    Success,
    SoldOut,
    NotEnoughCurrency,
    InventoryFull,
    ItemNotFound
}
// Csv转SO系统：
[System.Serializable]
public class LevelMonsterDice_List // 章节段内关卡存放骰子的类
{
    //====== 骰子数据 ======//
    public List<string> dices_List; // 骰子列表 (不在这里new, 解析时赋值)
}
public class CustomClass // 自定义类的存放区
{
    // 不放内容, 上面存放自定义类
}
