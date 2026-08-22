using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[Serializable]
//======可序列化的物品数据======//
public class SaveData_Item
{
    [Header("模块: 物品基础存档数据")]
    [Tooltip("物品绑定的SO编号")] public string itemID; //物品绑定的SO编号
    [Tooltip("拥有数量")] public int itemCount;  //拥有数量

    // ==========================================
    // 1. 初始化与工厂方法 (Init/Factory)
    // ==========================================

    /// <summary>
    /// 物品存档数据构造函数
    /// 这里负责：初始化物品存档的ID和数量
    /// </summary>
    /// <param name="_itemID">物品 SO 编号</param>
    /// <param name="_itemCount">物品持有数量</param>
    public SaveData_Item(string _itemID, int _itemCount)
    {
        itemID = _itemID;
        itemCount = _itemCount;
    }
}
