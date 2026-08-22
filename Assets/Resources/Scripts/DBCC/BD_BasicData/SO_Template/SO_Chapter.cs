using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu]
//======章节SO数据类======//
public class SO_Chapter : ScriptableObject
{
    [Tooltip("章节ID")] public string chapterId; //章节ID
    public int chapterIndex; //章节序号
    [Tooltip("章节难度")] public int chapterDifficulty; //章节难度
    public string file_Monster; //章节包含的关卡列表

      
    //基础设定
    [Tooltip("章节名称")] public string chapterName; //章节名称
    public string info; //章节介绍
    [Tooltip("关卡耗费体力")] public int staminaCost; //关卡耗费体力
    public Sprite chapterBG_0; //章节图片，已锁定
    [Tooltip("章节图片，已解锁")] public Sprite chapterBG_1; //章节图片，已解锁

    public float chapterIntensity; //章节强度
    [Tooltip("本章节新增骰子")] public List<string> diceTypeAdd; //本章节新增骰子
    public float randomMe; //随机元数据
    [Tooltip("章节奖励")] public List<string> chapterReward; //章节奖励
    public List<int> chapterRest;//章节休整
    [Tooltip("章节怪物")] public List<int> chapterMonster; //章节怪物
    public List<int> chapterMonsterElite;//章节精英
    [Tooltip("章节遗迹")] public List<int> chapterRelic; //章节遗迹
    public List<int> chapterBlackMarket;//章节黑市
    public List<int> chapterAdvanture;//

    
    [Tooltip("关卡怪物数量")] public List<int> levelMonsterNum; //关卡怪物数量
    //public List<List<string>> levelMonsterDice;  //关卡怪物骰子
    public List<LevelMonsterDice_List>levelMonsterDice;
}
