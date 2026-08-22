using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Unity.VisualScripting;
using UnityEngine;

public class CC_Dice : MonoBehaviour
{
    // ==========================================
    // 1. 数据核心 (Data Core)
    // ==========================================
    
    // --- 内部状态 --- (基础必要数据与引用)
    private GameData GameData => DBCC_DataBase.Instance.GameData; // GameData别名[因为单例原因]
    private SaveData SaveData => DBCC_DataBase.Instance.SaveData; // SaveData简写

    // --- 内部状态 --- (临时字典与集合)
    private SO_Dice[] all_SO_Dices; // 所有骰子配表数组
    private Dictionary<string, Dice> heroDiceDict; // 玩家拥有的卡牌字典
    private List<Dice> heroDiceFightList; // 玩家拥有的卡牌中，出战的卡牌列表
    private Dictionary<string, Dice> lockDiceDict; // 玩家未拥有的卡牌字典

    // ----------------------------------------------------------------------------------------------------------
        
    //模块：Initial - 初始化
    // public void Init_Dice()
    // {
    //     //初始化玩家骰子池
    //     heroDiceDict = new Dictionary<string, Dice>();
    //     lockDiceDict = new Dictionary<string, Dice>();
    //     heroDiceFightList = new List<Dice>();
        
    //     //加载所有英雄和随从卡牌的固定SO数据 和 DBCC中玩家的Dice数据:
    //     all_SO_Dices = Resources.LoadAll<SO_Dice>("Dice");
    //     if (all_SO_Dices == null) { Debug.LogError("未找到章节SO_Dice: 请检查文件路径: Dice"); }
    //     Dictionary<string, SaveData_Dices> SD_Dices = DBCC_DataBase.Instance.SaveData.SD_Dices; //章节1~N;

    //     //初始化所有Dice并为其赋予SD和SO数据
    //     foreach (SO_Dice _all_SO_Dice in all_SO_Dices)
    //     {
    //         Dice dice = null;

    //         //根据UserSaveData数据，设定Dice的基础信息。
    //         if (SD_Dices.TryGetValue(_all_SO_Dice.diceId, out SaveData_Dices saveData_Dices))
    //         {
    //             // 已解锁
    //             dice = new Dice(_all_SO_Dice);  //给与必要的基础SO数据
    //             dice.Init_HeroCard(saveData_Dices.getNum, saveData_Dices.isDiceFight); //初始化所有非SO的动态数据
    //             heroDiceDict[dice.SO_Dice.diceId] = dice;   //将已解锁的heroCard添加进入卡牌字典 
    //             if (dice.isDiceFight == true)
    //             {
    //                 heroDiceFightList.Add(dice);
    //             }
    //             // if(saveData_HeroCard.)     
    //         }
    //         else
    //         {
    //             // 未解锁
    //             dice = new Dice(_all_SO_Dice);  //给与必要的基础SO数据
    //             lockDiceDict[dice.SO_Dice.diceId] = dice; //将未解锁的heroCard添加进入卡牌字典      
    //         }
    //     }
    //     //将生成好的heroCard数据，存回到GameData中。
    //     DBCC_DataBase.Instance.GameData.heroDiceDict = heroDiceDict;
    //     DBCC_DataBase.Instance.GameData.heroDiceFightList = heroDiceFightList;
    //     DBCC_DataBase.Instance.GameData.lockDiceDict = lockDiceDict;
    // }
}
