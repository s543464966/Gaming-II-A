using UnityEngine;
using UnityEngine.EventSystems;
using DG.Tweening;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine.UI;

public class Card_Interaction : MonoBehaviour, IBeginDragHandler, IDragHandler, IPointerUpHandler,IPointerDownHandler
{
    // ==========================================
    // 1. 数据核心与运行态
    // ==========================================
    public enum CardState { Idle, Dragging, Swapping } // 枚举型「状态机」：空闲，拖动中，交换中
    
    [Header("模块: 基础配置")]
    [Tooltip("缓存自身所在Canvas")] public Canvas parentCanvas; // 缓存自身所在 Canvas
    
    // --- 内部状态 --- (交互态与组件引用)
    private CardState currentState = CardState.Idle; // 初始化起始状态
    [HideInInspector] public Card_Attribute Card_Attribute; // 卡牌属性表
    [HideInInspector] public Tween _moveTween; // 动画对象引用
    
    private const float SWAP_DURATION = 0.5f; // 交换动画持续时间
    private Vector2 swapStartPos; // 记录临时被交换卡的起始位置
    private GraphicRaycaster graphicRaycaster; // 光线控制
    private GameObject swapTarget = null; // 交换目标对象

    // ----------------------------------------------------------------------------------------------------------

    // ==========================================
    // 2. 初始化流程
    // ==========================================

    /// <summary>
    /// Awake执行预备初始化
    /// 负责: 绑定Canvas等基本组件，记录原生Position
    /// </summary>
    private void Awake()
    {
        graphicRaycaster = GetComponentInParent<GraphicRaycaster>();
        parentCanvas = graphicRaycaster ? graphicRaycaster.GetComponent<Canvas>() : null; // 获取父级Canvas
    }
    // ==========================================
    // 3. 拖拽交互动作流
    // ==========================================

    /// <summary>
    /// 【核心】响应点击按下事件
    /// 负责: 1.打断当前可能正在播放的位移动画, 2.重置状态机为等待, 3.记录当前的位置坐标系索引
    /// </summary>
    public void OnPointerDown(PointerEventData eventData)
    {
        // 打断动画
        KillTween(_moveTween);
        Debug.Log("点击目标");
        currentState = CardState.Idle;
        // 记录此时的位置索引
    }
    /// <summary>
    /// 响应开始拖拽事件
    /// 负责: 1.设置状态为拖动中, 2.记录起点用来可能地复位, 3.将UI层级置顶防止遮挡
    /// </summary>
    public void OnBeginDrag(PointerEventData eventData) // 开始拖动
    {
        // 仅在空闲状态下响应
        if (currentState != CardState.Idle) return;
        // if (isStart == true || isPreparePage == true) return;//开始或备战页面后不能被拖动
        // 打断动画
        KillTween(_moveTween);
        Debug.Log("开始拖动");
        
        // 变更状态并记录起始位置
        currentState = CardState.Dragging;
        swapStartPos = transform.position;

        // 放置在该子级顶端
        transform.SetAsLastSibling();
    }

    /// <summary>
    /// 【核心】响应拖拽进行中事件
    /// 负责: 根据指针转换出相机视角下的世界坐标来紧跟手指/鼠标位移, 并实时发射射线检测底下是否有可交换对象
    /// </summary>
    public void OnDrag(PointerEventData eventData) // 拖动中
    {
        // 仅在拖动状态下响应
        if (currentState != CardState.Dragging) return;
        // 打断动画
        KillTween(_moveTween);
        
        // 实时更新位置
        RectTransformUtility.ScreenPointToWorldPointInRectangle(
            GetComponent<RectTransform>(),
            eventData.position,
            eventData.pressEventCamera,
            out Vector3 worldPos
        );
        transform.position = worldPos;
        Debug.Log("拖动中");
        
        // 检测交换目标
        Swap_DetectTarget(eventData);
    }

