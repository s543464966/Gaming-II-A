using System;
using System.Collections.Generic;
using System.Reflection;
using DG.Tweening;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

[RequireComponent(typeof(C_FightDamage))]
[RequireComponent(typeof(Image))]
[RequireComponent(typeof(RectTransform))]
public class C_FightCard : MonoBehaviour
{
    // --- 内部状态 --- (底层数据与逻辑缓存)
    [HideInInspector] public Card Card; // 卡牌核心数据体
    [HideInInspector] public CC_Fight CC_Fight; // 战斗管控中枢引用
    [HideInInspector] public Fight_Entry Fight_Entry; // 战斗词条核算处理器
    [HideInInspector] public Fight_Effect Fight_Effect; // 能力目标捕捉器
    [HideInInspector] public C_Ability_T C_Ability; // 战斗特技触发控制器
    [HideInInspector] public C_FightDamage C_FightDamage; // 伤害运算器桥接
    [HideInInspector] public List<int> talentHeroList; // 天赋特性记录表
    private float hpRatio; // 生命充实比例值
    private float dpRatio; // 护盾抵扣比例值
    private float hpBarWidth; // 拟态血量条基准宽幅
    private List<GameObject> manaPrefabList = new List<GameObject>(); // 魔力刻度实元列表
    public List<GameObject> PreDiceOBJ = new List<GameObject>(); // 预分配意图骰子队列
    [HideInInspector] public Manager_FightCardTimeline manager_FightCardTimeline; // 战术轴调度器
    [HideInInspector] public GameObject enemyParent; // 敌对阵列锚定根节点
    public List<GameObject> diceIntentionObjList = new List<GameObject>(); // 落定派发意图骰子列
    private Sequence blinkSequence; // 光影闪烁动效序列链
    private bool isMakeBlink_Selectable = false; // 可点状态激活锁标
    private bool isRayHide_Unselectable = false; // 射线遮拒隔离锁标
    public int posIndex; // 场域坑位注册序号
    [HideInInspector] public bool isDead; // 当前卡牌是否已进入死亡态
    private Sequence currentFeedbackTween = null; // 在播回馈动画流控列
    private float scaleBounce = 0.5f; // 受击震荡形变幅度
    public event Action<C_FightCard> OnActionCompleted; // 演武连步收束回传播报

    [Header("模块: UI节点与预制件关联")]
    [Tooltip("卡牌立绘呈像罩层")] public Image CardMain_Img;
    [Tooltip("品质边框修饰层")] public Image CardBorder_Img;
    [Tooltip("攻属流派刻印图")] public Image CardAttackBar_Img;
    [Tooltip("输出战力定额版")] public TMP_Text Atk_TMP;
    [Tooltip("生命全值总长轨底")] public RectTransform HPBar_Prefab;
    [Tooltip("当前生机标刻浮条")] public RectTransform HP_Prefab;
    [Tooltip("全合规生机存量版")] public TMP_Text HP_TMP;
    [Tooltip("外覆偏导装甲标刻条")] public RectTransform DP_Prefab;
    [Tooltip("法力结晶槽基底座")] public GameObject ManaBar_Prefab;
    [Tooltip("法力结晶刻度量模")] public GameObject Mana_Prefab;
    [Tooltip("整卡不透明度融混仪")] public CanvasGroup canvasGroup;

    [Header("模块: 物理系位与动画运筹")]
    [Tooltip("归属阵域标定初锚点")] public Vector2 posIndexVector;
    [Tooltip("纵身扑击耗时")] public float attack_duration;
    [Tooltip("硬直反馈耗时")] public float feedback_duration;
    [Tooltip("跌退硬直滑行长距")] public float fixedLength;

    // ==========================================
    // 1. 初始化构建 (Initialize)
    // ==========================================

