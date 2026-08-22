using UnityEngine;
public enum ItemType// 定义物品类型枚举
{
    None = 0,
    Material = 1, // 材料
    Prop = 2,    // 道具
}
[CreateAssetMenu]
public class SO_Item : ScriptableObject //  物品统一数据结构
{
    //基础设定
    [Header("通用属性")]
    [Tooltip("物品序号")]public string itemId;
    [Tooltip("物品名称")]public string itemName;
    [Tooltip("物品图片")]public Sprite itemSprite;
    [Tooltip("物品介绍")]public string info;

    [Header("逻辑属性")]
    [Tooltip("物品类型：用于背包分类显示")]public ItemType itemType;
    [Tooltip("物品上限")]public int maxStack = 999;
    //

    // //数值
    // [Tooltip("词条类型")] public int valueType1;
    // [Tooltip("词条优先级")] public int value1;
    // [Tooltip("词条类型")] public int valueType2;
    // [Tooltip("词条优先级")] public int value2;
    // [Tooltip("词条类型")] public int valueType3;
    // [Tooltip("词条优先级")] public int value3;

    // //词条
    // [Tooltip("词条类型")] public int entryType;
    // [Tooltip("词条优先级")] public int entryPriority;
}
