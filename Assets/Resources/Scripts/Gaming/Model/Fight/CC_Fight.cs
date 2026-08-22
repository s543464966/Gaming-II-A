using System.Collections;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using DG.Tweening;
using UnityEngine;
using UnityEngine.UI;

public class CC_Fight : MonoBehaviour
{
    // --- 内部状态 --- (流程调度与动画缓存)
    private GameData GameData => DBCC_DataBase.Instance.GameData; // GameData别名单例提取
    private CC_Conflict CC_Conflict; // 关卡管理器
    private Queue<GameObject> attackQueue = new Queue<GameObject>(); // 总队列
    [HideInInspector] public List<GameObject> fightingHeroObjList; // 玩家出战卡牌
    [HideInInspector] public List<GameObject> fightingMonsterObjList; // 怪物出战卡牌
    [HideInInspector] public List<GameObject> heroDiceObjList; // 玩家所有骰子
    [HideInInspector] public List<GameObject> monsterDiceObjList; // 怪物所有骰子
    private List<Vector2> monsterPosVectorList = new List<Vector2>();
    private List<Vector2> heroPosVectorList = new List<Vector2>();
    private bool isProcessing = false; // 判断队列是否在执行当前任务
    private List<GameObject> monsterIntentionObjList = new List<GameObject>(); // 骰子实体对象
    private const float MOVE_DURATION = 0.5f; // 交换动画持续时间
    private const float FADE_DURATION = 0.5f; // 消淡动画持续时间
    private Dictionary<int, List<Vector2>> PreDiceAnchoredPos_Dic = new Dictionary<int, List<Vector2>>(); // 多个意图骰子作用在同个卡牌上的相对位置
    [HideInInspector] public bool isAutoPlay; // 是否自动化
    public bool isHeroAction = false; // 判断当前回合是玩家还是怪物
    private int actionDiceNum = 0; // 玩家或者怪物一方此时使用过的骰子数
    private int currentDiceFace; // 自动化执行的玩家骰子数量
    [HideInInspector] public List<GameObject> currentDiceObjList; // 当前执行的骰子列表
    [HideInInspector] public List<GameObject> currentFightingObjList; // 当前执行的卡牌列表
    enum FightingState { Idle, Single, Group, Queue } // 战斗状态
    private FightingState currentFightingState = FightingState.Idle; // 当前队列执行状态
    private int fightingNum = 0; // 队列执行数量

    [Header("模块: 基础UI与预设体引用")]
    [Tooltip("骰子预制体")] public GameObject dice_Prefab;
    [Tooltip("玩家出战容器")] public GameObject heroFightingArea;
    [Tooltip("怪物出战容器")] public GameObject monsterFightingArea;
    [Tooltip("意图骰子缩小倍率")] public float reduceScaleRate;

    [Header("模块: 战斗组件关联")]
    [Tooltip("骰子核心管理器")][HideInInspector] public Fight_Dice Fight_Dice;

    // ==========================================
    // 1. 初始化分配 (Initial)
    // ==========================================

    /// <summary>
    /// 【核心】计算骰子预设停靠位置
    /// 负责: 根据卡牌尺寸和骰子数量，计算并记录不同排列情况下的骰子相对坐标位置
    /// </summary>
    /// <param name="_cardPrefab">供测算的卡牌实体样板</param>
    /// <param name="_currentLevel">包含怪物骰池上限的现行关卡据</param>
    public void Init_DiceAnchoredPosition(GameObject _cardPrefab, Level _currentLevel)
    {
        //预备骰子相对位置数据
        int gwDiceMax = _currentLevel.monsterDiceList.Count;  //获取怪物骰子上限(待修改)逻辑获取上限
        Debug.Log("怪物骰子上限：" + gwDiceMax);
        float diceHeight = dice_Prefab.GetComponent<RectTransform>().rect.width;   //获取高度
        float diceReduceRate = reduceScaleRate;  //缩小倍率
        diceHeight = diceHeight * diceReduceRate;   //应用缩小后的高度
        float anchoredX = _cardPrefab.GetComponent<RectTransform>().rect.width / 2;
        for (int count = 1; count <= gwDiceMax; count++) //多少个骰子
        {
            List<Vector2> anchoredPos_List = new List<Vector2>();
            //  计算每种情况
            if (count % 2 == 1)// 奇数
            {
                // n = 3 -> idx: 1,0,-1 -> x = idx * slotWidth => w, 0, -w
                int half = count / 2;
                for (int i = 0; i < count; i++)
                {
                    int idx = i - half;
                    float anchoredY = -idx * diceHeight; // 注意负号
                    Vector2 anchoredPos = new Vector2(anchoredX, anchoredY);
                    anchoredPos_List.Add(anchoredPos);
                }
                //  添加进预备表里
                PreDiceAnchoredPos_Dic.Add(count, anchoredPos_List);
            }
            else    //偶数
            {
                // n = 2 -> idx: -1,0 -> x = -(idx + 0.5) * slotWidth => 0.5w, -0.5w
                int half = count / 2;
                for (int i = 0; i < count; i++)
                {
                    int idx = i - half;
                    float anchoredY = -(idx + 0.5f) * diceHeight; // 注意负号
                    Vector2 anchoredPos = new Vector2(anchoredX, anchoredY);
                    anchoredPos_List.Add(anchoredPos);
                }
                //  添加进预备表里
                PreDiceAnchoredPos_Dic.Add(count, anchoredPos_List);
            }
        }
    }

