using UnityEngine;

[CreateAssetMenu]
public class SO_Ability : ScriptableObject
{
    //基础设定
    [Tooltip("能力ID")] public string abilityId; //
    [Tooltip("能力名称")] public string abilityName;
    [Tooltip("能力图标")] public string abilitySprite;
    [Tooltip("能力描述")] public string info;
    [Tooltip("技能特效类型")]public int tx_Skill_Model;// 1是飞行 2是瞬发
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

    //目标特性
    // [Tooltip("目标类型: hero表示友方, monster表示敌方怪物")] public string targetType = "hero";
    // [Tooltip("排列位置: All表示全部, x表示同行, y表示同列")] public string targetAxis;
    // [Tooltip("包含自身: 0为不包含, 1为包含, 默认为0")] public int targetSelf;
    // [Tooltip("目标人数: 目标群体中的几人, 0为全部, 1为整体中的随即一个人, 默认1人")] public int targetNum;
    // [Tooltip("最近的人: 0表示无要求, 正为最近负则为最远, 1表示1个, 2表示2个 ")] public int targetDistance;
    // [Tooltip("释放次数: 对同个目标释放次数, 默认1次")] public int releaseNum = 1;
}