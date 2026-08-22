using UnityEngine;

// [CreateAssetMenu]
public class zzzSO_Monster : MonoBehaviour
{
////基础设定
    [Tooltip("怪物")] public string id;  //怪物ID
    // [Tooltip("怪物Obj")] public GameObject monsterObj;  //怪物ID
    // [Tooltip("怪物名字")] public string name;    //怪物名
    [Tooltip("怪物图片")] public Sprite image;  //图片
    [Tooltip("介绍")] public string info;   //介绍
    [Tooltip("位阶")] public int levelRank;   //位阶

////基础属性
    [Tooltip("生命值上限")] public float hpMax;    //生命值上限
    [Tooltip("能量值上限")] public int manaMax;    //能量值上限 
    [Tooltip("攻击力")] public float atk;   //攻击力
    [Tooltip("防御力")] public float apr;  //防御力

////高级属性
    [Tooltip("生命值因子")] public float hpMaxFactor;    //生命值因子
    [Tooltip("速度")] public float asp;   //速度

////元素加成属性
    [Tooltip("光元素")] public float manaLight;    //光元素
    [Tooltip("暗元素")] public float manaDark;    //暗元素
    [Tooltip("木元素")] public float manaWood;    //木元素
    [Tooltip("岩元素")] public float manaRock;    //岩元素
    [Tooltip("金元素")] public float manaMetal;    //金元素
    [Tooltip("水元素")] public float manaWater;    //水元素
    [Tooltip("火元素")] public float manaFire;    //火元素
    [Tooltip("风元素")] public float manaWind;    //风元素
    [Tooltip("雷元素")] public float manaThunder;    //雷元素
    [Tooltip("冰元素")] public float manaIce;    //冰元素
}