    /// <summary>
    /// 初始化怪物战斗实体卡牌
    /// 负责: 1.记录世界坐标与管理器引用, 2.重置出战标签为怪物阵营, 3.初始化UI展现并计算导入承伤数据
    /// </summary>
    /// <param name="_SO_Card">塑形骨架用的源始静配卡据</param>
    /// <param name="_posIndexVector">保存相对锚点位置</param>
    /// <param name="_CC_Fight">战局大盘轮转枢纽</param>
    /// <param name="_Fight_Entry">时效附加词条调配器</param>
    /// <param name="_Fight_Effect">战吼与常驻范围辐射器</param>
    public void Init_FightingMonsterCard(SO_Card _SO_Card, Vector2 _posIndexVector, CC_Fight _CC_Fight, Fight_Entry _Fight_Entry, Fight_Effect _Fight_Effect)
    {
        Reset_RuntimeStateBeforeBind();

        //暂存Card数据，战斗词条控制器，战斗能力效果控制器
        posIndexVector = _posIndexVector;
        isDead = false;
        Card = null;
        CC_Fight = _CC_Fight;
        Fight_Entry = _Fight_Entry;
        Fight_Effect = _Fight_Effect;
        gameObject.tag = "Monster"; //修改卡牌的标签

        Init_UI_CardFigure(_SO_Card);

        //设置魔法条的Grid组件
        hpBarWidth = HPBar_Prefab.rect.width;

        //加载C_FightDamage-战斗伤害控制器，并初始化
        C_FightDamage = GetComponent<C_FightDamage>();
        C_FightDamage.Init_FightValue(_SO_Card, _Fight_Entry, GetComponent<C_FightCard>());
    }

    //初始化英雄卡牌
    public void Init_FightingHeroCard(Card _Card, Vector2 _posIndexVector, CC_Fight _CC_Fight, Fight_Entry _Fight_Entry, Fight_Effect _Fight_Effect)
    {
        Reset_RuntimeStateBeforeBind();

        //暂存Card数据，战斗词条控制器，战斗能力效果控制器
        posIndexVector = _posIndexVector;
        isDead = false;
        Card = _Card;
        posIndex = _Card.posIndex;
        CC_Fight = _CC_Fight;
        Fight_Entry = _Fight_Entry;
        Fight_Effect = _Fight_Effect;
        gameObject.tag = "Hero"; //修改卡牌的标签

        //加载C_FightAbility-战斗能力控制器，并初始化
        Type abilityType = Assembly.GetExecutingAssembly().GetType(Card.SO_Card.skillId);
        if (abilityType != null)
        {
            C_Ability = (C_Ability_T)gameObject.AddComponent(abilityType);
            C_Ability.Init_FightAbility(_Card, C_Ability, _Fight_Entry, _Fight_Effect);
        }

        //Init_Update_Entry(List\LIst\LIst)
        // //处理SO_Equip
        // //处理SO_Aurora
        // //处理SO_Pollution

        //设置魔法条的Grid组件
        hpBarWidth = HPBar_Prefab.rect.width;
        // MagicBar_Grid.cellSize = new Vector2(MagicPiece_Width, Card_Magic.GetComponent<RectTransform>().rect.height);
        //更新卡牌信息
        Init_UI_CardFigure(Card.SO_Card);

        //加载C_FightDamage-战斗伤害控制器，并初始化
        C_FightDamage = GetComponent<C_FightDamage>();
        C_FightDamage.Init_FightValue(Card.SO_Card, _Fight_Entry, this.gameObject.GetComponent<C_FightCard>());
    }

    //初始化基础卡牌形象UI
    void Init_UI_CardFigure(SO_Card _SO_Card)
    {
        Clear_ManaPrefabs();

        //设置图片
        CardMain_Img.sprite = _SO_Card.cardImage;

        //设置Mana条及上限
        for (int i = 0; i < _SO_Card.manaMax; i++)
        {
            //实例化并设置父对象为魔法条
            GameObject manaPrefab = Instantiate(Mana_Prefab, ManaBar_Prefab.transform);
            //默认没有蓝量
            // manaPrefab.SetActive(false);
            manaPrefab.name = "Mana" + i;
            manaPrefab.GetComponent<Image>().color = Color.black;

            //保存对象
            manaPrefabList.Add(manaPrefab);
        }
    }


