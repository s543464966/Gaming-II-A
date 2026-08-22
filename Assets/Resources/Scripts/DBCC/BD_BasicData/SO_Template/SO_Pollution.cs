using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu]
public class SO_Pollution : ScriptableObject
{
    //基础设定
    [Tooltip("污染之力ID")] public string pollutionId;
    [Tooltip("污染之力名称")] public string pollutionName;
    [Tooltip("污染之力图片")] public Sprite pollutionSprite;
    [Tooltip("污染之力星级")] public int pollutionRank;
    [Tooltip("介绍")] public string info;

    //数值
    [Tooltip("数值类型1")] public int valueType1;
    [Tooltip("数值1")] public float value1;
    [Tooltip("数值类型2")] public int valueType2;
    [Tooltip("数值2")] public float value2;
    [Tooltip("数值类型3")] public int valueType3;
    [Tooltip("数值类型2")] public float value3;

    //词条
    [Tooltip("词条类型")] public int entryType;
    [Tooltip("词条优先级")] public int entryPriority;
}