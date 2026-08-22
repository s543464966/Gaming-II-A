using System.Collections;
using System.Collections.Generic;
using UnityEngine;

//======物品运行时动态数据类======//
public class Item
{
    //====== 静态数据 ======//
    public SO_Item SO_Item; // 物品数据

    //====== 动态数据 ======//
    public int itemCount; // 对应数量

    // ==========================================
    // 1. 初始化与工厂方法 (Init/Factory)
    // ==========================================

    /// <summary>
    /// 物品创建时, 通过构造函数获取基本数据
    /// 这里负责: 赋值 SO_Item 数据和基本数量
    /// </summary>
    /// <param name="_SO_Item">物品基础设定数据</param>
    /// <param name="_itemCount">物品持有数量</param>
    public Item(SO_Item _SO_Item, int _itemCount)
    {
        SO_Item = _SO_Item;
        itemCount = _itemCount;
    }
}
