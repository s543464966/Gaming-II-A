using System.Collections;
using System.Collections.Generic;
using DG.Tweening;
using UnityEngine;
using UnityEngine.UI;

public class C_FightDice : MonoBehaviour
{
    //必要数据
    [Tooltip("骰子类数据结构")] public Dice dice; //骰子类数据结构
    public CC_Fight CC_Fight;

    //临时数据
    [Tooltip("骰子位置")] public Vector2 dicePos; //骰子位置
    public int diceCurrentFace; //骰子当前面值
    [Tooltip("意图顺序透明度比率")] public float preIntentionFadeRate; //意图顺序透明度比率
    public List<GameObject> IntentionCardObjList = new List<GameObject>(); //骰子分配的意图卡牌对象
    [Tooltip("是否已被使用")] public bool isUsed; //是否已被使用
    public int camp; //阵营 0玩家 1怪物
    //  动画参数
    private const float FADE_DURATION = 0.3f;
    private const float MOVE_DURATION = 0.3f;

    // ----------------------------------------------------------------------------------------------------------
    //模块：Initial - 初始化

    public void init_Dice(Vector2 _dicePos, Dice _dice, int _camp, CC_Fight _CC_Fight) //通过外部传输的SO_Disc数据，来修改Obj的数据
    {
        transform.position = _dicePos;  //设置自身位置
        dicePos = _dicePos; //记录自身起始位置
        dice = _dice;
        camp = _camp;   //记录阵营状态
        CC_Fight = _CC_Fight;   //记录分配进来的对战管理脚本
    }

    // ----------------------------------------------------------------------------------------------------------
    //模块: Update - 更新

    //（待改进）这里的更新内容不够全面，还有改进空间
    public void Update_Dice(int _randomFace)
    {
        //更新骰子的面值
        diceCurrentFace = dice.SO_Dice.diceFaceList[_randomFace];
        Debug.Log(dice.SO_Dice.diceFaceList.Count);
        Debug.Log(dice.SO_Dice.diceFaceSpriteList.Count);
        //更具骰子的面值，来匹配对应的图片
        gameObject.GetComponent<Image>().sprite = dice.SO_Dice.diceFaceSpriteList[_randomFace];
    }


    // ----------------------------------------------------------------------------------------------------------
    //模块：Intention - 意图

