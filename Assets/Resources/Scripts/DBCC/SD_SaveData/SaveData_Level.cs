using System;
using System.Collections.Generic;
using UnityEngine;

[Serializable]
//======可序列化的关卡数据======//
public class SaveData_Level
{
    [Header("模块: 关卡基础存档数据")]
    [Tooltip("关卡是否解锁")] public bool isUnlocked; //关卡是否解锁  false==未解锁, true==已解锁
    [Tooltip("关卡是否完成")] public bool isCompleted; //关卡是否完成 false==未完成, true==已完成
    [Tooltip("关卡是否被选择")] public bool isSelected; //关卡是否被选择 false==未被选中, true==被选中
    [Tooltip("关卡是否做出选择")] public bool isMakeSelected;   //关卡是否做出选择 false==未做出选择, true==做出选择
    [Tooltip("关卡是否被前面的关卡进行选择路线")] public bool isBeforeSelecting; //关卡是否被前面的关卡进行选择路线 false==未选择, true==正在选择
    [Tooltip("关卡评级星级")] public int levelStar;   //关卡评级星级
    [Tooltip("关卡耗费体力")] public int staminaCost; //关卡耗费体力
    [Tooltip("关卡类型")] public LevelType levelType; //关卡类型
    [Tooltip("关卡普通怪物的数量")] public int monsterCount; //关卡普通怪物的数量
    [Tooltip("关卡同层数据")] public List<int> sameLayer; //关卡同层数据索引
    [Tooltip("关卡下一层数据索引")] public List<int> nextLayer; //关卡下一层数据索引
    [Tooltip("关卡上一层数据索引")] public List<int> beforeLayer; //关卡上一层数据索引
    [Tooltip("123表示从左到右,0=没有路,1=有路.sprite资源")] public List<int> levelRoadSpriteStatus; //123表示从左到右, 0=没有路, 1=有路. sprite资源
    [Tooltip("123表示从左到右,0表示没有选择,1表示选择路线")] public List<int> levelRoadStatus;//123表示从左到右, 0代表没有选择, 1代表选择的路线
    [Tooltip("关卡内的怪物ID")] public List<string> monsterSO_List; //关卡内的怪物
    [Tooltip("关卡怪物骰子")] public List<string> monsterDiceList;    //关卡怪物骰子

}
