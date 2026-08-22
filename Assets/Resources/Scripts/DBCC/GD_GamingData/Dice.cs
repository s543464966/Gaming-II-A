using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

//======枚举限制骰子类型和效果======//[维护]
// public enum TargetType { Single, Group }
// public enum EffectType { Single_Attack, Single_Skill, Single_Recover, Group_Attack,Group_Focus,Group_Recover}
//====== 骰子的数据类型 ======//
public class Dice
{
    //====== 基础数据 ======//
    public SO_Dice SO_Dice; // 骰子数据

    //====== 动态数据 ======//
    public int getNum = 0; // 玩家拥有数量, 默认为0, 表示未拥有, 表示未解锁
    public bool isDiceFight; // 是否出战, 默认为false, 表示未出战

    // ==========================================
    // 1. 初始化与工厂方法 (Init/Factory)
    // ==========================================

    /// <summary>
    /// 骰子创建时, 通过构造函数获取基本数据
    /// 这里负责: 赋值 SO_Dice 数据
    /// </summary>
    /// <param name="_SO_Dice">骰子基础设定数据</param>
    public Dice(SO_Dice _SO_Dice)
    {
        SO_Dice = _SO_Dice;
    }

    /// <summary>
    /// 【核心】初始化玩家骰子状态
    /// 这里负责: 1.设置骰子拥有数量和出战状态
    /// </summary>
    /// <param name="_getNum">拥有的数量</param>
    /// <param name="_isDiceFight">是否出战</param>
    public void Init_HeroCard(int _getNum, bool _isDiceFight)
    {
        getNum = _getNum;
        isDiceFight = _isDiceFight;
    }
}



//======玩家骰子随机效果信息======//
// public DiceType DiceData;  //骰子数据;
//====== 位置数据 ======//
// [HideInInspector] public Vector2 originPos;
// //======保留敌方父对象引用======//
// [HideInInspector] public List<GameObject> playerFightCard;
// //======群体骰子队列管理器======//
// [HideInInspector] public Fight_Fighting Fight_Fighting;



// Start is called before the first frame update


// Update is called once per frame
// void Update()
// {

// }
//======实现骰子类型的效果======//[需要维护，因为是实现]
// public void UseDiceEffect(GameObject targetOBJ)
// {
//     if(player_dice.Target == TargetType.Single ) 
//     {
//         //单体攻击骰子
//         if(player_dice.Effect == EffectType.Single_Attack)
//         {
//             Debug.Log("单体攻击骰子");
//             //恢复1点法力值，并进行一次正常攻击
//             targetOBJ.GetComponent<C_Fight>().SingleAttack();
//         }
//         //单体技能骰子
//         if(player_dice.Effect == EffectType.Single_Skill)
//         {
//             Debug.Log("单体技能骰子");
//             //无视法力值释放一次技能。而后恢复1点法力值
//             // int addMagic = 1;
//             targetOBJ.GetComponent<C_Fight>().Single_Skill();
//         }
//         //单体恢复骰子
//         if(player_dice.Effect == EffectType.Single_Recover)
//         {
//             Debug.Log("单体恢复骰子");
//             //额外恢复2点法力和20%最大生命值
//             int addMagic = 2;
//             float addHealth_Ratio = 0.2f;
//             targetOBJ.GetComponent<C_Fight>().Single_Recover(addMagic,addHealth_Ratio);
//         }
//     }
//     else if(player_dice.Target == TargetType.Group)
//     {
//         //群体攻击骰子
//         if (player_dice.Effect == EffectType.Group_Attack)
//         {
//             Debug.Log("群体攻击骰子");
//             //群体恢复1点法力值，进行一次正常攻击
//             foreach (GameObject playerCard in playerFightCard)
//             {
//                 if (playerCard == null) continue;
//                 Fight_Fighting.EnqueueAction_Attack(playerCard, player_dice.Effect);
//             }
//             Fight_Fighting.ProcessQueue();//全部入列完毕后调用第一次
//         }
//         //群体集火骰子
//         if (player_dice.Effect == EffectType.Group_Focus)
//         {
//             Debug.Log("群体集火骰子");
//             //群体恢复1点法力值，对制定目标进行一次正常攻击
//             int addMagic = 1;
//             foreach (GameObject playerCard in playerFightCard)
//             {
//                 if (playerCard == null) continue;
//                 Debug.Log(targetOBJ.GetComponent<C_Fight>().card_SO.cardId);
//                 Fight_Fighting.EnqueueAction_FocusAttack(playerCard, targetOBJ, player_dice.Effect, addMagic);
//             }
//             Fight_Fighting.ProcessQueue();//全部入列完毕后调用第一次
//         }
//         //群体恢复骰子
//         if (player_dice.Effect == EffectType.Group_Recover)
//         {
//             Debug.Log("群体恢复骰子");
//             //群体恢复2点法力值，和20%最大生命值
//             int addMagic = 2;
//             float addHealth_Ratio = 0.2f;
//             foreach (GameObject playerCard in playerFightCard)
//             {
//                 if (playerCard == null) continue;
//                 Fight_Fighting.EnqueueAction_Recover(playerCard, player_dice.Effect, addMagic, addHealth_Ratio);
//             }
//             Fight_Fighting.ProcessQueue();//全部入列完毕后调用第一次
//         }
//     }
// }
