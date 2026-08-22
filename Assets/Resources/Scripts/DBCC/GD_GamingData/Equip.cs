using UnityEngine;

//======装备运行时动态数据类======//
public class Equip
{
    //====== 基础数据 ======//
    public SO_Equip SO_Equip; // 装备数据

    //====== 动态数据 ======//
    public int getNum = 0; // 玩家拥有数量, 默认为0, 表示未拥有, 表示未解锁

    // ==========================================
    // 1. 初始化与工厂方法 (Init/Factory)
    // ==========================================

    /// <summary>
    /// 装备创建时, 通过构造函数获取基本数据
    /// 这里负责: 赋值 SO_Equip 数据
    /// </summary>
    /// <param name="_SO_Equip">装备的基础设定数据</param>
    public Equip(SO_Equip _SO_Equip)
    {
        SO_Equip = _SO_Equip;
    }
}