    //----------------------------------------------------------------------------------------------------------
    //模块：Update - 更新

    //更新生命值及护盾UI：传入当前生命值，最大生命值，当前护盾值
    public void Update_CardUI_HP(float _hp, float _hpMax, float _dp)
    {
        //比例判断
        if (_hp + _dp > _hpMax)//大于1超过上限了
        {
            hpRatio = _hp / (_hp + _dp);
            dpRatio = _dp / (_hp + _dp);
        }
        else    //没超过上限按最大值血量算
        {
            hpRatio = _hp / _hpMax;
            dpRatio = _dp / _hpMax;
        }
        //将计算好的比例调入血量和护盾
        Debug.Log("血条比例:" + hpRatio + "护盾比例:" + dpRatio);
        Vector2 temp_V2 = new Vector2(hpBarWidth * Mathf.Clamp01(hpRatio), HPBar_Prefab.rect.height);
        HP_Prefab.sizeDelta = temp_V2;
        //将护盾UI移动到血量UI后面衔接
        temp_V2 = HP_Prefab.anchoredPosition;//获取血条基于锚点位置
        temp_V2 = new Vector2(temp_V2.x + HP_Prefab.sizeDelta.x, temp_V2.y);//将血条基于锚点的位置的x加上血条大小的x
        DP_Prefab.anchoredPosition = temp_V2;
        //设置护盾条ui比例
        DP_Prefab.sizeDelta = new Vector2(hpBarWidth * Mathf.Clamp01(dpRatio), HPBar_Prefab.rect.height);

        //展示血量数值(总数包含血量和血条)
        HP_TMP.text = (_hp + _dp).ToString();
    }

    //更新攻击力数值UI：传入当前攻击力
    public void Update_CardUI_Atk(float _atk)
    {
        //展示Atk数值
        Atk_TMP.text = _atk.ToString();
    }

    //更新Mana条UI：传入当前蓝量
    public void Update_CardUI_Mana(float _mana)
    {
        //对每格蓝条进行处理
        for (int i = 0; i < manaPrefabList.Count; i++)
        {
            if (i < _mana) { manaPrefabList[i].GetComponent<Image>().color = Color.white; }
            else { manaPrefabList[i].GetComponent<Image>().color = Color.black; }
        }
    }

    //----------------------------------------------------------------------------------------------------------
    //模块：Perform - 执行卡牌动作

    public void Perform_Dice_Action(int _diceCurrentFace)
    {
        //现有一个加队列的动作，单人和群体，然后再让队列出列，分别执行switch的具体效果。
        switch (_diceCurrentFace)
        {
            //单体瞬发及队列
            case 1: //单体攻击
                Debug.Log("单体攻击");
                Perform_Attack_1();
                break;

            case 2: //单体恢复Hp
                Debug.Log("单体恢复Hp");
                //Perform_Ability_4();
                Perform_Heal_2(0.2f);
                break;

            case 3: //单体恢复mana
                Debug.Log("单体恢复mana");
                //Perform_Ability_4();
                Perform_GetMana_3(1f);
                break;

            case 4: //单体技能
                Debug.Log("尝试释放技能");
                Perform_Ability_4();
                break;

            default:
                Debug.Log("未知骰子面值");
                break;
        }
    }


    public void Perform_Attack_1()
    {
        //获取最近的目标
        GameObject[] target = Fight_Effect.Ability_GetTargets(gameObject, true, 0, true, 1);

        Debug.Log("target的名字: " + target[0].name);

        //调用攻击Attack方法
        Attack_Act(target[0]);
    }
    public void Perform_Heal_2(float _healRaio)
    {
        //恢复血量
        C_FightDamage.ToSelf_Healing_HpRatio(_healRaio);
        // float health = hpMax * addHealth_Ratio;
        //执行完检查是否满蓝，满蓝就放技能
        // Ability();

        //发布动作完成通知
        Notify_ActionCompleted();
    }