    //骰子有意图-怪物，骰子无意图-玩家自动，骰子是手动的-玩家手动；
    public void Intention_Auto_FindList()
    {
        //判断是否存在意图列表，如果为0则表示玩家自动化骰子，需要自动选择意图目标,如果有则为怪物自动化骰子
        if (IntentionCardObjList.Count == 0)
        {
            //自动选择意图目标
            if (camp == 0) //玩家
            {
                //玩家自动化骰子
                if (diceCurrentFace <= 10)  //都属于单体效果的范畴
                {
                    if (diceCurrentFace <= 5)//单体选择，己方
                    {
                        int randomHeroObj = Random.Range(0, CC_Fight.fightingHeroObjList.Count);
                        IntentionCardObjList.Add(CC_Fight.fightingHeroObjList[randomHeroObj]); //记录分配给骰子的对象
                    }
                    else //单体选择，敌方
                    {
                        int randomMonsterObj = Random.Range(0, CC_Fight.fightingMonsterObjList.Count);
                        IntentionCardObjList.Add(CC_Fight.fightingMonsterObjList[randomMonsterObj]); //记录分配给骰子的对象
                    }
                    //位移动画(待改进)
                    Sequence moveSequence = Auto_DiceMoveToIntention(gameObject, IntentionCardObjList[0]);
                    //位移动画完成后调用intention方法，同时把自己重置初始状态
                    moveSequence.OnComplete(() =>
                    {
                        Action_Intention();
                    });
                    return;
                }
                //（待改进）群体和队列骰子，他们或驱动骰子前往Container的中间，并且将所有队员加入IntentionObjList中--->(已修改)
                else if (diceCurrentFace <= 210)    //都属于群体效果的范畴
                {
                    if (diceCurrentFace <= 110) //群体瞬发,队列选择，己方
                    {
                        //群体效果寻找己方大区域
                        IntentionCardObjList.Add(CC_Fight.heroFightingArea);
                    }
                    else if (diceCurrentFace <= 210) //群体队列选择，敌方
                    {
                        //群体效果寻找敌方大区域
                        IntentionCardObjList.Add(CC_Fight.monsterFightingArea);
                    }
                    //位移动画(待改进)
                    Sequence moveSequence = Auto_DiceMoveToIntention(gameObject, IntentionCardObjList[0]);
                    //位移动画完成后调用intention方法，同时把自己重置初始状态
                    moveSequence.OnComplete(() =>
                    {
                        Action_Intention();
                    });
                    return;
                }
            }
            else //怪物只分配意图，无需移动动画
            {
                //怪物自动化骰子
                if (diceCurrentFace <= 10)  //都属于单体效果的范畴
                {
                    if (diceCurrentFace <= 5)//单体选择，己方
                    {
                        int randomMonsterObj = Random.Range(0, CC_Fight.fightingMonsterObjList.Count);
                        IntentionCardObjList.Add(CC_Fight.fightingMonsterObjList[randomMonsterObj]); //记录分配给骰子的对象
                        CC_Fight.fightingMonsterObjList[randomMonsterObj].GetComponent<C_FightCard>().diceIntentionObjList.Add(gameObject); //给意图卡牌添加意图的骰子
                    }
                    else    //单体选择，敌方
                    {
                        int randomHeroObj = Random.Range(0, CC_Fight.fightingHeroObjList.Count);
                        IntentionCardObjList.Add(CC_Fight.fightingHeroObjList[randomHeroObj]); //记录分配给骰子的对象
                        CC_Fight.fightingHeroObjList[randomHeroObj].GetComponent<C_FightCard>().diceIntentionObjList.Add(gameObject); //给意图卡牌添加意图的骰子
                    }
                }
                // //群体和队列骰子,对于怪物还是需要找一个目标卡牌
                // else if (diceCurrentFace <= 210)    //都属于群体效果的范畴
                // {
                //     if (diceCurrentFace <= 110) //群体瞬发，队列选择，己方
                //     {
                //         int randomMonsterObj = Random.Range(0, CC_Fight.fightingMonsterObjList.Count);
                //         IntentionCardObjList.Add(CC_Fight.fightingMonsterObjList[randomMonsterObj]); //记录分配给骰子的对象
                //         CC_Fight.fightingMonsterObjList[randomMonsterObj].GetComponent<C_FightCard>().diceIntentionObjList.Add(gameObject); //给意图卡牌添加意图的骰子
                //     }
                //     else if (diceCurrentFace <= 210) //群体队列选择，敌方
                //     {
                //         int randomHeroObj = Random.Range(0, CC_Fight.fightingHeroObjList.Count);
                //         IntentionCardObjList.Add(CC_Fight.fightingHeroObjList[randomHeroObj]); //记录分配给骰子的对象
                //         CC_Fight.fightingHeroObjList[randomHeroObj].GetComponent<C_FightCard>().diceIntentionObjList.Add(gameObject); //给意图卡牌添加意图的骰子
                //     }
                // }
                return;
            }
        }
        else //已经有意图列表，直接使用怪物骰子，并激活动画
        {
            if (IntentionCardObjList[0] != null) //判断意图卡牌对象是否被销毁标记为null了
            {
                //每个骰子目前意图表里只有一个对象，需骰子移动过去后才开始分配对应的目标数量
                Sequence moveSequence = Auto_DiceMoveToIntention(gameObject, IntentionCardObjList[0]);
                //位移动画完成后调用intention方法，同时把自己重置初始状态
                moveSequence.OnComplete(() =>
                {
                    Debug.Log("自动化执行当前骰子面值：" + diceCurrentFace);
                    Action_Intention();
                });
            }
            else
            {
                Action_Intention();
            }
        }
    }