    /// <summary>
    /// 初始化战斗对局卡牌数据
    /// 负责: 接收并记录参战的双方卡牌列表与位置信息，预加载自动战斗设定
    /// </summary>
    /// <param name="_fightingHeroObjList">已入场选定我方实体花名册</param>
    /// <param name="_fightingMonsterObjList">已入场选定敌方实体花名册</param>
    /// <param name="_CC_Conflict">关卡中央管理桥接映射</param>
    /// <param name="_monsterPosVectorList">敌区坑位相对坐标阵</param>
    /// <param name="_heroPosVectorList">我区坑位相对坐标阵</param>
    public void Init_Fighting(List<GameObject> _fightingHeroObjList, List<GameObject> _fightingMonsterObjList, CC_Conflict _CC_Conflict, List<Vector2> _monsterPosVectorList, List<Vector2> _heroPosVectorList)
    {
        //获取必要数据及组件
        fightingHeroObjList = _fightingHeroObjList;
        fightingMonsterObjList = _fightingMonsterObjList;
        CC_Conflict = _CC_Conflict;
        monsterPosVectorList = _monsterPosVectorList;
        heroPosVectorList = _heroPosVectorList;

        //获取玩家手动或自动队长状态设置
        isAutoPlay = DBCC_DataBase.Instance.GameData.Sys_User.isAutoPlay;
    }

    /// <summary>
    /// 重置战斗回合相关的缓存数据
    /// 负责: 清除本关特定的骰子挂靠位置缓存，并重置骰子使用计数器
    /// </summary>
    public void Reset_CC_Fight()
    {
        //  切换关卡清空一次
        PreDiceAnchoredPos_Dic.Clear();
        actionDiceNum = 0;  //重置使用骰子数
    }
    //----------------------------------------------------------------------------------------------------------
    //模块：Update - 更新

    //更新当前回合的骰子数据
    public void Update_DiceData(List<GameObject> _heroDiceObjList, List<GameObject> _monsterDiceObjList)
    {
        heroDiceObjList = _heroDiceObjList;
        monsterDiceObjList = _monsterDiceObjList;
    }

    // public void Update_DiceData(List<GameObject> _heroDiceObjList, List<GameObject> _monsterDiceObjList)
    // {
    //     heroDiceObjList = _heroDiceObjList;
    //     monsterDiceObjList = _monsterDiceObjList;
    // }


    //----------------------------------------------------------------------------------------------------------
    //模块: Playbook

    //开始新回合
    public void Playbook_Action_NewRound()
    {
        //随机双方骰子并获取骰子数据
        Fight_Dice.Dice_RandomFace(heroDiceObjList);
        Fight_Dice.Dice_RandomFace(monsterDiceObjList);

        //初始化起始先手方数据
        currentDiceObjList = heroDiceObjList;
        currentFightingObjList = fightingHeroObjList;

        //重置双方的卡牌及骰子的必要数据
        ResetState_Playbook(fightingMonsterObjList, monsterDiceObjList);
        ResetState_Playbook(fightingHeroObjList, heroDiceObjList);

        //随机完毕后，将玩家的骰子从发牌区发到对应占位符位置后
        Sequence moveHeroDiceSeq = Fight_Dice.Move_BlankPlace_HeroDice();

        //随机动画结束后调用Show_DiceIntention()方法
        moveHeroDiceSeq.OnComplete(() =>
            //将怪物意图展现出来
            Show_MonsterDiceIntention_Playbook()
        );
    }