    //======骰子效果卡牌释放技能无视蓝量======//
    public void Perform_GetMana_3(float _mana)
    {
        C_FightDamage.ToSelf_Get_Mana(_mana);
        // Skill_Targets.isIgnoreMagic = true;//无视蓝量释放技能
        // Skill_Targets.IgnoreMagic_AddMagic = addMagic;//恢复的蓝量
        // C_Ability_T.Ability_Release();//触发技能脚本


        Notify_ActionCompleted();
    }

    public void Perform_Ability_4()
    {
        //检测蓝量是否达到释放技能的条件
        if (C_FightDamage.mana > 0)
        {
            Debug.Log("开始释放技能");
            C_FightDamage.ToSelf_Get_Mana(-1);
            C_Ability.Ability_Release();
            // manager_FightCardTimeline.SkillExecuting();//执行技能打断
            // manager_FightCardTimeline.AttackCompleted();//解除执行攻击的打断

            //同步更改当前蓝量
            // gameObject.GetComponent<C_FightDamage>().Sum_Mana(-lastMagic);
            // C_Ability_T.SkillRelase();//触发技能脚本
        }
        else
        {
            //回调
            Debug.Log("蓝量不够");
            //发布动作完成通知
            Notify_ActionCompleted();
        }
    }

    //----------------------------------------------------------------------------------------------------------
    //模块：Act - 表演行动
    void Attack_Act(GameObject _target)
    {
        if (_target == null || isDead)
        {
            Notify_ActionCompleted();
            return;
        }

        C_FightCard targetFightCard = _target.GetComponent<C_FightCard>();
        RectTransform rectTransform = GetComponent<RectTransform>();
        RectTransform targetRectTransform = _target.GetComponent<RectTransform>();
        if (targetFightCard != null && targetFightCard.isDead)
        {
            Notify_ActionCompleted();
            return;
        }

        if (rectTransform == null || targetRectTransform == null)
        {
            Notify_ActionCompleted();
            return;
        }

        Vector2 startAnchoredPosition = rectTransform.anchoredPosition;
        Vector2 targetAnchoredPosition = targetRectTransform.anchoredPosition;

        transform.SetAsLastSibling();
        Sequence attackSequence = DOTween.Sequence().SetAutoKill(true).SetTarget(rectTransform);

        attackSequence.Append(rectTransform.DOAnchorPos(targetAnchoredPosition, attack_duration).SetEase(Ease.OutQuad));
        attackSequence.Join(transform.DOScale(0.8f, attack_duration).SetEase(Ease.InQuad));
        attackSequence.AppendCallback(() =>
        {
            if (targetFightCard == null || targetFightCard.isDead)
            {
                return;
            }

            Vector2 feedbackDirection = (targetAnchoredPosition - startAnchoredPosition).normalized;
            C_FightDamage.ToTarget_Attack_Atk(_target);
            if (targetFightCard.isDead)
            {
                return;
            }

            targetFightCard.Hit_FeedbackAction(feedbackDirection);
        });
        attackSequence.Append(rectTransform.DOAnchorPos(startAnchoredPosition, attack_duration).SetEase(Ease.OutQuad));
        attackSequence.Join(transform.DOScale(1.0f, attack_duration).SetEase(Ease.OutQuad));
        attackSequence.OnComplete(() =>
        {
            Notify_ActionCompleted();
            Debug.Log("真的攻击结束");
        });
    }

