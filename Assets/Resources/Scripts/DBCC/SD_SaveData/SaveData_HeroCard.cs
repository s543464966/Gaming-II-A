using System;
using UnityEngine;

[Serializable]
//======可序列化的玩家卡牌数据======//
public class SaveData_HeroCard
{
    [Header("模块: 卡牌基础存档数据")]
    // --- 核心 ID ---
    [Tooltip("卡牌绑定的SO编号")] public string cardID; //卡牌绑定的SO编号
    // --- 状态数据 ---
    [Tooltip("卡牌当前血量")] public float hp; //卡牌当前血量
    [Tooltip("对战位置排序号 -1为未出战")] public int posIndex = -1; //对战位置排序号 -1为未出战
    //public string equipID;  //后续穿戴的装备SO编号
    // 记录该卡牌激活的隐秘之路的表数据

    // ==========================================
    // 1. 初始化与工厂方法 (Init/Factory)
    // ==========================================

    /// <summary>
    /// 英雄卡牌存档数据构造函数
    /// 这里负责：初始化卡牌存档的ID、血量以及出战位置
    /// </summary>
    /// <param name="_cardID">卡牌 SO 编号</param>
    /// <param name="_hp">当前血量</param>
    /// <param name="_posIndex">出战位置</param>
    public SaveData_HeroCard(string _cardID, float _hp, int _posIndex)
    {
        cardID = _cardID;
        hp = _hp;
        posIndex = _posIndex;
    }
}