    //清空出战卡牌被分配到骰子的对象列表
    void ResetState_Playbook(List<GameObject> _fightingCardObjList, List<GameObject> _fightingDiceList)
    {
        //清洗每个卡牌
        foreach (GameObject _fightingCardObj in _fightingCardObjList)
        {
            // 将传入的对战实例的被分配骰子列表清空
            _fightingCardObj.GetComponent<C_FightCard>().diceIntentionObjList.Clear();
        }
        //清洗每个骰子
        foreach (GameObject _fightingDice in _fightingDiceList)
        {
            //清空意图列表
            _fightingDice.GetComponent<C_FightDice>().IntentionCardObjList.Clear();
            _fightingDice.GetComponent<C_FightDice>().isUsed = false;
        }
    }

    //展示怪物意图
    void Show_MonsterDiceIntention_Playbook()
    {
        //（待改进）骰子意图需要加上玩家骰子的意图，玩家的骰子意图不需要移动，只要存储目标即可，这个是因为要给玩家骰子自动化做数据准备

        // 进行UI展示意图
        Sequence monsterIntentionSeq = DOTween.Sequence();

        float fadeSpacing = 1.0f / monsterDiceObjList.Count; //控制透明度，来暗示执行的先后顺序

        for (int i = 0; i < monsterDiceObjList.Count; i++)
        {
            //找到一个意图对象
            GameObject monsterDiceObj = monsterDiceObjList[i]; //一个一个执行怪物骰子
            monsterDiceObj.GetComponent<C_FightDice>().Intention_Auto_FindList(); //寻找意图列表

            //为每个骰子设定透明度
            float targetFade = Mathf.Clamp01(1.0f - i * fadeSpacing); //透明度比率
            monsterDiceObj.GetComponent<C_FightDice>().preIntentionFadeRate = targetFade; //保存透明度数据
            GameObject preIntentionCard = monsterDiceObjList[i].GetComponent<C_FightDice>().IntentionCardObjList[0];  //获取骰子要作用的意图对象卡牌
            List<GameObject> preDiceObjList = preIntentionCard.GetComponent<C_FightCard>().diceIntentionObjList; //获取该卡牌被分配的骰子

            //如果多个骰子分配给同一个卡牌，则他们需要重新分配位置并执行换位动画
            Sequence midMonsterIntentionSeq = DOTween.Sequence();
            List<Vector2> Pos = PreDiceAnchoredPos_Dic[preDiceObjList.Count];   //获取提前计算好的相对位置
            for (int j = 0; j < preDiceObjList.Count; j++)
            {
                Vector3 worldPos = preIntentionCard.GetComponent<RectTransform>().TransformPoint(Pos[j]); //将意图卡牌上的相对坐标转世界坐标
                Tween _moveTween = preDiceObjList[j].transform.DOMove(worldPos, MOVE_DURATION)
                    .SetEase(Ease.OutQuad);
                midMonsterIntentionSeq.Join(_moveTween);
                //判断是否为被分配的那个骰子，如果是则加入fade和reduce动画
                if (monsterDiceObj == preDiceObjList[j])
                {
                    Tween _fadeTween = preDiceObjList[j].GetComponent<Image>().DOFade(targetFade, FADE_DURATION)
                        .SetEase(Ease.OutQuad);
                    midMonsterIntentionSeq.Join(_fadeTween);
                    Tween _reduceScaleTween = preDiceObjList[j].transform.DOScale(reduceScaleRate, MOVE_DURATION)
                        .SetEase(Ease.OutQuad);
                    midMonsterIntentionSeq.Join(_reduceScaleTween);
                }
            }
            monsterIntentionSeq.Append(midMonsterIntentionSeq);
            monsterDiceObj.GetComponent<Image>().raycastTarget = false; //取消被光线检测
        }

        //  展示玩家骰子
        monsterIntentionSeq.OnComplete(() =>
        {
            Debug.Log("怪物意图展示完毕");
            isHeroAction = true;
            ContinueRound_Playbook(); //通知下一步动作
        });
    }