    /// <summary>
    /// 标记卡牌进入死亡状态，并清理本体的触发与反馈动画
    /// </summary>
    public void Set_DeadState_Fight()
    {
        isDead = true;

        BoxCollider2D boxCollider2D = GetComponent<BoxCollider2D>();
        if (boxCollider2D != null)
        {
            boxCollider2D.isTrigger = false;
        }

        if (currentFeedbackTween != null)
        {
            currentFeedbackTween.Kill();
            currentFeedbackTween = null;
        }
    }
    //======反馈动画======//
    public void Hit_FeedbackAction(Vector2 _hitDirection)
    {
        if (isDead)
        {
            return;
        }

        // 中断当前所有动画
        if (currentFeedbackTween != null)
        {
            currentFeedbackTween.Kill();
            currentFeedbackTween = null;
        }

        // 恢复初始状态（防止上次动画残留）
        RectTransform rectTransform = GetComponent<RectTransform>();
        transform.localScale = Vector3.one;
        rectTransform.anchoredPosition = posIndexVector;

        // 开始反馈动画
        // 创建 Sequence 并把它绑定到 transform（便于后续 Kill）
        currentFeedbackTween = DOTween.Sequence().SetAutoKill(true).SetTarget(transform);
        currentFeedbackTween.Append(transform.DOScale(1.18f, feedback_duration).SetEase(Ease.OutQuad));
        currentFeedbackTween.Append(transform.DOScale(0.85f, feedback_duration).SetEase(Ease.InQuad));
        currentFeedbackTween.Append(transform.DOScale(1.0f, feedback_duration).SetEase(Ease.OutBack));
        // 反馈位移统一使用 UI 锚点坐标，避免 world 坐标改动 z 轴
        Tween moveTween = rectTransform.DOAnchorPos(rectTransform.anchoredPosition + _hitDirection * fixedLength, feedback_duration)
            .SetEase(Ease.OutCubic)
            .SetLoops(2, LoopType.Yoyo);

        // 将移动动画加入 Sequence
        currentFeedbackTween.Insert(0, moveTween);

        // 注册回调
        currentFeedbackTween.OnKill(() =>
        {
            Debug.Log("反馈动画结束");
        });
    }
    //======真实伤害反馈动画======//
    void Hit_RealDamage_FeedbackAction()
    {
        // 中断当前所有动画
        if (currentFeedbackTween != null)
        {
            currentFeedbackTween.Kill();
            currentFeedbackTween = null;
        }

        // 恢复初始状态
        transform.localScale = Vector3.one;
        Image image = GetComponent<Image>();
        if (image != null)
        {
            image.color = Color.white;
        }

        // 开始反馈动画
        // manager_FightCardTimeline.FeedbackExecuting();

        // 创建 Sequence 并使用 Join 添加动画
        Sequence sequence = DOTween.Sequence();

        // 1. 缩放抖动动画
        sequence.Join(transform.DOPunchScale(Vector3.one * scaleBounce, feedback_duration, 10, 1f)
            .SetEase(Ease.InOutSine));

        // 2. 颜色变化动画
        Image ui = GetComponent<Image>();
        if (ui != null)
        {
            sequence.Join(ui.DOColor(Color.red, 0.1f)
                .OnComplete(() => ui.DOColor(Color.white, 0.2f)));
        }

        // 3. 透明度变化动画
        if (ui != null)
        {
            sequence.Join(ui.DOFade(0.5f, 0.1f)
                .OnComplete(() => ui.DOFade(1f, 0.2f)));
        }

        // 注册回调
        sequence.OnKill(() =>
        {
            // manager_FightCardTimeline.FeedbackCompleted();
            Debug.Log("真实伤害反馈动画结束");
        });

        // 缓存当前动画引用
        currentFeedbackTween = sequence;

        // 播放动画
        sequence.Play();
    }
    //======增益buff的反馈动画======//
    void Add_Buff_FeedbackAction()
    {
        // 中断当前所有动画
        if (currentFeedbackTween != null)
        {
            currentFeedbackTween.Kill();
            currentFeedbackTween = null;
        }

        // 恢复初始状态
        transform.localScale = Vector3.one;
        transform.position = posIndexVector;
        Image image = GetComponent<Image>();
        if (image != null)
        {
            image.color = Color.white;
        }

        // 开始反馈动画
        // manager_FightCardTimeline.FeedbackExecuting();

        float jumpDuration = 0.4f;
        float scaleDuration = 0.4f;
        float scaleUp = 1.2f;//放大倍数

        Sequence sequence = DOTween.Sequence();

        // 1. 上升动画 + 放大 + 颜色/透明度变化（同步）
        Tween jumpUp_Tween = transform.DOMoveY(posIndexVector.y + fixedLength, jumpDuration / 2)
            .SetEase(Ease.OutSine);
        Tween scaleUp_Tween = transform.DOScale(scaleUp, scaleDuration / 2)
            .SetEase(Ease.OutSine);

        Image ui = GetComponent<Image>();
        if (ui != null)
        {
            Tween colorFlash_Tween = ui.DOColor(new Color(0.4f, 0.8f, 0.6f), 0.1f)//接近蓝调的淡绿
                .OnComplete(() => ui.DOColor(Color.white, 0.2f));
            Tween fadeOut_Tween = ui.DOFade(0.6f, 0.1f)
                .OnComplete(() => ui.DOFade(1f, 0.2f));

            // 将放大、颜色、透明度动画与上升动画并行执行
            sequence.Append(jumpUp_Tween);
            sequence.Join(scaleUp_Tween);
            sequence.Join(colorFlash_Tween);
            sequence.Join(fadeOut_Tween);
        }
        // 2. 下降动画 + 缩小
        sequence.Append(transform.DOMoveY(posIndexVector.y, jumpDuration / 2)
            .SetEase(Ease.InSine)
            .OnStart(() => transform.DOScale(Vector3.one, scaleDuration / 2).SetEase(Ease.InSine)));

        // 注册回调
        sequence.OnKill(() =>
        {
            // manager_FightCardTimeline.FeedbackCompleted();
            Debug.Log("真实伤害反馈动画结束");
        });

        // 缓存当前动画引用
        currentFeedbackTween = sequence;

        // 播放动画
        sequence.Play();
    }
    //======施法动画======//
    public Tween PreSkillAction()//卡牌放大+闪光（通用型）
    {
        Image cardImage = GetComponent<Image>();
        Sequence seq = DOTween.Sequence();

        seq.Append(transform.DOScale(1.25f, 0.2f).SetEase(Ease.OutBack));
        seq.Join(cardImage.DOColor(new Color(1, 1, 1, 0.8f), 0.3f));
        seq.Append(transform.DOScale(1.0f, 0.1f));
        seq.Append(cardImage.DOColor(new Color(1, 1, 1, 1), 0.2f));

        seq.Play();
        return seq;//支持回调
    }
    //======例子：检测敌方最近的卡牌======//
    // private GameObject CheckNearestCard()
    // {
    //     // 1. 遍历父对象下所有子对象
    //     GameObject nearestEnemy = null;
    //     float minDistance = Mathf.Infinity;