    /// <summary>
    /// 【核心】响应停止拖拽松开事件
    /// 负责: 1.判断若是未拖动的单纯点击, 呼出属性面板组件, 2.若是拖放, 基于是否有目标发生卡位互换或是回退位移
    /// </summary>
    public void OnPointerUp(PointerEventData eventData) // 松开
    {
        if (enabled == false)
        {
            return;
        }

        // 仅在idle状态下响应
        if (currentState != CardState.Dragging)
        {
            Debug.Log("松开状态");
            // 打开属性面板
            if (currentState == CardState.Idle)
            {
                C_FightCard C_FightCard = GetComponent<C_FightCard>();
                if (C_FightCard != null && C_FightCard.Card != null)
                {
                    // 场上已出战卡点击后, 先查看目标卡牌属性, 再由属性表按钮进入替换选择。
                    Card_Attribute.Update_CardAttribute(C_FightCard.Card, CardAttributeActionMode.SelectReplace);
                }

                //展示备战席
                // Conflict_Prepare.Show_PrepareArea();
            }
            currentState = CardState.Idle;
            return;
        }
        // 重置缩放
        // KillTween(_scaleTween);
        // _scaleTween = transform.DOScale(1f, SCALE_DURATION)
        //     .SetEase(Ease.OutBack);
        //需要执行交换或复位动作
        if (swapTarget != null)
        {
            Debug.Log("有物体" + swapTarget.name);
            // 获取目标属性
            bool isCardSwap = swapTarget.TryGetComponent(out Card_Interaction targetCard); // 尝试获取该对象上是否有该组件
            Vector2 targetAnchoredPos = isCardSwap ?
                targetCard.GetComponent<C_FightCard>().posIndexVector : // 获取交换卡牌上的UI锚点相对坐标
                swapTarget.GetComponent<RectTransform>().anchoredPosition; // 获取占位白卡的UI锚点相对坐标
            
            // 存储临时自身位置
            Vector2 tempAnchoredPos = GetComponent<C_FightCard>().posIndexVector;
            // 执行位置数据进行互相交换
            CardPosDataSwap(isCardSwap, targetAnchoredPos);
            // 执行动画协程
            StartCoroutine(Swap_AutoRoutine(isCardSwap, targetAnchoredPos, tempAnchoredPos));
        }
        else
        {
            Debug.Log("开始执行复位动画");
            ReturnToOrigin();
        }

        currentState = CardState.Idle;
    }

    // ==========================================
    // 4. 辅助执行逻辑
    // ==========================================

    /// <summary>
    /// 底层射线交互探针
    /// 负责: 投出UI射线, 返回碰到的第一个合法可交换物体对象并缓存在引用中
    /// </summary>
    /// <param name="eventData">指针事件载体</param>
    private void Swap_DetectTarget(PointerEventData eventData)
    {
        // 获取射线结果
        var results = new List<RaycastResult>();
        graphicRaycaster.Raycast(eventData, results); // [注意光线目标检测]

        // 过滤无效目标, 寻找卡牌或占位符
        foreach (var r in results)
        {
            if (r.gameObject == gameObject) continue; // 跳过自己

            // 判断是否是可交换对象(卡牌或占位符)
            bool isCard = r.gameObject.TryGetComponent(out Card_Interaction _);
            bool isBlank = r.gameObject.CompareTag("BlankCard");
            
            // 允许出战席之间的卡牌交换位置
            if (isCard || isBlank)
            {
                swapTarget = r.gameObject;
                break; // 只处理第一个有效目标
            }
            else
            {
                swapTarget = null;
            }
        }
    }
    /// <summary>
    /// 卡牌对战席数据交换
    /// 负责: 根据交换类型(另一张卡牌/空白格子), 同步它们的原点坐标标记和战斗阵型索引
    /// </summary>
    /// <param name="isHeroCard">是否是实体卡牌</param>
    /// <param name="targetAnchoredPos">要换过去的UI锚点相对坐标</param>
    void CardPosDataSwap(bool isHeroCard, Vector2 targetAnchoredPos)
    {
        // 通过检测TargetCard是否有操控脚本, 来判断是否为卡牌, 并进行数据交换
        if (isHeroCard)
        {
            // 互换C_FightCard位置数据
            swapTarget.GetComponent<C_FightCard>().posIndexVector = GetComponent<C_FightCard>().posIndexVector;
            GetComponent<C_FightCard>().posIndexVector = targetAnchoredPos;

            // 互换出战卡牌顺序
            int posIndex = GetComponent<C_FightCard>().Card.posIndex;
            int swapPosIndex = swapTarget.GetComponent<C_FightCard>().Card.posIndex;
            GetComponent<C_FightCard>().Card.posIndex = swapPosIndex;
            swapTarget.GetComponent<C_FightCard>().Card.posIndex = posIndex;
        }
        else // 占位符交换
        {
            GetComponent<C_FightCard>().posIndexVector = targetAnchoredPos;

            // 互换出战卡牌顺序
            int swapPosIndex = swapTarget.GetComponent<C_Blank>().posIndex;
            Debug.Log(swapPosIndex);
            GetComponent<C_FightCard>().Card.posIndex = swapPosIndex;
        }
    }