    void ContinueRound_Playbook() //让玩家操控或自动化操控玩家骰子，加入队列并执行
    {
        //首先判断双方起始回合，看谁先行动
        if (isAutoPlay == false && isHeroAction == true)  //玩家操控和玩家回合，通过玩家操控+玩家回合来开启玩家权限
        {
            //需要有一个弱提示，告诉玩家他可以操作骰子了（待改进）
            //一个UI提示    
            return;
        }
        else //自动化操控
        {
            //自动化操控，直接将玩家骰子加入队列
            //获取骰子列表，并按照顺序，一个一个执行，如果执行过还需要将其隐藏
            Debug.Log("查看执行骰子情况：" + currentDiceObjList.Count + "，第一个骰子的名字：" + currentDiceObjList[0]);
            for (int i = 0; i < currentDiceObjList.Count; i++)
            {
                if (currentDiceObjList[i].GetComponent<C_FightDice>().isUsed == true) continue; //如果骰子被使用过则跳过
                //获取当前执行的骰子
                GameObject currentDice = currentDiceObjList[i];
                currentDice.GetComponent<C_FightDice>().Intention_Auto_FindList(); //寻找意图列表

                //(待改进)需要一个骰子自动移动的动画，用来表示当前被选中的骰子，进行触发。
                //IntentionObjList是骰子对应的卡牌列表，谁用那个骰子，对应关系，Monster是通过意图来分配。单体还是群体，都是通过意图来分配
                //去自己的卡牌，去群体的卡牌，集火敌方。集体
                //通过骰子的面值，来判断骰子的效果，从而选定移动动画的种类，Auto动画。

                Debug.Log("可用骰子名字：" + currentDice.name);
                break;  //从头往后找到没使用的骰子就跳出循环
            }
        }
    }
    //去调用可以执行骰子效果方法的方法
    public void Dice_SingleFightIntention_Playbook(GameObject _checkDice, GameObject _currentFightingCardObj) //单体
    {
        //同步fightingNum的数量
        fightingNum = 1;
        _checkDice.GetComponent<C_FightDice>().isUsed = true; //标记为使用过
        currentFightingState = FightingState.Single;
        //  判断要执行的对象是否已经被击杀destroy了(现在只有单体后续可能需要添加其他的)
        if (_currentFightingCardObj == null)
        {
            HandleActionCompleted(null);
        }
        else
        {
            Fight_Dice.Dice_Reset(_checkDice); //重置骰子位置
            C_FightCard C_FightCard = _currentFightingCardObj.GetComponent<C_FightCard>();
            C_FightCard.OnActionCompleted -= HandleActionCompleted;
            C_FightCard.OnActionCompleted += HandleActionCompleted;
            Debug.Log(_checkDice.GetComponent<C_FightDice>().diceCurrentFace + " " + _currentFightingCardObj.name);
            _currentFightingCardObj.GetComponent<C_FightCard>().Perform_Dice_Action(_checkDice.GetComponent<C_FightDice>().diceCurrentFace);
        }
    }

    public void Dice_Auto_GroupFightIntention_Playbook(GameObject _checkDice, List<GameObject> _currentFightingObjList) //群体
    {
        //同步fightingNum的数量
        fightingNum = _currentFightingObjList.Count;
        _checkDice.GetComponent<C_FightDice>().isUsed = true; //标记为使用过
        Fight_Dice.Dice_Reset(_checkDice); //重置骰子位置
        currentFightingState = FightingState.Group;
        foreach (GameObject _currentFightingObj in _currentFightingObjList)
        {
            C_FightCard C_FightCard = _currentFightingObj.GetComponent<C_FightCard>();
            C_FightCard.OnActionCompleted -= HandleActionCompleted;
            C_FightCard.OnActionCompleted += HandleActionCompleted;
            _currentFightingObj.GetComponent<C_FightCard>().Perform_Dice_Action(_checkDice.GetComponent<C_FightDice>().diceCurrentFace);
        }
    }