    //     foreach (Transform child in enemyParent.transform)
    //     {
    //         // 2. 检测子对象是否挂载目标脚本
    //         if (child.GetComponent<C_FightCard>() != null)
    //         {
    //             // 3. 计算距离
    //             float distance = Vector2.Distance(transform.position, child.position);
    //             if (distance < minDistance)
    //             {
    //                 minDistance = distance;
    //                 nearestEnemy = child.gameObject;
    //             }
    //         }
    //     }
    //     nearestEnemy.GetComponent<BoxCollider2D>().isTrigger = true;//谁被攻击谁就是触发器
    //     return nearestEnemy;
    // }

    //======卡牌安全销毁接口======//
    // public void SafeDestroy(GameObject diedObjCard)//魔法条的list也要销毁
    // {
    //     // 判断是怪物还是玩家实例卡牌
    //     if (diedObjCard.tag == "GwCard")//Tag有改动需要注意
    //     {
    //         //直接调用本体
    //         List<GameObject> gwAllCard = init_FightingCard.gwAllCard;
    //         for (int i = 0; i < gwAllCard.Count; i++)
    //         {
    //             if (gwAllCard[i] == diedObjCard)
    //             {
    //                 for (int j = i; j < gwAllCard.Count - 1; j++)
    //                 {
    //                     gwAllCard[j] = gwAllCard[j + 1];//逻辑删除
    //                 }
    //                 gwAllCard.Remove(gwAllCard[gwAllCard.Count - 1]);//避免空引用
    //                 Destroy(diedObjCard);
    //                 //每消灭一个怪物对象询问一次
    //                 init_FightingCard.LevelVictory();
    //             }
    //         }
    //     }
    //     else if (diedObjCard.tag == "PlayerCard")
    //     {
    //         //直接调用本体
    //         List<GameObject> playerFightCard = init_FightingCard.playerFightCard;
    //         for (int i = 0; i < playerFightCard.Count; i++)
    //         {
    //             if (playerFightCard[i] == diedObjCard)
    //             {
    //                 //出战实例卡牌列表逻辑删除[保留空间]
    //                 playerFightCard[i] = null;
    //                 //关卡内阵亡记录卡牌数据类
    //                 Card diedCard = diedObjCard.GetComponent<C_Fight>().heroCard;
    //                 CC_Card.Instance.ManageCardinDiedState(diedCard);
    //                 Destroy(diedObjCard);
    //                 init_FightingCard.LevelDefeat();
    //             }
    //         }
    //     }
    // }

