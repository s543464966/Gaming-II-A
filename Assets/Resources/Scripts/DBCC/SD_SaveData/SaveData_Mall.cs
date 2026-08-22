using System.Collections.Generic;
using System;

[Serializable]
public class SaveData_Mall
{
    // 1. 实体列表：所有产生过购买行为的商品
    // 用 List 完美避开了 Unity 不支持 Dictionary 序列化的坑
    public List<SaveData_Commodity> saveData_Commodity = new List<SaveData_Commodity>();

    // 2. 系统级全局状态：上次全局刷新的时间戳
    public long lastDailyRefreshTime = 0;
    public long lastWeeklyRefreshTime = 0;
    
    // 【扩展预留】
    // public int todayFreeRefreshCount = 0; // 玩家今天手动免费刷新商城的次数
}