    /// <summary>
    /// 交换动画协程展示
    /// 负责: 串联触发自己和目标体的 DOTween 位移效果, 并且锁死状态防止连续误操作, 直到动画播完
    /// </summary>
    private IEnumerator Swap_AutoRoutine(bool isHeroCard, Vector2 targetAnchoredPos, Vector2 originAnchoredPos)
    {
        // 设置交换状态
        currentState = CardState.Swapping;

        _moveTween = GetComponent<RectTransform>().DOAnchorPos(targetAnchoredPos, SWAP_DURATION).SetEase(Ease.OutQuad);
        
        if (isHeroCard) // 告诉对方记录的移动动画的变量
        {
            swapTarget.GetComponent<Card_Interaction>()._moveTween = swapTarget.GetComponent<RectTransform>().DOAnchorPos(originAnchoredPos, SWAP_DURATION).SetEase(Ease.OutQuad);
        } 

        yield return _moveTween.WaitForCompletion();

        // 重置状态
        swapTarget = null;
        currentState = CardState.Idle;
    }

    /// <summary>
    /// 通用复位方法
    /// 负责: 拖拽到非法区域产生取消逻辑时, 触发归位动画
    /// </summary>
    private void ReturnToOrigin()
    {
        KillTween(_moveTween);
        Vector2 originAnchoredPos = GetComponent<C_FightCard>().posIndexVector; //  获取自身的原始UI锚点相对坐标
        _moveTween = GetComponent<RectTransform>().DOAnchorPos(originAnchoredPos, SWAP_DURATION).SetEase(Ease.OutQuad);
    }
    
    /// <summary>
    /// 打断动画
    /// 负责: 防止多个补间冲突
    /// </summary>
    private void KillTween(Tween tween)
    {
        if (tween != null && tween.IsActive())
        {
            tween.Kill();
        }
    }

    /// <summary>
    /// 设置准备态交互启停
    /// 负责: 在进入战斗和返回准备态时统一开关本组件交互
    /// </summary>
    /// <param name="_isEnabled">是否启用准备态交互</param>
    public void Set_PrepareInteractionEnabled(bool _isEnabled)
    {
        if (_isEnabled == false)
        {
            swapTarget = null;
            currentState = CardState.Idle;
            KillTween(_moveTween);
        }

        enabled = _isEnabled;
    }