    //玩家手动选择意图目标
    public void Manual_FindList_Intention(GameObject _targetObj)
    {
        if (_targetObj != null)
        {
            IntentionCardObjList.Add(_targetObj);
            //Action_Intention();
        }
        else
        {
            Action_Intention();
        }
        //  执行动画
        Sequence moveSequence = Auto_DiceMoveToIntention(gameObject, IntentionCardObjList[0]);
        //位移动画完成后调用intention方法，同时把自己重置初始状态
        moveSequence.OnComplete(() =>
        {
            Debug.Log("自动化执行当前骰子面值：" + diceCurrentFace);
            Action_Intention();
        });
    }

    void Action_Intention()
    {
        //根据骰子的面值，来寻找对应的目标卡牌，并放入IntentionObjList中
        switch (diceCurrentFace)
        {
            case int n when n >= 0 && n <= 10:
                //单体选择，己方

                //通知CC_Fight，执行对应的骰子效果及更新骰子使用情况。
                CC_Fight.Dice_SingleFightIntention_Playbook(this.gameObject, IntentionCardObjList[0]);
                break;

                // case int n when n >= 21 && n <= 30:
                //     //群体瞬发选择，己方
                //     IntentionCardObjList.Clear();
                //     foreach (GameObject _currentFightingObjList in CC_Fight.currentFightingObjList)
                //     {
                //         //这里需要判断加入的队员不能是自己
                //         // if (_currentFightingObjList == _checkDice.GetComponent<C_Dice>().IntentionObjList[0]) continue;
                //         IntentionCardObjList.Add(_currentFightingObjList);
                //     }
                //     CC_Fight.Auto_GroupFightIntention(this.gameObject, IntentionCardObjList);
                //     break;

                // //群体骰子，备注：但是目前没有设计这块
                // case int n when n >= 100 && n <= 110:
                //     //群体轮动选择，己方
                //     IntentionCardObjList.Clear();
                //     foreach (GameObject _currentFightingObjList in CC_Fight.currentFightingObjList)
                //     {
                //         //这里需要判断加入的队员不能是自己
                //         // if (_currentFightingObjList == _checkDice.GetComponent<C_Dice>().IntentionObjList[0]) continue;
                //         IntentionCardObjList.Add(_currentFightingObjList);
                //     }
                //     CC_Fight.Auto_GroupFightIntention(this.gameObject, IntentionCardObjList);
                //     break;
        }
    }

    //模块：Auto_DiceMoveToIntention - 自动骰子移动到意图位置
    private Sequence Auto_DiceMoveToIntention(GameObject _checkDice, GameObject _intentionObj)
    {
        Sequence moveSequence = DOTween.Sequence(); //创建一个移动动画序列

        //添加位移动画
        moveSequence.Append(_checkDice.transform.DOMove(_intentionObj.transform.position, MOVE_DURATION)
            .SetEase(Ease.OutQuad));
        //添加消失动画
        moveSequence.Append(_checkDice.GetComponent<Image>().DOFade(0, FADE_DURATION))
            .SetEase(Ease.OutQuad);
        //添加缩小动画
        moveSequence.Join(_checkDice.transform.DOScale(Vector3.zero, FADE_DURATION))
            .SetEase(Ease.OutQuad);

        return moveSequence;
    }
    // //判断给的对象是否有C_FightCard组件来判断是给单体还是群体
    // if (_intentionObj.GetComponent<C_FightCard>() != null)
    // {
    //     // //添加目标卡牌反馈动画
    //     // moveSequence.Append(
    //     //     _intentionObj.transform.DOScale(new Vector3(1.2f, 1.2f, 1.2f), scaleDuration)
    //     //         .SetEase(Ease.OutQuad)
    //     //         .SetLoops(2, LoopType.Yoyo)); // 第一次放大，第二次回到原始
    // }
    // else    //有个问题，如果是怪物的群体骰子还是作用在一个卡牌上，动画
    // {
    //     //给所有卡牌添加反馈动画
    // }
    // public void Auto_DiceEnqueue(GameObject _checkDice)
    // {
    //     //判断骰子是否是群体骰子，如果是则需要把所有队友卡牌找到并加入intentionObjList中作为队员,额外的区分骰子存储的是敌人还是友军
    //     // currentDiceFace = _checkDice.GetComponent<C_Dice>().diceCurrentFace;
    //     // //群体骰子, 
    //     // if (currentDiceFace >= 100)
    //     // {

