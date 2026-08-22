using System.Collections;
using System.Collections.Generic;
using UnityEngine;

//======章节运行时动态数据类======//
public class Chapter//章节数据类
{
    //====== 基础数据 ======//
    public SO_Chapter SO_Chapter; // 章节SO数据

    //====== 动态数据 ======//
    public bool isUnlocked; // 章节是否解锁
    public bool isCompleted; // 章节是否完成
    public List<Level> level_List = new List<Level>(); // 章节包含的关卡列表

    //====== 临时数据 ======//
    public List<SO_Card> SO_Monsters_List = new List<SO_Card>(); // 普通怪物
    public List<SO_Card> SO_MonstersElite_List = new List<SO_Card>(); // 精英怪物
    public SO_Card SO_MonstersBoss; // Boss怪物
    public Sprite Level_ConnectLine_x_Off; // 连接线UI图片(未激活)
    public Sprite Level_ConnectLine_x_On; // 连接线UI图片(激活)
    public Sprite Level_ConnectLine_xy_Off; // 分叉连接线UI图片(未激活)
    public Sprite Level_ConnectLine_xy_On; // 分叉连接线UI图片(激活)
    public Sprite Level_Monster_Not; // 未挑战节点UI
    public Sprite Level_Monster_Pass; // 已通关节点UI
    public Sprite Level_Monster_Ready; // 当前可挑战节点UI
    public Sprite Level_Unknown; // 未知节点UI

    // ==========================================
    // 1. 初始化与工厂方法 (Init/Factory)
    // ==========================================

    /// <summary>
    /// 【核心】章节创建时初始化数据
    /// 这里负责: 1.赋值基本SO数据, 2.初始化解锁状态, 3.并在已解锁情况下加载该章节的所有UI精灵切图
    /// </summary>
    /// <param name="_SO_Chapter">章节的基础静态数据表</param>
    /// <param name="_isUnlocked">是否默认解锁该章节</param>
    public Chapter(SO_Chapter _SO_Chapter, bool _isUnlocked)
    {
        //获取基本数据
        SO_Chapter = _SO_Chapter;

        //获取动态数据
        isUnlocked = _isUnlocked; // 第一章默认解锁(动态数据)
        isCompleted = false;

        //获取临时数据
        //判断章节是否解锁, 如果解锁则加载对应章节所需的关卡UI图片
        if (isUnlocked == true)
        {
            Sprite[] level_UISprite_List = Resources.LoadAll<Sprite>($"Chapter/{_SO_Chapter.chapterId}/Level");//Chapter/Chapter0101/Level
            // Load_Level_UISprite(level_UISprite_List);
            Level_ConnectLine_x_Off = level_UISprite_List[0];
            Level_ConnectLine_x_On = level_UISprite_List[1];
            Level_ConnectLine_xy_Off = level_UISprite_List[2];
            Level_ConnectLine_xy_On = level_UISprite_List[3];
            Level_Monster_Not = level_UISprite_List[4];
            Level_Monster_Pass = level_UISprite_List[5];
            Level_Monster_Ready = level_UISprite_List[6];
            Level_Unknown = level_UISprite_List[7];
            Debug.Log("章节里的关卡iconUI已经正确加载并挂载!");
            //Sprite[] level_UISprite_List = Resources.LoadAll<Sprite>("Chapter/Chapter001/Level");
            //chapter.Load_Level_UISprite(level_UISprite_List);
        }
    }

    // //章节创建时, 加载并存储当前章节对应的所有关卡的UI图片
    // public void Load_Level_UISprite(Sprite[] _level_UISprit)
    // {
    //     Level_ConnectLine_x_Off = _level_UISprit[0];
    //     Level_ConnectLine_x_On = _level_UISprit[1];
    //     Level_ConnectLine_xy_Off = _level_UISprit[2];
    //     Level_ConnectLine_xy_On = _level_UISprit[3];
    //     Level_Monster_Not = _level_UISprit[4];
    //     Level_Monster_Pass = _level_UISprit[5];
    //     Level_Monster_Ready = _level_UISprit[6];
    //     Level_Unknown = _level_UISprit[7];
    // } 
}

