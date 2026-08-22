using System.Collections;
using System.Collections.Generic;
using System.IO;
using DG.Tweening;
using UnityEngine;
using UnityEngine.UI;

public class Fight_Dice : MonoBehaviour
{
    [Header(" Initial - 初始化 ")]
    [Tooltip("卡牌层的光线检测器")] public GraphicRaycaster GraphicRaycaster;

    //======随机配置的参数======//
    // private int current_dice_ID = 0;
    // private int current_singleDice_NUM = 0;
    // private int current_groupDice_NUM = 0;
    // private bool isGwRound = false;//当前是怪物的回合
    // private GameObject randomTarget;//作用的随机对象
    //======动画参数======//
    // private Tween _moveTween;
    // private Tween _fadeTween;
    // private Tween _reduceScaleTween;

    //======当前使用的骰子索引======//
    // private int current_dice_Index = 0;
    //======骰子一些动画参数======//
    private const float MOVE_DURATION = 0.5f;//交换动画持续时间
    private const float FADE_DURATION = 0.5f;
    //======保留对方卡牌的区对象======//
    //[HideInInspector] public List<GameObject> gwAllCard;//怪物卡牌
    // public Manager_PlayerDice manager_PlayerDice;//玩家骰子管理器
    //======群体效果队列对象======//
    [HideInInspector] public CC_Fight CC_Fight;

    //====== 骰子 ======//
    [Header("玩家骰子发牌区域对象")] public GameObject heroContainer; //玩家骰子发牌位置
    [Header("怪物骰子发牌区域对象")] public GameObject monsterContainer; //怪物骰子发牌位置
    [Header("骰子预制体")] public GameObject dice_Prefab; //骰子预制体
    [Header("骰子占位符预制体")] public GameObject diceBlank_Prefab; //骰子占位符预制体
    [Tooltip("骰子间距倍数")] public float spacingMultiplier = 1.2f; //骰子间距倍数
    [Tooltip("Dice模块的CanvasGroup")] public CanvasGroup dice_CanvasGroup;
    private List<int> heroDiceBlankIndexList = new List<int>();  //玩家骰子白卡固定位置的索引
    [HideInInspector] public int heroDiceCount; //骰子占位符预制体
    [HideInInspector] public int monsterDiceCount; //骰子占位符预制体
    // SO_Dice[] SO_Dice_List; //所有骰子数据
    [HideInInspector] public List<Dice> heroDiceFightList; //玩家骰子类型列表
    [HideInInspector] public List<Dice> monsterFightDiceList; //怪物骰子类型列表
    [HideInInspector] public List<string> monsterSODiceList; //怪物骰子类型列表
    [HideInInspector] public List<GameObject> monsterDiceObjList = new List<GameObject>();  //怪物所有骰子
    [HideInInspector] public List<GameObject> monsterDiceBlankObjList = new List<GameObject>();   //怪物骰子占位符
    [HideInInspector] public List<GameObject> heroDiceObjList = new List<GameObject>();    //玩家所有骰子
    public List<GameObject> heroDiceBlankObjList = new List<GameObject>();    //玩家骰子占位符,提前预制好的
    //  随机算法核心生成器
    public System.Random shareRng = new System.Random();// 使用 Guid 的 HashCode 作为种子，确保极其混乱的随机熵，避免时间戳种子雷同

    // ----------------------------------------------------------------------------------------------------------    