    // ----------------------------------------------------------------------------------------------------------
    //模块：Animation - 动画

    //模块：外部调用，响应骰子的可选择状态和不可选择状态
    public void PlaySelectableUI()    //重复调用激活不同状态
    {
        if (isMakeBlink_Selectable == false)
        {
            isMakeBlink_Selectable = true;
            StartBlink();   //执行闪烁动画
        }
        else
        {
            isMakeBlink_Selectable = false;
            StopBlink();    //取消闪烁动画
        }
    }

    //开始执行闪烁动画
    private void StartBlink()
    {
        blinkSequence?.Kill();  //先把已有的动画给停掉
        canvasGroup.alpha = 1.0f;
        //  激活显示自己
        //gameObject.SetActive(true);
        //创建闪烁动画序列
        blinkSequence = DOTween.Sequence()
            .Append(canvasGroup.DOFade(0.3f, 0.3f))
            .Append(canvasGroup.DOFade(1.0f, 0.3f))
            .SetLoops(-1, LoopType.Yoyo);
    }

    //停止闪烁动画
    private void StopBlink()
    {
        blinkSequence?.Kill();
        blinkSequence = null;
        //  隐藏自己
        //gameObject.SetActive(false);
        canvasGroup.DOKill();    //停止所有动画
        canvasGroup.alpha = 1.0f; //恢复原始透明度
    }

    //模块：外部调用，不可被选择的置灰并停止对象的光线检测
    public void PlayUnselectableUI()
    {
        if (isRayHide_Unselectable == false)
        {
            isRayHide_Unselectable = true;
            StartRayHide();   //执行光线遮挡
        }
        else
        {
            isRayHide_Unselectable = false;
            StopRayHide();    //取消光线遮挡
        }
    }

    //激活区域及卡牌的光线遮挡
    private void StartRayHide()
    {
        //激活卡牌的遮挡
        canvasGroup.blocksRaycasts = false;
        //置灰
        canvasGroup.alpha = 0.5f;
    }

    //关闭区域及卡牌的光线遮挡
    private void StopRayHide()
    {
        //关闭卡牌的遮挡
        canvasGroup.blocksRaycasts = true;
        //恢复
        canvasGroup.alpha = 1.0f;
    }

