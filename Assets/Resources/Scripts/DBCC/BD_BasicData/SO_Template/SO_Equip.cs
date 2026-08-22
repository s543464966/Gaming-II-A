using UnityEngine;

[CreateAssetMenu]
public class SO_Equip : ScriptableObject
{
    //基础设定
    [Tooltip("装备变量")] public string equipId;
    [Tooltip("装备名")] public string equipName;
    [Tooltip("装备图片")] public Sprite equipSprite;
    [Tooltip("装备星级")] public int equipRank;
    [Tooltip("装备介绍")] public string info;

    //数值
    [Tooltip("词条类型")] public int valueType1;
    [Tooltip("词条优先级")] public int value1;
    [Tooltip("词条类型")] public int valueType2;
    [Tooltip("词条优先级")] public int value2;
    [Tooltip("词条类型")] public int valueType3;
    [Tooltip("词条优先级")] public int value3;

    //词条
    [Tooltip("词条类型")] public int entryType;
    [Tooltip("词条优先级")] public int entryPriority;
}