    //模块：Initial - 初始化
    public void Init_Dice(List<Dice> _heroDiceFightList, int _heroDiceCount, List<string> _monsterSODiceList, int _monsterDiceCount)
    {
        //获取出战的骰子数据
        heroDiceCount = _heroDiceCount; //获取玩家骰子上限
        heroDiceFightList = _heroDiceFightList;   //获取玩家骰子种类列表

        //获取怪物的骰子数据
        monsterDiceCount = _monsterDiceCount; //获取怪物骰子上限
        monsterFightDiceList = Update_MonsterDice(_monsterDiceCount, _monsterSODiceList); //获取怪物骰子种类列表

        // //从项目文件中，获取所有的骰子SO_Dice; (待改进) 地址有误//待商榷
        // SO_Dice_List = Resources.LoadAll<SO_Dice>("ScriptableObject/Dice");

        //依据玩家骰子数，将骰子占位符实例出来
        // AutoChangeDicePlace(heroDiceCount, heroContainer, heroDiceBlankObjList);
        // AutoChangeDicePlace(monsterDiceCount, monsterContainer, monsterDiceBlankObjList);
        Update_HeroDiceBlankIndex(); //更新玩家骰子的白卡索引
        //  显示Dice模块，激活dice模块玩家骰子占位符
        Sequence showDice = Show_HeroBlankDice();
        showDice.OnComplete(() =>
        {
            //实例化所有骰子
            Dices_Instantiate(heroDiceObjList, heroDiceFightList, 0, heroContainer, heroDiceCount); //0代表玩家阵营
            Dices_Instantiate(monsterDiceObjList, monsterFightDiceList, 1, monsterContainer, monsterDiceCount); //1代表怪物阵营

            //将骰子完成更新，然后通知Fighting可以进行战斗了
            CC_Fight.Update_DiceData(heroDiceObjList, monsterDiceObjList); //更新战斗数据
            Debug.Log("激活完毕，开始战斗!");
            CC_Fight.Playbook_Action_NewRound(); //开始战斗
        });
    }
    //====== 初始化扩展方法 ======//

    //通过怪物的骰子类型字符串，获取对应的Dice数据
    private List<Dice> Update_MonsterDice(int _monsterDiceCount, List<string> _monsterSODiceList)
    {
        Dictionary<string, Dice> lockDiceDict = DBCC_DataBase.Instance.GameData.lockDiceDict;
        Dictionary<string, Dice> heroDiceDict = DBCC_DataBase.Instance.GameData.heroDiceDict;
        List<Dice> monsterDiceFaceList = new List<Dice>();

        for (int i = 0; i < _monsterDiceCount; i++)
        {
            foreach (var _lockDiceDict in lockDiceDict)
            {
                if (_lockDiceDict.Key == _monsterSODiceList[i])
                {
                    monsterDiceFaceList.Add(_lockDiceDict.Value); //加入骰子列表
                    continue;
                }
            }
            foreach (var _heroDiceDict in heroDiceDict)
            {
                if (_heroDiceDict.Key == _monsterSODiceList[i])
                {
                    monsterDiceFaceList.Add(_heroDiceDict.Value); //加入骰子列表
                    continue;
                }
            }
        }
        return monsterDiceFaceList;
    }
    void Update_HeroDiceBlankIndex()    //初始化固定的骰子占位符顺序索引
    {
        heroDiceBlankIndexList.Clear();
        for (int i = 0; i < heroDiceBlankObjList.Count; i++)
        {
            heroDiceBlankIndexList.Add(i);
        }
    }
    //实例化骰子占位符(待改进)占位符好像不需要了，怪物的只需要从一个地方类似发牌给意图，玩家的按目前规划是提前预制好的
    void AutoChangeDicePlace(int _diceCount, GameObject _container, List<GameObject> _diceBlankObjList)
    {
        RectTransform container = _container.transform as RectTransform;   //自身
        float itemWidth = diceBlank_Prefab.GetComponent<RectTransform>().rect.width;   //获取预制体宽度
        float slotWidth = itemWidth * spacingMultiplier; // <- 关键：每个格子的宽度（中心步进）
        int diceCount = _diceCount;   //获取玩家骰子上限
        // 奇数/偶数分别处理
        if (diceCount % 2 == 1)
        {
            // n = 3 -> idx: -1,0,1 -> x = idx * slotWidth => -w, 0, +w
            int half = diceCount / 2;
            for (int i = 0; i < diceCount; i++)
            {
                int idx = i - half;
                float anchoredX = idx * slotWidth;
                //  生成实例
                GameObject diceBlank = Instantiate(diceBlank_Prefab, container);
                RectTransform rt = diceBlank.GetComponent<RectTransform>(); //调整位置
                if (rt != null)
                {
                    // 保证缩放正常（防止预制体带奇怪缩放）
                    rt.localScale = Vector3.one;
                    rt.anchoredPosition = new Vector2(anchoredX, 0f);
                }
                _diceBlankObjList.Add(diceBlank.gameObject);
            }
        }
        else
        {
            // n = 2 -> idx: -1,0 -> x = (idx + 0.5) * slotWidth => -0.5w, +0.5w
            int half = diceCount / 2;
            for (int i = 0; i < diceCount; i++)
            {
                int idx = i - half;
                float anchoredX = (idx + 0.5f) * slotWidth;
                //  生成实例
                GameObject diceBlank = Instantiate(diceBlank_Prefab, container);
                RectTransform rt = diceBlank.GetComponent<RectTransform>(); //调整位置
                if (rt != null)
                {
                    // 保证缩放正常（防止预制体带奇怪缩放）
                    rt.localScale = Vector3.one;
                    rt.anchoredPosition = new Vector2(anchoredX, 0f);
                }
                _diceBlankObjList.Add(diceBlank.gameObject);
            }
        }
    }

