using System.Collections;
using System.Collections.Generic;
using UnityEngine;

//======运行时商品的动态数据类======//
public class Commodity
{
    // 静态配置引用
    public SO_Commodity SO_Commodity { get; private set; }
    public int boughtCount; //已购买的次数 

    // UI展示缓存数据 (由 Sys_Mall 初始化时赋值)
    public string commodityName { get; set; }
    public Sprite commoditySprite { get; set; }

    // 运行时的折扣率，1.0为不打折，0.8为八折
    // 这个值可以活动系统 (Sys_Event) 在初始化商城时动态赋予
    public float currentDiscountRate = 1.0f;
    public Commodity(SO_Commodity _SO_Commodity, int _boughtCount)
    {
        SO_Commodity = _SO_Commodity;
        boughtCount = _boughtCount;
        currentDiscountRate = 1.0f; // 默认不打折
    }

    /// <summary>
    /// 获取当前真实结算价格 (原价 * 折扣，向下取整)
    /// </summary>
    public int GetFinalPrice()
    {
        // 向下取整，比如 100金币 打 0.85折 = 85
        return Mathf.FloorToInt(SO_Commodity.basePrice * currentDiscountRate);
    }
    /// <summary>
    /// 是否已售罄 (限购次数大于0 且 已买次数 >= 限购次数)
    /// </summary>
    public bool IsSoldOut => SO_Commodity.maxBuyLimit > 0 && boughtCount >= SO_Commodity.maxBuyLimit;

    /// <summary>
    /// 是否处于打折状态 (用于 UI 展示打折角标)
    /// </summary>
    public bool IsDiscounted => currentDiscountRate < 1.0f;


}