    //====== 备战状态下的点击功能 ======//
    // private void PrepareStateClick()
    // {
    //     isMove = true;//开始移动
    //     if (battleType == BattleType.Fight)//当前点击的是出战席
    //     {
    //         MoveToPrepareField();
    //     }
    //     else if (battleType == BattleType.Prepare)//当前点击的是备战席
    //     {
    //         if (!IsBattleFieldFull())
    //         {   //没满进入
    //             MoveToBattleField();
    //         }
    //         else
    //         {
    //             isMove = false;
    //             Debug.LogWarning("出战席已满，无法放入");
    //         }
    //     }
    // }
    //====== 备战席点击移动去出战席 ======//
    // private void MoveToBattleField()
    // {
    //     int index = 0;
    //     //先处理数据[加入对战列表]
    //     for (int i = 0; i < playerFightCards.Count; i++)
    //     {
    //         //就找第一个为空的位置
    //         if (playerFightCards[i] == null)
    //         {
    //             index = i;
    //             playerFightCards[i] = gameObject;//放入对战列表
    //             break;
    //         }
    //     }
    //     Vector2 temp_target = blankCards[index].transform.position;
    //     //设置父对象
    //     transform.parent = prepareBtn.transform;
    //     //将卡移动到出战席
    //     _moveTween = transform.DOMove(temp_target, MOVE_DURATION).SetEase(Ease.OutQuad)
    //         .OnComplete(() =>
    //         {
    //             transform.parent = battleParent.transform;
    //             AutoModifyCardFightState();
    //             isMove = false;//移动结束
    //         });
    // }
    // //====== 出战席点击移动去备战席 ======//
    // private void MoveToPrepareField()
    // {
    //     //备战席是否有子对象
    //     if (prepareParent.transform.childCount == 0)
    //     {
    //         //先处理数据[不在对战列表上]
    //         int index = playerFightCards.IndexOf(gameObject);
    //         // 如果找到该对象（index >= 0），则将其设为 null
    //         if (index >= 0)
    //         {
    //             playerFightCards[index] = null;
    //         }
    //         //设置自身为出战席子对象顶部
    //         transform.SetAsLastSibling();
    //         //没有子对象要先用特定的局部坐标转换成世界坐标来移动
    //         // Vector2 temp_target_Anchored = prepareParent.GetComponent<Manager_PrepareCard>().firstCard_Anchored;//锚点相对坐标
    //         // float newX = prepareParent.transform.position.x + temp_target_Anchored.x;
    //         // float newY = prepareParent.transform.position.y + temp_target_Anchored.y;
    //         // Vector2 temp_target_World = new Vector2(newX,newY);
    //         //设置父对象
    //         transform.parent = prepareBtn.transform;
    //         //将卡移动到备战席
    //         // _moveTween = transform.DOMove(temp_target_World, MOVE_DURATION).SetEase(Ease.OutQuad)
    //         //     .OnComplete(() =>
    //         //     {
    //         //         transform.parent = prepareParent.transform;
    //         //         AutoModifyCardFightState();
    //         //         //移动到再调子对象顺序
    //         //         transform.SetAsFirstSibling();//放置最后位置
    //         //         isMove = false;//移动结束
    //         //     });
    //     }
    //     else
    //     {
    //         //先处理数据[不在对战列表上]
    //         int index = playerFightCards.IndexOf(gameObject);
    //         // 如果找到该对象（index >= 0），则将其设为 null
    //         if (index >= 0)
    //         {
    //             playerFightCards[index] = null;
    //         }
    //         //设置自身为出战席子对象顶部
    //         transform.SetAsLastSibling();
    //         Transform tempFirst = prepareParent.transform.GetChild(0);
    //         Vector2 temp_target = tempFirst.position;
    //         //设置父对象
    //         transform.parent = prepareBtn.transform;
    //         //将卡移动到备战席
    //         _moveTween = transform.DOMove(temp_target, MOVE_DURATION).SetEase(Ease.OutQuad)
    //             .OnComplete(() =>
    //             {
    //                 transform.parent = prepareParent.transform;
    //                 AutoModifyCardFightState();
    //                 //移动到再调子对象顺序
    //                 transform.SetAsFirstSibling();//放置最后位置
    //                 isMove = false;//移动结束
    //             });
    //     }

    // }

    //====== 工具方法 ======//
    //修改出战和备战状态
    // public void AutoModifyCardFightState()
    // {
    //     // 自动识别状态
    //     // if (transform.parent.GetComponent<PlayerCardLayout_UIManager>())//出战席
    //     //     battleType = BattleType.Fight;
    //     // else if (transform.parent.GetComponent<Manager_PrepareCard>())//备战席
    //     //     battleType = BattleType.Prepare;
    // }
    //判断是否出战席满了
    // private bool IsBattleFieldFull()
    // {
    //     if (playerFightCards == null)
    //     {
    //         Debug.LogError("playerFightCards 未初始化！");
    //         return true;
    //     }

    //     // 如果列表中存在 null（空位），返回 false（未满）
    //     return !playerFightCards.Any(card => card == null);
    // }
    //返回原位

}