    //实例化每个骰子(待改进)不管是怪物的还是玩家的，只需要生成在发牌位置就好(已修改)
    void Dices_Instantiate(List<GameObject> _fightDiceObjList, List<Dice> _fightDiceList, int _camp, GameObject _diceContainer, int _diceCount)
    {
        //根据骰子上限来实例化对应数量的骰子
        for (int i = 0; i < _diceCount; i++)
        {
            //分配父对象
            GameObject dice = Instantiate(dice_Prefab, _diceContainer.transform);

            //加入实例化骰子列表
            _fightDiceObjList.Add(dice);

            //赋予数据
            dice.GetComponent<C_FightDice>().init_Dice(_diceContainer.transform.position, _fightDiceList[i], _camp, CC_Fight);

            //判断是否分配玩家骰子，如果是需要额外挂载一个Dice_Interaction脚本
            if (_fightDiceList == heroDiceFightList)
            {

                dice.AddComponent<Dice_Interaction>(); //判断传入的骰子是否为玩家的出战骰子
                dice.GetComponent<Dice_Interaction>().Init_DiceInteraction(GraphicRaycaster, CC_Fight);
                // dice.GetComponent<Dice_Interaction>().CC_Fight = CC_Fight; //分配CC_Fight脚本引用
            }
        }
    }

    public void Dice_Reset(GameObject _checkDice)  //重置骰子使用位置
    {
        _checkDice.transform.position = _checkDice.GetComponent<C_FightDice>().dicePos; //重置位置
        _checkDice.transform.localScale = Vector3.one;  //重置缩放
        //重置透明度
    }

    //为实例化骰子分配并设定相关数据
    public void Dice_RandomFace(List<GameObject> _diceObjLists)
    {
        //(待改进)将一些数据在回合内添加并调用的需要重置
        //循环分配 + 动画后续分配确认好后再播放
        foreach (GameObject _diceObjList in _diceObjLists)
        {
            //随机骰子面值
            List<int> diceFaceList = _diceObjList.GetComponent<C_FightDice>().dice.SO_Dice.diceFaceList;

            // 获取随机索引
            int randomFace = shareRng.Next(0, diceFaceList.Count);
            _diceObjList.GetComponent<C_FightDice>().Update_Dice(randomFace); //更新骰子面值
        }
    }

    //  为玩家骰子从发牌位置移动到去占位符的位置
    private List<int> Random_HeroDiceIndex()
    {
        List<int> copyHeroDiceBlankIndexList = new List<int>(heroDiceBlankIndexList);   //复制一份
        List<int> randomHeroDiceIndexList = new List<int>();
        for (int i = 0; i < heroDiceObjList.Count; i++)
        {
            //  根据玩家骰子的个数，随机抽取对应个数的索引
            int random = Random.Range(0, copyHeroDiceBlankIndexList.Count);
            //  将随机出来的索引对应的值
            int randomValue = copyHeroDiceBlankIndexList[random];
            randomHeroDiceIndexList.Add(randomValue);
            //  抽取出来加进随机表后就移除
            copyHeroDiceBlankIndexList.RemoveAt(random);
        }
        return randomHeroDiceIndexList;
    }

