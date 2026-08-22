using System;

[Serializable]
public class SaveData_Commodity
{
    public string commodityId;   // 商品ID
    public int boughtCount;   // 已购买次数

    // 【极强的扩展性预留】
    // public long individualNextRefreshTime; // 独立刷新时间戳
    // public float currentDynamicDiscount;   // 玩家专属随机折扣（比如砍一刀）

    public SaveData_Commodity(string _commodityId, int _boughtCount)
    {
        commodityId = _commodityId;
        boughtCount = _boughtCount;
    }
}