    public void Dice_Auto_FightProcessQueue_Playbook(GameObject _checkDice, List<GameObject> _currentFightingObjList) //队列
    {
        //同步fightingNum的数量
        fightingNum = _currentFightingObjList.Count;
        currentFightingState = FightingState.Queue;
        //将当前骰子对应的卡牌加入队列
        for (int j = 0; j < _currentFightingObjList.Count; j++)
        {
            GameObject checkCard = _currentFightingObjList[j]; //获取当前骰子对应的卡牌
            attackQueue.Enqueue(checkCard); //Enqueue是队列的入列
                                            // currentCard = attackQueue.Dequeue();
        }

        //更新一下checkDiceList的状态，避免下次因自动化而被使用
        _checkDice.GetComponent<C_FightDice>().isUsed = true; //标记为使用过
        Fight_Dice.Dice_Reset(_checkDice); //重置骰子位置

        //将加入队列的卡牌按照顺序逐个执行
        if (attackQueue.Count > 0)
        {
            ProcessQueue_Playbook(); //出列
        }
    }
    void ProcessQueue_Playbook() //出列
    {
        //所要行动的卡牌出列
        GameObject attackCard = attackQueue.Dequeue();

        //为执行卡牌注册“动作执行完成”事件
        C_FightCard C_FightCard = attackCard.GetComponent<C_FightCard>();
        // C_Fight.OnActionCompleted += HandleActionCompleted;

        //先确保“动作执行完成”事件没有重复订阅（防止多次订阅同一处理器）
        C_FightCard.OnActionCompleted -= HandleActionCompleted;
        C_FightCard.OnActionCompleted += HandleActionCompleted;

        attackCard.GetComponent<C_FightCard>().Perform_Dice_Action(currentDiceFace); //执行卡牌动作
    }

    //
    void HandleActionCompleted(C_FightCard _C_FightCard)
    {
        //取消订阅，避免重复调用
        if (_C_FightCard != null) _C_FightCard.OnActionCompleted -= HandleActionCompleted;
        //  若没有则是被击杀直接过怪物对该骰子的使用
        int starttemp = fightingNum - 1;
        if (starttemp < fightingNum)
        {
            fightingNum--;
            if (fightingNum == 0)
            {
                actionDiceNum++; //更新已使用骰子数量
                NewOrContinue_Playbook(); //更新当前回合数据
                return;
            }

            if (currentFightingState == FightingState.Group) { return; }

            isProcessing = false;
            ProcessQueue_Playbook(); // 继续处理下一卡牌
        }
    }

    //
    void NewOrContinue_Playbook()
    {
        if (isHeroAction) //玩家回合
        {
            // 如果此时怪物数量为0，则直接结束回合
            if (fightingMonsterObjList.Count == 0)
            {
                Debug.Log("怪物已全部击败,结束回合");
                return;
            }
            //如果所有的玩家骰子都被使用过了，则重置
            if (actionDiceNum >= heroDiceObjList.Count)
            {
                //更新下回合数据
                actionDiceNum = 0; //重置
                isHeroAction = false; //切换为怪物回合

                //更新List数据 
                currentDiceObjList = monsterDiceObjList;
                currentFightingObjList = fightingMonsterObjList;

                Debug.Log("换边，进入怪物回合");
                ContinueRound_Playbook(); //进入怪物回合
                return;
            }
            else
            {
                Debug.Log("继续玩家回合");
                ContinueRound_Playbook(); //继续玩家回合
                return;
            }
        }
        else //怪物回合
        {
            // 如果此时玩家卡牌数量为0，则直接结束回合
            if (fightingHeroObjList.Count == 0)
            {
                Debug.Log("玩家卡牌已全部击败,结束回合");
                return;
            }
            //如果所有的玩家骰子都被使用过了，则重置
            if (actionDiceNum >= monsterDiceObjList.Count)
            {
                actionDiceNum = 0; //重置

                Debug.Log("进入新回合");
                Playbook_Action_NewRound(); //重新开始新一轮的骰子分配
                return;
            }
            else
            {
                Debug.Log("继续怪物回合");
                ContinueRound_Playbook(); //继续怪物回合
                return;
            }
        }
    }