    public Sequence Move_BlankPlace_HeroDice()  //(待改进)--->将骰子随机分配到对应位置(已修改)
    {
        List<int> randomHeroDiceIndexList = Random_HeroDiceIndex(); //获得利用随机算法生成的玩家骰子索引列表
        Sequence moveHeroDiceSeq = DOTween.Sequence();
        // 为玩家骰子添加移动动画
        for (int i = 0; i < heroDiceObjList.Count; i++)
        {
            int index = randomHeroDiceIndexList[i]; //获得随机表的值
            GameObject diceBlankObj = heroDiceBlankObjList[index];  //  根据索引获得对应骰子占位符的对象
            Vector2 startBlankPos = diceBlankObj.transform.position;    //获取起始占位符的位置
            Quaternion startBlankQuq = diceBlankObj.transform.rotation; //获取起始占位符的旋转角度
            heroDiceObjList[i].GetComponent<Dice_Interaction>().Update_DiceInBlankPos(startBlankPos, startBlankQuq); //  更新骰子在占位符的位置
            Tween moveTween = heroDiceObjList[i].transform.DOMove(startBlankPos, MOVE_DURATION).SetEase(Ease.OutQuad);
            Tween rotateTween = heroDiceObjList[i].transform.DORotateQuaternion(startBlankQuq, MOVE_DURATION).SetEase(Ease.OutQuad);
            Tween fadeTween = heroDiceObjList[i].GetComponent<Image>().DOFade(1, FADE_DURATION).SetEase(Ease.OutQuad);
            // 顺序执行 或同时执行
            moveHeroDiceSeq.Append(moveTween);
            moveHeroDiceSeq.Join(rotateTween);
            moveHeroDiceSeq.Join(fadeTween);
        }
        return moveHeroDiceSeq;
    }

    //  显示Dice模块，激活dice模块玩家骰子占位符
    private Sequence Show_HeroBlankDice()
    {
        //Dice模块显现
        dice_CanvasGroup.alpha = 0; //先设置透明度为0
        gameObject.SetActive(true);
        Sequence diceSeq = DOTween.Sequence();
        Tween dice_Fadein = dice_CanvasGroup.DOFade(1.0f, FADE_DURATION).SetEase(Ease.OutQuad);
        diceSeq.Append(dice_Fadein);
        return diceSeq;
    }

    //  隐藏Dice模块，激活dice模块玩家骰子占位符
    private void Hide_HeroBlankDice()
    {
        //Dice模块隐藏
        dice_CanvasGroup.alpha = 0; //先设置透明度为0
        gameObject.SetActive(false);
    }

    public void Reset_FightDice()    //重置FightDice模块里切换关卡后的临时数据
    {
        //关卡结束后删除玩家已有的骰子
        foreach (GameObject heroDiceObj in heroDiceObjList)//  遍历玩家骰子obj表删除并清空
        {
            Destroy(heroDiceObj);
        }
        heroDiceObjList.Clear();
        foreach (GameObject monsterDiceObj in monsterDiceObjList)
        {
            Destroy(monsterDiceObj);
        }
        monsterDiceObjList.Clear();
        //  隐藏骰子模块
        Hide_HeroBlankDice();
    }

    // public void ClearCardForRecordIntentionDice()
    // {
    //     if (dice_Data_TargetObj.Count == 0) return;
    //     for (int i = 0; i < dice_Data_TargetObj.Count; i++)
    //     {
    //         dice_Data_TargetObj[i].GetComponent<C_Fight>().PreDiceOBJ.Clear();    //对每个保存意图骰子的列表进行清空
    //         Debug.Log("卡牌:" + dice_Data_TargetObj[i].GetComponent<C_Fight>().card_SO.cardId + "保存列表数量为:" + dice_Data_TargetObj[i].GetComponent<C_Fight>().PreDiceOBJ.Count);
    //     }
    //     Debug.Log("所有包含意图骰子卡牌的保存列表都清空了");
    // }
    // //======清除意图骰子的目标对象保存所分配的骰子======//
    // private void Clear_ALLIntentionDice(GameObject _fightingCardObjLists)
    // {
    //     foreach (GameObject _fightingCardObjList in _fightingCardObjLists)
    //     {
    //         // Destroy(child.gameObject); //先清空残余子对象
    //         _fightingCardObjList.GetComponent<C_Fight>().PreDiceOBJ.Clear()
    //     }

    //     // for (int i = 0; i < dice_Data_TargetObj.Count; i++)
    //     // {
    //     //     dice_Data_TargetObj[i].GetComponent<C_Fight>().PreDiceOBJ.Clear();    //对每个保存意图骰子的列表进行清空
    //     //     Debug.Log("卡牌:" + dice_Data_TargetObj[i].GetComponent<C_Fight>().card_SO.cardId + "保存列表数量为:" + dice_Data_TargetObj[i].GetComponent<C_Fight>().PreDiceOBJ.Count);
    //     // }
    //     Debug.Log("所有包含意图骰子卡牌的保存列表都清空了");
    // }