    //======卡牌动作执行完毕通知======//
    public void Notify_ActionCompleted()
    {
        // if (OnActionCompleted == null)//单体的
        // {
        //     Debug.Log("为单体效果的骰子回调");
        //     //区分玩家和怪物
        //     if (gameObject.tag == "Hero")//玩家回调
        //     {
        //         // manager_PlayerDice.CardActionCompleted();
        //     }
        //     if (gameObject.tag == "Monster")//怪物回调
        //     {
        //         // manager_GwDice.CardActionCompleted();
        //     }
        //     return;
        // }
        //动作执行完毕 「通知订阅者开播了」
        //如果有订阅就执行，有订阅的是群体效果的，是群体里面继续
        OnActionCompleted?.Invoke(this);
    }

    public void DamageFloat()
    {
        float float_duration = 1f;
        float floatLength = gameObject.GetComponent<RectTransform>().rect.height / 2;
        //漂浮动画
        transform.DOMoveY(transform.position.y + floatLength, float_duration).SetEase(Ease.Linear)
        .OnComplete(() =>
        {
            Destroy(gameObject);
        });
    }


    public void Update_HeroCard()   //同步卡牌对战后的hp信息
    {

        Card.hp = GetComponent<C_FightDamage>().hp;
    }

    /// <summary>
    /// 重置英雄实例为准备态
    /// 负责: 恢复死亡标记, 动画状态和准备态可见表现
    /// </summary>
    public void Reset_HeroRuntimeForPrepare()
    {
        isDead = false;
        diceIntentionObjList.Clear();
        PreDiceOBJ.Clear();

        if (currentFeedbackTween != null)
        {
            currentFeedbackTween.Kill();
            currentFeedbackTween = null;
        }

        StopBlink();
        StopRayHide();
        transform.localScale = Vector3.one;
        GetComponent<RectTransform>().anchoredPosition = posIndexVector;

        BoxCollider2D BoxCollider2D = GetComponent<BoxCollider2D>();
        if (BoxCollider2D != null)
        {
            BoxCollider2D.isTrigger = true;
        }
    }

    /// <summary>
    /// 重绑前重置运行时状态
    /// </summary>
    void Reset_RuntimeStateBeforeBind()
    {
        Clear_AbilityComponents();
        Clear_ManaPrefabs();

        diceIntentionObjList.Clear();
        PreDiceOBJ.Clear();
        isMakeBlink_Selectable = false;
        isRayHide_Unselectable = false;

        if (currentFeedbackTween != null)
        {
            currentFeedbackTween.Kill();
            currentFeedbackTween = null;
        }

        blinkSequence?.Kill();
        blinkSequence = null;
        if (canvasGroup != null)
        {
            canvasGroup.alpha = 1.0f;
            canvasGroup.blocksRaycasts = true;
        }

        transform.localScale = Vector3.one;
    }

    /// <summary>
    /// 清理旧技能组件
    /// </summary>
    void Clear_AbilityComponents()
    {
        C_Ability_T[] abilityComponents = GetComponents<C_Ability_T>();
        foreach (C_Ability_T abilityComponent in abilityComponents)
        {
            if (abilityComponent != null)
            {
                Destroy(abilityComponent);
            }
        }

        C_Ability = null;
    }

    /// <summary>
    /// 清理旧 mana 节点
    /// </summary>
    void Clear_ManaPrefabs()
    {
        for (int i = 0; i < manaPrefabList.Count; i++)
        {
            if (manaPrefabList[i] != null)
            {
                Destroy(manaPrefabList[i]);
            }
        }

        manaPrefabList.Clear();

        for (int i = ManaBar_Prefab.transform.childCount - 1; i >= 0; i--)
        {
            Destroy(ManaBar_Prefab.transform.GetChild(i).gameObject);
        }
    }

    // 在销毁时确保 kill tween 与清理
    private void OnDestroy()
    {
        if (currentFeedbackTween != null)
        {
            currentFeedbackTween.Kill();
            currentFeedbackTween = null;
        }
        Debug.Log("销毁卡牌时清理动画");
    }
}
