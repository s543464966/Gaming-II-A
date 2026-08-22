using System;
using System.Collections.Generic;
using UnityEngine;

[Serializable]
//======可序列化的章节数据======//
public class SaveData_Chapter
{
    [Header("模块: 章节基础存档数据")]
    [Tooltip("章节索引")] public int chapterIndex; //章节索引
    [Tooltip("章节是否解锁")] public bool isUnlocked; //章节是否解锁
    [Tooltip("章节是否完成")] public bool isCompleted; //章节是否完成
    [Tooltip("记录随机关卡路线")] public List<SaveData_Level> saveData_Levels_Route; //记录随机关卡路线

    // ==========================================
    // 1. 初始化与工厂方法 (Init/Factory)
    // ==========================================

    /// <summary>
    /// 章节存档数据构造函数
    /// 这里负责：初始化章节的基础存档配置，包括索引、是否解锁、是否已完成
    /// </summary>
    /// <param name="_chapterIndex">章节的索引编号</param>
    /// <param name="_isUnlocked">是否已解锁</param>
    /// <param name="_isCompleted">是否已完成</param>
    public SaveData_Chapter(int _chapterIndex, bool _isUnlocked, bool _isCompleted)
    {
        chapterIndex = _chapterIndex;
        isUnlocked = _isUnlocked;
        isCompleted = _isCompleted;
    }

}
