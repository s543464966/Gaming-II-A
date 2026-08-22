using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.Linq;
public class Entry : MonoBehaviour
{
    //====== 基础数据 ======//
    [Header("模块: 基础数据")]
    [Tooltip("技能类型2")] public int entryType; // 技能类型2
    [Tooltip("技能优先级")] public int entryPriority; // 技能优先级
    [Tooltip("技能模板组件")] public C_Ability_T C_Ability_T; // 技能模板组件

    //====== 动态数据 ======//
    [Header("模块: 动态数据")]
    [Tooltip("触发物体")] public GameObject cardObj; // 触发物体

    // ==========================================
    // 1. 初始化与工厂方法 (Init/Factory)
    // ==========================================

    /// <summary>
    /// 词条创建时, 通过构造函数获取基本数据
    /// 这里负责: 初始化词条的类型, 优先级, 以及相关的游戏对象引用
    /// </summary>
    /// <param name="_entryType">词条类型</param>
    /// <param name="_entryPriority">触发优先级</param>
    /// <param name="_cardObj">触发该词条的物体</param>
    /// <param name="_C_Ability_T">对应的能力模板组件</param>
    public Entry(int _entryType, int _entryPriority, GameObject _cardObj, C_Ability_T _C_Ability_T)
    {
        entryType = _entryType;
        entryPriority = _entryPriority;
        cardObj = _cardObj;
        C_Ability_T = _C_Ability_T;

    }
}

