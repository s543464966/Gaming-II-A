using UnityEngine;

[CreateAssetMenu]
public class SO_Talent : ScriptableObject
{
    //基础设定
    [Tooltip("天赋之力")] public string talentId; //
    [Tooltip("天赋之力")] public string talentName;
    [Tooltip("天赋之力")] public string talentSprite;
    [Tooltip("天赋之力")] public string info;

    //天赋英雄
    [Tooltip("词条类型")] public string talentHero;
    [Tooltip("词条类型")] public string talentIndex;

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