    public void SafeDestroy(GameObject _deadCardObj)//魔法条的list也要销毁
    {
        if (CC_Conflict != null && CC_Conflict.Conflict_RuntimeBoard != null)
        {
            CC_Conflict.Conflict_RuntimeBoard.Remove_DeadRuntimeObjectSafe(_deadCardObj, Fight_Dice);
        }

        //判断剧幕是否结束
        if (CC_Conflict != null && CC_Conflict.Conflict_RuntimeBoard != null)
        {
            fightingMonsterObjList = CC_Conflict.Conflict_RuntimeBoard.FightingMonsterObjList;
            fightingHeroObjList = CC_Conflict.Conflict_RuntimeBoard.FightingHeroObjList;
        }

        if (fightingMonsterObjList.Count <= 0)
        {
            CC_Conflict.Result_Level_Victory();
        }
        else if (fightingHeroObjList.Count <= 0)
        {
            CC_Conflict.Result_Level_Defeat();
        }
    }

    //模块：外部调用，玩家操控

    //通知所有卡牌、区域更新触发：可选传入true，不可选传入false--->后期可以改成传入骰子 进行判断哪些卡牌可以被选择
    public void Notify_AllHeroCard_OptionalUI(bool isOptional)
    {
        if (isOptional == true)
        {
            //可选择卡牌执行动画
            foreach (GameObject heroCardObj in fightingHeroObjList)
            {
                heroCardObj.GetComponent<C_FightCard>().PlaySelectableUI();
            }
        }
        else
        {
            //不可选择卡牌取消光线检测
            foreach (GameObject heroCardObj in fightingHeroObjList)
            {
                heroCardObj.GetComponent<C_FightCard>().PlayUnselectableUI();
            }
        }
    }

    public void Notify_AllMonsterCard_OptionalUI(bool isOptional)
    {
        if (isOptional == true)
        {
            //可选择卡牌执行动画
            foreach (GameObject monsterCardObj in fightingMonsterObjList)
            {
                monsterCardObj.GetComponent<C_FightCard>().PlaySelectableUI();
            }
        }
        else
        {
            //不可选择卡牌取消光线检测
            foreach (GameObject monsterCardObj in fightingMonsterObjList)
            {
                monsterCardObj.GetComponent<C_FightCard>().PlayUnselectableUI();
            }
        }
    }
    //通知英雄区域UI执行动画
    public void Notify_AllHeroArea_OptionalUI(bool isOptional) //true=可选择，false=不可选择
    {
        if (isOptional == true)
        {
            //可选择区域执行动画
            heroFightingArea.GetComponent<Fight_CardArea>().PlaySelectableUI();
        }
        else
        {
            //不可选择区域取消光线检测
            heroFightingArea.GetComponent<Fight_CardArea>().PlayUnselectableUI(fightingHeroObjList);
        }
    }

    public void Notify_AllMonsterArea_OptionalUI(bool isOptional) //通知怪物区域UI执行动画
    {
        if (isOptional == true)
        {
            //可选择区域执行动画
            monsterFightingArea.GetComponent<Fight_CardArea>().PlaySelectableUI();
        }
        else
        {
            //不可选择区域取消光线检测
            monsterFightingArea.GetComponent<Fight_CardArea>().PlayUnselectableUI(fightingMonsterObjList);
        }
    }

    // 模块：Interaction



    //让怪物自动化操控怪物骰子，加入队列并执行
    //完成后，通知玩家和怪物，当前回合结束

    // public void AttackQueue_Enqueue(GameObject action_Card, Dice _diceType)
    // {
    //     //获取当前执行的卡牌和卡牌对应的骰子
    //     //入列
    //     attackQueue.Enqueue(action_Card); //Enqueue是队列的入列
    //     currentCard = attackQueue.Dequeue();
    // }


    //群体攻击的效果
    // public void EnqueueAction_Attack(GameObject action_Card, EffectType _effectType)
    // {
    //     //入列
    //     attackQueue.Enqueue(action_Card);   //Enqueue是队列的入列
    //     effectType = _effectType;
    // }

    //集火攻击的效果
    // public void EnqueueAction_FocusAttack(GameObject action_Card, GameObject _target, EffectType _effectType, int _addMagic_Focus)
    // {
    //     Debug.Log(action_Card.name);
    //     //入列
    //     attackQueue.Enqueue(action_Card);
    //     //保存参数
    //     effectType = _effectType;
    //     targetOBJ = _target;
    //     addMagic_Focus = _addMagic_Focus;
    // }
    //
    // public void EnqueueAction_Recover(GameObject action_Card, EffectType _effectType, int _addMagic_Recover, float _addHealth_Ratio)
    // {
    //     Debug.Log(action_Card.name);
    //     //入列
    //     attackQueue.Enqueue(action_Card);
    //     //保存参数
    //     effectType = _effectType;
    //     addMagic_Recover = _addMagic_Recover;
    //     addHealth_Ratio = _addHealth_Ratio;
    // }

