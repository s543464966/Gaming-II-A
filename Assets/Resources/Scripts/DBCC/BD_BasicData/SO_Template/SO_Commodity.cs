using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu]
public class SO_Commodity : ScriptableObject
{
    [Header("商品基础信息")]
    public string commodityId;       // 商品的唯一ID (如: Shop_Hero_001)
    public MallTabType tabType;      // 属于哪个商店页签 (如: 每日特惠, 英雄馆)
    public int sortOrder;            // 在商店里的排序优先级

    [Header("发货内容")]
    //public RewardType rewardType;    // 给什么类型的奖励
    public string rewardId;          // 给哪个具体的东西 (对应 SO_Card.cardId 或 SO_Item.itemId)
    public int rewardAmount = 1;     // 给多少个 (买卡牌通常是1，买药水可能是10)

    [Header("价格与规则")]
    public CurrencyType currencyType;   // 消耗哪种货币
    public int basePrice;   // 基准原价
    [Tooltip("限购次数,0代表不限购")]
    public int maxBuyLimit = 0;
}