    //调用方法
    // InstantiateHeroDices(_diceType);
    // //调整透明度为0
    // foreach (Transform child in transform)
    // {
    //     Color newColor = child.GetComponent<Image>().color;
    //     newColor.a = 0f;
    //     child.GetComponent<Image>().color = newColor;
    // }
    // }
    // {
    // foreach (Transform child in transform)
    // {
    //     Destroy(child.gameObject); //先清空残余子对象
    // }
    // AutoChangePlayerDicePlace(); //自动调整玩家骰子
    //依据怪物骰子数，将骰子实例出来
    //     for (int i = 0; i < dice_NUM; i++)
    //     {
    //         GameObject dice = Instantiate(dice_Prefab, gameObject.transform);//分配父对象
    //         playerAllDices.Add(dice);//加入骰子里
    //         dice.transform.position = blankDicePlaces[i].transform.position;//赋予位置
    //         dice.GetComponent<PlayerDice>().originPos = dice.transform.position;//同步初始位置
    //         dice.GetComponent<PlayerDice>().playerFightCard = playerFightCard;
    //         dice.GetComponent<PlayerDice>().manager_ActionQueue = manager_ActionQueue;  //分配群体效果队列管理器
    //         //分配脚本引用
    //         dice.GetComponent<C_PlayerDice>().manager_PlayerDice = gameObject.GetComponent<Manager_PlayerDice>();
    //     }
    //     //调整透明度为0
    //     foreach (Transform child in transform)
    //     {
    //         Color newColor = child.GetComponent<Image>().color;
    //         newColor.a = 0f;
    //         child.GetComponent<Image>().color = newColor;
    //     }
    // }
    //======初始化骰子======//
    // private void Init_Dice()
    // {
    //     //目前先利用占位符，到时要自行计算
    //     foreach (Transform child in transform)
    //     {
    //         blankDicePlaces.Add(child.gameObject);
    //     }

    //     //将实体骰子实例出来
    //     for (int i = 0; i < dice_NUM; i++)
    //     {
    //         GameObject dice = Instantiate(dice_Prefab, gameObject.transform);//分配父对象
    //         gwAllDices.Add(dice);//加入骰子里
    //         dice.transform.position = blankDicePlaces[i].transform.position;//赋予位置
    //         dice.GetComponent<GwDice>().originPos = dice.transform.position;//同步初始位置
    //         dice.GetComponent<GwDice>().gwAllCard = gwAllCard;
    //         // dice.GetComponent<GwDice>().Fight_Fighting = Fight_Fighting;  //分配群体效果队列管理器
    //     }
    //     //调整透明度为0
    //     foreach (Transform child in transform)
    //     {
    //         Color newColor = child.GetComponent<Image>().color;
    //         newColor.a = 0f;
    //         child.GetComponent<Image>().color = newColor;
    //     }
    // }
    //======随机分配======//

