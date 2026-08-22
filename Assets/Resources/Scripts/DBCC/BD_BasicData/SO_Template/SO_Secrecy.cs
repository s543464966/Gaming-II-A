using UnityEngine;

[CreateAssetMenu]
public class SO_Secrecy : ScriptableObject
{
    // 基础设定
    [Tooltip("隐秘ID")] public string securecyId; //
    [Tooltip("隐秘名称")] public string securecyName;
    [Tooltip("隐秘形象")] public string securecySprite;
    [Tooltip("介绍")] public string info;

    //天赋英雄
    [Tooltip("匹配的隐秘英雄")] public string securecyHero;
    [Tooltip("隐秘序号")] public string securecyIndex;

    //数值
    [Tooltip("词条类型")] public int valueType1;
    [Tooltip("词条优先级")] public float value1;
    [Tooltip("词条类型")] public int valueType2;
    [Tooltip("词条优先级")] public float value2;
    [Tooltip("词条类型")] public int valueType3;
    [Tooltip("词条优先级")] public float value3;

    //词条
    [Tooltip("词条类型")] public int entryType;
    [Tooltip("词条优先级")] public int entryPriority;


}