    //队列应该全部入列后再进行处理






    //======骰子进行产生效果的动画协程======//
    // IEnumerator GwDiceUsedMove(GameObject _gwCard, GameObject _gwDice)
    // {
    //     //区分操作的目标卡牌是否还存在
    //     if (_gwCard == null)    //不存在
    //     {
    //         Sequence gwSeq = DOTween.Sequence();
    //         //让骰子回原位
    //         _moveTween = _gwDice.transform.DOMove(_gwDice.GetComponent<GwDice>().originPos, MOVE_DURATION / 2)
    //             .SetEase(Ease.OutQuad);
    //         _fadeTween = _gwDice.GetComponent<Image>().DOFade(0f, FADE_DURATION / 2)
    //             .SetEase(Ease.OutQuad);
    //         _reduceScaleTween = _gwDice.transform.DOScale(Vector3.one, MOVE_DURATION / 2)
    //         .SetEase(Ease.OutQuad);
    //         //顺序播放
    //         gwSeq.Append(_fadeTween);
    //         gwSeq.Join(_moveTween);
    //         gwSeq.Join(_reduceScaleTween);
    //         //等待动画执行完成
    //         yield return gwSeq.WaitForCompletion();
    //         //  手动触发回调
    //         CardActionCompleted();
    //     }
    //     else    //存在
    //     {
    //         //顺序动画
    //         Sequence gwSeq = DOTween.Sequence();
    //         Tween _fadeInTween = _gwDice.GetComponent<Image>().DOFade(1f, FADE_DURATION / 2)
    //             .SetEase(Ease.OutQuad);
    //         _moveTween = _gwDice.transform.DOMove(_gwCard.GetComponent<C_Fight>().originPos, MOVE_DURATION / 2)
    //             .SetEase(Ease.OutQuad);
    //         _fadeTween = _gwDice.GetComponent<Image>().DOFade(0f, FADE_DURATION / 2)
    //             .SetEase(Ease.OutQuad);
    //         //顺序播放
    //         gwSeq.Append(_fadeInTween);
    //         gwSeq.Join(_moveTween);
    //         gwSeq.Append(_fadeTween);
    //         //等待动画执行完成
    //         yield return gwSeq.WaitForCompletion();
    //         //修改显示效果
    //         CardAddCanvas();
    //         //将要操作的怪物卡牌放入要执行的骰子中
    //         _gwDice.GetComponent<GwDice>().UseDiceEffect(_gwCard);
    //         //让骰子回原位
    //         _moveTween = _gwDice.transform.DOMove(_gwDice.GetComponent<GwDice>().originPos, MOVE_DURATION / 2)
    //             .SetEase(Ease.OutQuad);
    //         _reduceScaleTween = _gwDice.transform.DOScale(Vector3.one, MOVE_DURATION / 2)
    //         .SetEase(Ease.OutQuad);
    //     }
    // }
    //======骰子意图存放相对位置======//[怪物使用]


    //======清除意图骰子的目标对象保存所分配的骰子======//

    // //======展示意图时骰子的canvas层级======//
    // private void DiceAddCanvas()
    // {
    //     foreach (GameObject gwDice in gwAllDices)
    //     {
    //         //给怪物骰子上canvas组件
    //         gwDice.AddComponent<Canvas>();
    //         gwDice.GetComponent<Canvas>().overrideSorting = true;
    //         gwDice.GetComponent<Canvas>().sortingOrder = 2;
    //     }
    // }
    // private void DiceRemoveCanvas()
    // {
    //     foreach (GameObject gwDice in gwAllDices)
    //     {
    //         gwDice.GetComponent<Image>().raycastTarget = true; //恢复被光线检测
    //         //给怪物骰子销毁canvas组件
    //         Canvas canvas = gwDice.GetComponent<Canvas>();
    //         if (canvas != null) Destroy(canvas);
    //     }
    // }

}