    //======可以分等级来调整AI的难易程度======//
    //======模拟人类使用骰子======//
    // public void GwUseDice()//最简单的
    // {
    //     Debug.Log("怪物执行使用骰子");
    //     //如果是最后一个执行完再调用
    //     if (current_dice_Index == gwAllDices.Count)
    //     {
    //         isGwRound = false;
    //         Debug.Log("怪物回合完毕，怪物先刷新骰子展示意图");
    //         //全部使用完毕后结束开启下一个「大回合」，调用怪物随机
    //         //manager_PlayerDice.RandomDice();
    //         RandomDice();
    //         return;
    //     }
    //     isGwRound = true;//为怪物回合
    //     GameObject gwDice = gwAllDices[current_dice_Index]; //一个一个执行
    //     //  顺序访问，拿取记录的释放目标数据
    //     randomTarget = dice_Data_TargetObj[current_dice_Index];
    //     if (randomTarget == null) Debug.Log("该释放目标被销毁为null,可能被击杀");
    //     DiceAddCanvas();//  所有怪物骰子层级增加
    //     //启动协程
    //     StartCoroutine(GwDiceUsedMove(randomTarget, gwDice));
    // }
    // //======展示怪物意图======//
    // private void DisplayIntention()
    // {
    //     Debug.Log("怪物展示意图");
    //     //怪物卡牌
    //     GameObject[] gwCards = GameObject.FindGameObjectsWithTag("GwCard");
    //     GameObject[] playerCards = GameObject.FindGameObjectsWithTag("PlayerCard");
    //     if (gwCards == null) return;
    //     //  清空骰子使用目标数据
    //     dice_Data_TargetObj.Clear();
    //     //  将骰子使用的意图数据分配
    //     for (int i = 0; i < gwAllDices.Count; i++)
    //     {
    //         GameObject gwDice = gwAllDices[i]; //一个一个执行
    //         //  根据随机分配后的骰子效果进行分配
    //         if (gwDice.GetComponent<GwDice>().gw_dice.Effect == EffectType.Group_Focus)//如果是集火从玩家那边选择目标
    //         {
    //             //  从玩家出战实例卡牌里随机拿取一个
    //             int random = Random.Range(0, playerCards.Length);
    //             // 记录数据
    //             dice_Data_TargetObj.Add(playerCards[random]);
    //             playerCards[random].GetComponent<C_Fight>().PreDiceOBJ.Add(gwDice);    //记录被分配的骰子对象
    //         }
    //         else
    //         {
    //             int random = Random.Range(0, gwCards.Length);
    //             // 记录数据
    //             dice_Data_TargetObj.Add(gwCards[random]);
    //             gwCards[random].GetComponent<C_Fight>().PreDiceOBJ.Add(gwDice);    //记录被分配的骰子对象
    //         }
    //     }
    //     AllDiceIntentionMovePosition(); //转换世界坐标并赋值
    //     // 进行UI展示意图
    //     Sequence intentionAllSeq = DOTween.Sequence();
    //     float fadeSpacing = 1.0f / gwAllDices.Count;    //透明度间隔
    //     for (int i = 0; i < gwAllDices.Count; i++)
    //     {
    //         GameObject gwDice = gwAllDices[i]; //一个一个执行
    //         float targetFade = Mathf.Clamp01(1.0f - i * fadeSpacing);
    //         gwDice.GetComponent<GwDice>().preIntentionFadeRate = targetFade;
    //         Vector3 targetPos = gwDice.GetComponent<GwDice>().preIntentionPos;
    //         gwDice.GetComponent<Image>().raycastTarget = false; //取消被光线检测
    //         intentionAllSeq.Append(GwDiceUseMove(targetPos, gwDice));
    //     }
    //     //  展示玩家骰子
    //     intentionAllSeq.OnComplete(() =>
    //     { 
    //         manager_PlayerDice.RandomDice();
    //     });
    // }
    // //======处理所有怪物骰子意图移动位置的终点======//
    // private void AllDiceIntentionMovePosition()
    // {
    //     for (int i = 0; i < dice_Data_TargetObj.Count; i++) //调用记录的目标使用卡牌[有重复的]
    //     {
    //         GameObject targetObj = dice_Data_TargetObj[i];  //目标卡牌
    //         List<GameObject> preDices = targetObj.GetComponent<C_Fight>().PreDiceOBJ; //要被分配的骰子
    //         List<Vector2> preDiceAnchoredPos = PreDiceAnchoredPos_Dic[preDices.Count];
    //         //  为每个被分配的骰子分配位置
    //         for (int j = 0; j < preDices.Count; j++)
    //         {
    //             Vector3 worldPos = targetObj.GetComponent<RectTransform>().TransformPoint(preDiceAnchoredPos[j]);   //将相对坐标转世界坐标
    //             Debug.Log("世界坐标为:" + worldPos);
    //             preDices[j].GetComponent<GwDice>().preIntentionPos = worldPos;
    //         }
    //     }
    // }
    // //======骰子移动的协程======//
    // private Sequence GwDiceUseMove(Vector3 _targetPos, GameObject _gwDice)
    // {
    //     float targetFade = _gwDice.GetComponent<GwDice>().preIntentionFadeRate;
    //     //顺序动画
    //     Sequence gwSeq = DOTween.Sequence();
    //     Tween _moveTween = _gwDice.transform.DOMove(_targetPos, MOVE_DURATION)
    //         .SetEase(Ease.OutQuad);
    //     Tween _fadeTween = _gwDice.GetComponent<Image>().DOFade(targetFade, FADE_DURATION)
    //         .SetEase(Ease.OutQuad);
    //     Tween _reduceScaleTween = _gwDice.transform.DOScale(reduceScaleRate, MOVE_DURATION)
    //         .SetEase(Ease.OutQuad);
    //     //顺序播放
    //     gwSeq.Append(_moveTween);
    //     gwSeq.Join(_reduceScaleTween);
    //     gwSeq.Append(_fadeTween);
    //     return gwSeq;
    // }
    // //======骰子进行产生效果的动画协程======//
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
    // //======骰子意图存放相对位置======//[怪物使用]
    // public void PreDiceAnchoredPosition(GameObject cardPrefab)
    // {
    //     //  利用怪物骰子上限来计算骰子在卡牌的相对位置
    //     int gwDiceMax = dice_NUM;
    //     Debug.Log("怪物骰子上限：" + gwDiceMax);
    //     float diceHeight = dice_Prefab.GetComponent<RectTransform>().rect.width;   //获取高度
    //     float diceReduceRate = reduceScaleRate;  //缩小倍率
    //     diceHeight = diceHeight * diceReduceRate;   //应用缩小后的高度
    //     float anchoredX = cardPrefab.GetComponent<RectTransform>().rect.width / 2;
    //     for (int count = 1; count <= gwDiceMax; count++) //多少个骰子
    //     {
    //         List<Vector2> anchoredPos_List = new List<Vector2>();
    //         //  计算每种情况
    //         if (count % 2 == 1)// 奇数
    //         {
    //             // n = 3 -> idx: 1,0,-1 -> x = idx * slotWidth => w, 0, -w
    //             int half = count / 2;
    //             for (int i = 0; i < count; i++)
    //             {
    //                 int idx = i - half;
    //                 float anchoredY = -idx * diceHeight; // 注意负号
    //                 Vector2 anchoredPos = new Vector2(anchoredX, anchoredY);
    //                 anchoredPos_List.Add(anchoredPos);
    //             }
    //             //  添加进预备表里
    //             PreDiceAnchoredPos_Dic.Add(count, anchoredPos_List);
    //         }
    //         else    //偶数
    //         {
    //             // n = 2 -> idx: -1,0 -> x = -(idx + 0.5) * slotWidth => 0.5w, -0.5w
    //             int half = count / 2;
    //             for (int i = 0; i < count; i++)
    //             {
    //                 int idx = i - half;
    //                 float anchoredY = -(idx + 0.5f) * diceHeight; // 注意负号
    //                 Vector2 anchoredPos = new Vector2(anchoredX, anchoredY);
    //                 anchoredPos_List.Add(anchoredPos);
    //             }
    //             //  添加进预备表里
    //             PreDiceAnchoredPos_Dic.Add(count, anchoredPos_List);
    //         }
    //     }
    // }
    // //======外部执行完动画回调======//
    // public void CardActionCompleted()
    // {
    //     if (isGwRound == true)
    //     {
    //         //顺序使用增加索引
    //         current_dice_Index++;
    //         //恢复显示效果，让骰子正常
    //         CardRemoveCanvas();
    //         Debug.Log("当前是怪物的回合,怪物使用了骰子：" + current_dice_Index);
    //         //再次模拟使用骰子
    //         GwUseDice();
    //     }
    // }

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
    // //======使用时调整卡牌的canvas层级======//
    // private void CardAddCanvas()
    // {
    //     foreach (GameObject gwCard in gwAllCard)
    //     {
    //         //给怪物卡牌上canvas组件
    //         gwCard.AddComponent<Canvas>();
    //         gwCard.GetComponent<Canvas>().overrideSorting = true;
    //         gwCard.GetComponent<Canvas>().sortingOrder = 0;
    //     }
    // }
    // private void CardRemoveCanvas()
    // {
    //     foreach(GameObject gwCard in gwAllCard)
    //     {
    //         //给怪物卡牌销毁canvas组件
    //         Canvas canvas = gwCard.GetComponent<Canvas>();
    //         if(canvas != null) Destroy(canvas);
    //     }
    // }
}

