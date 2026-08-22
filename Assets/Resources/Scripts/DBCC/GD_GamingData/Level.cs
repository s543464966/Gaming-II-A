using System;
using System.Collections.Generic;
using System.IO;
using UnityEngine;

public enum LevelType { Start, M, Me, Mb, Rest, Relic, BlackMarket, Advanture } // 关卡类型: 普通, 精英, Boss, 休整, 遗迹, 黑市, 冒险
//======关卡数据类======//
public class Level
{
    //====== 基础数据 ======//
    public Sprite levelTypeIcon; // 关卡UI图片
    public List<Sprite> levelrRoad = new List<Sprite> { null, null, null }; // 123表示从左到右, null=未选择, 有图片=已选择.

    //====== 动态数据 ======//
    public bool isUnlocked; // 关卡是否解锁 false==未解锁, true==已解锁
    public bool isCompleted; // 关卡是否完成 false==未完成, true==已完成
    public bool isSelected; // 关卡是否被选择 false==未被选中, true==被选中
    public bool isMakeSelected; // 关卡是否做出选择 false==未做出选择, true==做出选择
    public bool isBeforeSelecting; // 关卡是否被前面的关卡进行选择路线 false==未选择, true==正在选择
    public int levelStar; // 关卡评级星级
    public List<Level> sameLayer; // 关卡同层数据
    public List<Level> nextLayer = new List<Level>(); // 关卡下一层数据
    public List<Level> beforeLayer = new List<Level>(); // 关卡上一层数据
    public List<int> levelrRoadStatus = new List<int> { 0, 0, 0 }; // 123表示从左到右, 0代表没有选择, 1代表选择的路线
    public LevelType levelType; // 关卡类型: 普通, 精英, Boss, 休整, 遗迹, 黑市, 奇遇
    public int staminaCost; // 关卡耗费体力
    public int monsterCount; // 关卡普通怪物的数量
    public List<SO_Card> monsterSO_List = new List<SO_Card>(); // 关卡内的怪物
    public List<string> monsterDiceFaceList = new List<string>(); // 骰子类型: 0=攻击...
    public List<string> monsterDiceList; // 关卡怪物骰子

    //====== 绑定委托 ======//
    public Action OnLevelStateChangedEvent; // 节点专属通知 (脏刷新广播源)

    // ==========================================
    // 1. 初始化与工厂方法 (Init/Factory)
    // ==========================================

    /// <summary>
    /// 关卡创建时, 通过构造函数获取基本数据
    /// 这里负责: 初始化关卡需要的怪物信息, 体力消耗, 以及默认锁定和未完成的状态
    /// </summary>
    /// <param name="_monsterCount">怪物数量</param>
    /// <param name="_monsterDiceList">怪物携带的骰子信息</param>
    /// <param name="_staminaCost">关卡挑战需要的体力</param>
    public Level(int _monsterCount, List<string> _monsterDiceList, int _staminaCost) // List<Level> _sameLayer, int _monsterDiceCount
    {
        //获取动态数据:
        //sameLayer = _sameLayer;
        monsterCount = _monsterCount;
        // monsterDiceCount = _monsterDiceCount;
        monsterDiceList = _monsterDiceList;
        staminaCost = _staminaCost;
        isUnlocked = false;
        isCompleted = false;
        isSelected = false;
        isMakeSelected = false;
        isBeforeSelecting = false;    //通关后所连接的关卡才会被修改
        levelStar = 0;
    }

    /// <summary>
    /// 添加怪物数据对象
    /// 这里负责: 将参数传入的怪物 SO 数据添加至怪物列表中
    /// </summary>
    /// <param name="_SO_Card">怪物的基础卡牌数据</param>
    public void Add_MonsterSO(SO_Card _SO_Card) // 添加怪物
    {
        monsterSO_List.Add(_SO_Card);
    }
}