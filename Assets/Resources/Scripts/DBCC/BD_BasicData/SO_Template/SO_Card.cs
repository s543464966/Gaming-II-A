using UnityEngine;

[CreateAssetMenu]
public class SO_Card : ScriptableObject
{
    ////基础设定
    [Header("模块: 基础设定")]
    [Tooltip("卡牌ID")] public string cardId; //卡牌ID
    [Tooltip("卡牌类型")] public string cardType; //卡牌类型
    [Tooltip("卡牌名字")] public string cardName; //卡牌名
    [Tooltip("卡牌主图")] public Sprite cardImage; //图片
    [Tooltip("介绍")] public string info; //介绍
    [Tooltip("等级提升信息")] public string gradeInfo; //等级提升信息


    //购买相关
    [Header("模块: 购买相关")]
    [Tooltip("卡牌购买花费")] public string costG; //卡牌购买花费


    //卡牌特质
    [Header("模块: 卡牌特质")]
    [Tooltip("元素特质")] public string elementType; //元素特质
    [Tooltip("元素特质")] public Sprite elementTypeImage; //元素特质图片
    [Tooltip("职业")] public string careerType; //职业
    [Tooltip("职业")] public Sprite careerTypeImage; //职业图片


    //技能相关
    [Header("模块: 技能相关")]
    [Tooltip("技能Id")] public string skillId; //技能Id


    ////基础属性
    [Header("模块: 基础属性")]
    [Tooltip("能量值上限")] public int manaMax; //能量值上限 
    [Tooltip("生命值上限")] public float hpMax; //生命值上限
    [Tooltip("攻击力")] public float atk; //攻击
    [Tooltip("攻击力")] public string atkType; //攻击类型
}