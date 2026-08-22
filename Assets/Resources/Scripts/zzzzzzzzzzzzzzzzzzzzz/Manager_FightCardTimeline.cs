using System.Collections;
using System.Collections.Generic;
using System.Linq;
using DG.Tweening;
using UnityEngine;
using UnityEngine.UI;

public class Manager_FightCardTimeline : MonoBehaviour
{
    //自身属性
    private float totalLength;//总长度
    private Vector2 originPos;//起始位置
    private Sequence battleSequence;//保存当前卡执行动画
    public GameObject originPosFlag;
    //Timeline参数
    public GameObject tlCardPrefab;//Timeline卡牌预制体
    private List<GameObject> allTimelineCards;//TL卡牌列表
    //======逻辑控制======//
    private bool isRound_Begin = false;//管理开始运行
    private bool isExternalBreak = false;//外部中断总控
    //小开关
    public bool isRound_Feedback = false;//管理反馈动画
    public bool isRound_Attack = false;//管理攻击动画中断
    public bool isRound_Skilling = false;//管理技能释放打断
    public bool isRound_Action = false;//管理卡牌执行动作的中断
    // public Init_FightingCard init_FightingCard;//初始化的脚本
    //======同步动画序列======//
    public Sequence _syncTweens;
    //======动画持续时间======//
    private const float MOVE_DURATION = 0.5f;//移动动画持续时间
    void Start()
    {
        InitManger();
        //InitTimelineCard();
        //InitBattleSequence();
    }

    // Update is called once per frame
    void Update()
    {
        if(isRound_Begin && !isExternalBreak)
        {
            isRound_Begin = false;//制约
            _syncTweens = DOTween.Sequence(); //新建序列
            //StartCoroutine(MoveRoutine());
            Debug.Log("触发完毕");
        }
    }

    //======初始化管理器======//
    void InitManger()
    {
        //获取宽度以及总长度 
        totalLength = GetComponent<RectTransform>().rect.width;
        Debug.Log(totalLength);
        Debug.Log(transform.position.x);
        //设定起始世界坐标
        originPos = originPosFlag.transform.position;
        //获取TL卡
        //allTimelineCards = init_FightingCard.tlAllCard;
    }
    //======初始化TL卡配置======//
    void InitTimelineCard()
    {
        //修改Timeline卡父对象为对战条
        foreach(GameObject tlCard in allTimelineCards)
        {
            tlCard.transform.SetParent(transform);
            //修改位置
            tlCard.transform.position = originPos;
            //记录位置
            tlCard.GetComponent<FightCardTimeline_UIManager>().originPos = originPos;
            //tlCard.SetActive(true);
        }
        Debug.Log(allTimelineCards.Count);
    }
    //====== 卡牌移动协程 ======//
    private IEnumerator MoveRoutine()
    {
        // 记录协程是否被外部终止
        bool isStopped = false;
        // 添加移动动画
        for(int i = 0;i < allTimelineCards.Count;i++)
        {
            // float card_Speed = allTimelineCards[i].GetComponent<FightCardTimeline_UIManager>().LinkedCard.GetComponent<C_Card>().speed;
            // Transform card_transfrom = allTimelineCards[i].transform;
            // _syncTweens.Join(card_transfrom.DOMoveX(card_transfrom.position.x + card_Speed * 100,MOVE_DURATION).SetEase(Ease.OutQuad));
        }
        // 添加 OnKill 回调
        _syncTweens.OnKill(() => isStopped = true);

        yield return _syncTweens.WaitForCompletion();//同步移动
        Debug.Log("执行完成");
        // 检查是否被终止
        if (isStopped)
        {
            Debug.Log("动画被强制终止，需处理残留状态");
            isRound_Begin = true;
            yield break; // 终止协程
        }

        // 正常后续逻辑...
    }
    //======外部启动开始运行命令======//
    public void BeginRunning()
    {
        if(isRound_Begin == false)
        {
            isRound_Begin = true;
            Debug.Log("TL系统开始运行!");
        }
    }

