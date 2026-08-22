using System;
using UnityEngine;

[Serializable]
//======可序列化的玩家卡牌数据======//
public class SaveData_Dices
{
    [Header("模块: 骰子基础存档数据")]
    [Tooltip("卡牌绑定的SO编号")] public string diceID; //卡牌绑定的SO编号
    [Tooltip("拥有数量")] public int getNum;  //拥有数量
    [Tooltip("是否出战")] public bool isDiceFight; //是否出战->true为出战

    // ==========================================
    // 1. 初始化与工厂方法 (Init/Factory)
    // ==========================================

    /// <summary>
    /// 存储骰子数据构造函数
    /// 这里负责：初始化骰子存档的编号，数量以及出战情况
    /// </summary>
    /// <param name="_diceID">骰子的 SO 编号</param>
    /// <param name="_getNum">拥有的数量</param>
    /// <param name="_isDiceFight">是否出战</param>
    public SaveData_Dices(string _diceID, int _getNum, bool _isDiceFight)
    {
        diceID = _diceID;
        getNum = _getNum;
        isDiceFight = _isDiceFight;
    }
}