    //     // }

    //     //中断后续for循环，等待当前队列执行完毕后，再次调用Auto_GamerAndMonsterAction

    //     Auto_FightProcessQueue(_checkDice, _checkDice.GetComponent<C_Dice>().IntentionObjList);
    // }

}


// public class GwDice : MonoBehaviour
// {

//     //======怪物骰子随机效果信息======//
//     public DiceType gw_dice;
//     //======骰子的起始位置======//
//     public Vector3 originPos;
//     public Vector3 preIntentionPos;//怪物骰子意图分配位置
//     public float preIntentionFadeRate;  //意图顺序透明度比率
//     //======保留敌方父对象引用======//
//     [HideInInspector] public List<GameObject> gwAllCard;
//     //======群体骰子队列管理器======//
//     [HideInInspector] public Manager_ActionQueue manager_ActionQueue;
//     //======实现骰子类型的效果======//[需要维护，因为是实现]
//     public void UseDiceEffect(GameObject _gwCard)
//     {
//         //单体攻击
//         if (gw_dice.Target == TargetType.Single)
//         {
//             //单体攻击骰子
//             if (gw_dice.Effect == EffectType.Single_Attack)
//             {
//                 Debug.Log("单体攻击骰子");
//                 //恢复1点法力值，并进行一次正常攻击
//                 _gwCard.GetComponent<C_Fight>().SingleAttack();
//             }
//             //单体技能骰子
//             if (gw_dice.Effect == EffectType.Single_Skill)
//             {
//                 Debug.Log("单体技能骰子");
//                 //无视法力值释放一次技能。而后恢复1点法力值
//                 // int addMagic = 1;
//                 _gwCard.GetComponent<C_Fight>().Single_Skill();
//             }
//             //单体恢复骰子
//             if (gw_dice.Effect == EffectType.Single_Recover)
//             {
//                 Debug.Log("单体恢复骰子");
//                 //额外恢复2点法力和20%最大生命值
//                 int addMagic = 2;
//                 float addHealth_Ratio = 0.2f;
//                 _gwCard.GetComponent<C_Fight>().Single_Recover(addMagic, addHealth_Ratio);
//             }
//         }
//         else if (gw_dice.Target == TargetType.Group)
//         {
//             //群体攻击骰子
//             if (gw_dice.Effect == EffectType.Group_Attack)
//             {
//                 Debug.Log("群体攻击骰子");
//                 //群体恢复1点法力值，进行一次正常攻击
//                 foreach (GameObject gwCard in gwAllCard)
//                 {
//                     manager_ActionQueue.EnqueueAction_Attack(gwCard, gw_dice.Effect);
//                 }
//                 manager_ActionQueue.ProcessQueue();//全部入列完毕后调用第一次
//             }
//             //群体集火骰子
//             if (gw_dice.Effect == EffectType.Group_Focus)
//             {
//                 Debug.Log("群体集火骰子");
//                 //群体恢复1点法力值，对制定目标进行一次正常攻击
//                 int addMagic = 1;
//                 foreach (GameObject gwCard in gwAllCard)
//                 {
//                     manager_ActionQueue.EnqueueAction_FocusAttack(gwCard, _gwCard, gw_dice.Effect, addMagic);
//                 }
//                 manager_ActionQueue.ProcessQueue();//全部入列完毕后调用第一次
//             }
//             //群体恢复骰子
//             if (gw_dice.Effect == EffectType.Group_Recover)
//             {
//                 Debug.Log("群体恢复骰子");
//                 //群体恢复2点法力值，和20%最大生命值
//                 int addMagic = 2;
//                 float addHealth_Ratio = 0.2f;
//                 foreach (GameObject gwCard in gwAllCard)
//                 {
//                     manager_ActionQueue.EnqueueAction_Recover(gwCard, gw_dice.Effect, addMagic, addHealth_Ratio);
//                 }
//                 manager_ActionQueue.ProcessQueue();//全部入列完毕后调用第一次
//             }
//         }
//     }
// }