    //======外部中断动画方法======//
    public void BreakSequence()
    {
        if (_syncTweens != null && _syncTweens.IsActive())
        {
            _syncTweens.Kill(); // 终止动画
            _syncTweens = null;
        }
    }
    //======外部响应攻击以及反馈动画的方法======//
    public void AttackCompleted()
    {
        if(isRound_Attack == true)//攻击完成
        {
            isRound_Attack = false;
            BreakMainChannel();
        }
    }
    public void AttackExecuting()//执行攻击
    {
        if(isRound_Attack == false)
        {
            isRound_Attack = true;
            BreakMainChannel();
        }
    }
    public void FeedbackCompleted()//反馈完成
    {
        if(isRound_Feedback == true)
        {
            isRound_Feedback = false;
            BreakMainChannel();
        }
    }
    public void FeedbackExecuting()//执行反馈
    {
        if(isRound_Feedback == false)
        {
            isRound_Feedback = true;
            BreakMainChannel();
        }
    }
    //======外部响应技能释放动画方法======//
    public void SkillCompleted()//技能完成
    {
        if(isRound_Skilling == true)
        {
            isRound_Skilling = false;//释放完毕不在释放状态为false
            //后续可能将多个通道汇入一个总通道
            BreakMainChannel();
        }
    }
    public void SkillExecuting()//执行技能
    {
        if(isRound_Skilling == false)
        {
            isRound_Skilling = true;
            BreakMainChannel();
        }
    }
    //======外部调用卡牌执行动作的中断方法======//
    public void CardActionCompleted()//动作完成
    {
        if(isRound_Action == true)
        {
            isRound_Action = false;
            BreakMainChannel();
        }
    }
    public void CardActionExecuting()//执行动作
    {
        if(isRound_Action == false)
        {
            isRound_Action = true;
            BreakMainChannel();
        }
    }
    //======外部打断的总通道======//
    private void BreakMainChannel()
    {
        //每次一个外部打断恢复后在恢复方法里需要再次调用这个方法
        //并且需要维护响应的外部打断变量[「维护」所额外加的外部中断]
        if(!isRound_Attack && !isRound_Feedback && !isRound_Skilling && !isRound_Action)//所有外部中断恢复后才允许COUTINUE
        {
            isExternalBreak = false;
        }else
        {
            isExternalBreak = true;//继续打断允许
        }
    }
    // public void InitBattleSequence()
    // {
    //     Debug.Log("第一次"+battleSequence.IsActive());
    //     // 终止旧动画
    //     if (battleSequence != null && battleSequence.IsActive()) {
    //         battleSequence.Kill(true);
    //         battleSequence = null;  
    //         Debug.Log("第二次"+battleSequence.IsActive());
    //     }
    //     Debug.Log("进入序列");
    //     battleSequence = DOTween.Sequence();
    //     //按速度先排序
    //     // var sortedCards = allTimelineCards.OrderByDescending(c => c.GetComponent<FightCardTimeline_UIManager>().LinkedCard
    //     // .GetComponent<PlayerCard_UIManager>().card_Speed);//利用Linq的排序算法

    //     // foreach(GameObject tlCard in allTimelineCards)//对每个卡牌逐一操作[回合制]
    //     // {
    //     //     GameObject currentCard = tlCard; 
    //     //     //先计算当前卡牌要移动的位置
    //     //     /float current_Speed = currentCard.GetComponent<FightCardTimeline_UIManager>().LinkedCard.GetComponent<PlayerCard_UIManager>().card_Speed;
    //     //     //float moveLength = current_Speed;
    //     //     Vector2 move_Target = new Vector2(currentCard.transform.position.x + current_Speed* 25f,currentCard.transform.position.y);
    //     //     //移动阶段
    //     //     battleSequence.Append(currentCard.transform.DOMove(move_Target,0.7f).SetEase(Ease.OutQuad));
    //     //     //计算与初始位置距离
    //     //     float distance = Vector2.Distance(originPos,move_Target);
    //     //     if (distance >= totalLength / 2 && distance < totalLength
    //     //     && currentCard.GetComponent<FightCardTimeline_UIManager>().isAttack == false
    //     //     && currentCard.GetComponent<FightCardTimeline_UIManager>().numAttack == 0)//触发攻击命令
    //     //     {
    //     //         //记录攻击次数上限
    //     //         currentCard.GetComponent<FightCardTimeline_UIManager>().isAttack = true;
    //     //         //
    //     //     }
    //     //     else if(distance >= totalLength)//执行技能命令
    //     //     {
    //     //         currentCard.GetComponent<FightCardTimeline_UIManager>().isSkill = true;
    //     //         //记录重置位置信息
    //     //         currentCard.GetComponent<FightCardTimeline_UIManager>().isReset = true;
    //     //     }

    //     //     //检测攻击命令
    //     //     if(currentCard.GetComponent<FightCardTimeline_UIManager>().isAttack == true)
    //     //     {
    //     //         currentCard.GetComponent<FightCardTimeline_UIManager>().isAttack = false;
    //     //         currentCard.GetComponent<FightCardTimeline_UIManager>().numAttack = 1 ;
    //     //         //执行攻击指令
    //     //         battleSequence.Append(currentCard.GetComponent<FightCardTimeline_UIManager>().LinkedCardToAttack());
    //     //     }
    //     //     //如果超过总长度重置位置
    //     //     if(currentCard.GetComponent<FightCardTimeline_UIManager>().isReset == true)
    //     //     {
    //     //         battleSequence.Append(currentCard.GetComponent<Image>().DOFade(0,0.1f));
    //     //         battleSequence.Append(currentCard.transform.DOMove(originPos, 1.0f)).SetEase(Ease.OutQuad);

    //     //         battleSequence.AppendCallback(()=>{
    //     //             currentCard.GetComponent<FightCardTimeline_UIManager>().isReset = false;
    //     //             currentCard.GetComponent<FightCardTimeline_UIManager>().isSkill = false;
    //     //             currentCard.GetComponent<FightCardTimeline_UIManager>().isAttack = false;
    //     //             currentCard.GetComponent<FightCardTimeline_UIManager>().numAttack = 0;});
    //     //         battleSequence.Append(currentCard.GetComponent<Image>().DOFade(1,0.1f));
    //     //     }//还有小问题
    //     // }
    //     battleSequence.OnComplete(() =>
    //     {
    //         Debug.Log("本轮结束");
    //         //InitBattleSequence(); // 递归调用，开始新一轮 //递归循环外部调用接口获取序列并终止
    //     }).Play();

    // }
}
