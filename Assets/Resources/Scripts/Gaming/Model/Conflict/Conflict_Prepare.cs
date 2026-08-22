using System.Collections.Generic;
using DG.Tweening;
using UnityEngine;

[RequireComponent(typeof(RectTransform))]
public class Conflict_Prepare : MonoBehaviour
{
    //模块：初始化的卡牌脚本
    [Header("模块: 备战UI参数与组件")]
    [Tooltip("备战席区域对象")] public RectTransform prepareScollRect;
    [Tooltip("CC_Conflict脚本")] public CC_Conflict CC_Conflict;
    [Tooltip("备战席滑动区域对象")] public GameObject PrepareContentObj;
    [Tooltip("轻量化的备战席预制体资源")] public GameObject PrepareCard_Prefab;
    [Tooltip("顶部栏")] public GameObject topContainer;
    [Tooltip("底部栏")] public GameObject bottomContainer;
    [Tooltip("备战席卡牌列表")] private List<GameObject> prepareCardObjList = new List<GameObject>();

    [Header("模块: 公开数据资源")]
    [HideInInspector] public Card_Attribute Card_Attribute; // 卡牌属性表
    [HideInInspector] public int targetPosIndex; // 缓存所点击坑位的序号
    [Tooltip("是否进入替换选择状态")] public bool isReplaceSelect = false; // 默认为false true = 进入状态 false = 未进入状态

    // --- 内部状态 --- (UI布局数据与缓存记录)
    private Vector2 prepareViewPort_OriginPos; // 备战席初始位置
    private List<Card> heroUnlockedCardList; // 玩家拥有的卡组列表
    private PrepareFlowMode prepareFlowMode = PrepareFlowMode.None; // 备战流程模式
    private const float MOVE_DURATION = 0.25f; // 动画时长
    public PrepareFlowMode CurrentFlowMode => prepareFlowMode;  // 当前备战流程模式

    // ==========================================
    // 1. 初始化预处理 (Initial)
    // ==========================================

    /// <summary>
    /// 初始化备战卡池
    /// 负责: 1.缓存玩家持有卡组, 2.初始化备战席布局依赖, 3.刷新动态备战卡 UI 缓存
    /// </summary>
    /// <param name="_heroUnlockedCardList">玩家持有的完整卡组列表</param>
    public void Init_Prepare(List<Card> _heroUnlockedCardList)
    {
        // 备战席默认显示状态
        bottomContainer.SetActive(false);
        // 为基础属性赋值
        prepareViewPort_OriginPos = prepareScollRect.anchoredPosition;   // 备战席初始位置
        heroUnlockedCardList = _heroUnlockedCardList ?? new List<Card>();

        // 清理编辑器阶段残留的预挂卡牌对象, 后续统一由运行时生成。
        Clear_ContentResidualChildren();

        // 将所有卡牌初始化
        Update_PrepareCard();
    }
    // ==========================================
    // 2. 备战席视图控制交互 (View Control)
    // ==========================================

    /// <summary>
    /// 【核心】打开备战席面板
    /// 负责: 1.记录当前操作状态, 2.更新备战席卡牌数据, 3.隐藏部分战斗环境UI并滑屏展开
    /// </summary>
    public void Show_PrepareArea()
    {
        // 更新备战席的数据和UI内容
        Update_PrepareCard();

        // 移动top栏，隐藏相关UI
        CC_Conflict.Com_HideBtn();
        CC_Conflict.Hide_HeroCard_Prepare();
        CC_Conflict.MoveUp_TopContainer();
        //  显示备战席上下栏的遮挡
        topContainer.SetActive(true);
        bottomContainer.SetActive(true);
        // 移动备战席
        Move_PrepareArea(prepareViewPort_OriginPos.y + prepareScollRect.rect.height);
    }

    /// <summary>
    /// 更新备战卡牌的状态数据和占位图层
    /// 负责: 按玩家已解锁卡牌数量补齐 UI 缓存, 并刷新真实卡牌展示和可选状态
    /// </summary>
    public void Update_PrepareCard()
    {
        if (heroUnlockedCardList == null)
        {
            Hide_UnusedPrepareCardInstances(0);
            return;
        }

        Ensure_PrepareCardInstances(heroUnlockedCardList.Count);

        // 只激活真实存在的已解锁卡牌 UI, 不补齐空格子。
        for (int i = 0; i < heroUnlockedCardList.Count; i++)
        {
            GameObject prepareCardObj = prepareCardObjList[i];
            if (prepareCardObj == null)
            {
                continue;
            }

            Card card = heroUnlockedCardList[i];
            C_Card cCard = prepareCardObj.GetComponent<C_Card>();
            if (cCard == null)
            {
                prepareCardObj.SetActive(false);
                Debug.LogWarning("备战卡 UI 缺少 C_Card 组件: " + prepareCardObj.name);
                continue;
            }

            prepareCardObj.SetActive(true);
            cCard.Card_Attribute = Card_Attribute;
            cCard.Init_PrepareCard(card, Get_CardAttributeActionMode());
            cCard.Set_PrepareSelectable(Check_IsSelectableCard(card));
        }

        Hide_UnusedPrepareCardInstances(heroUnlockedCardList.Count);
    }

    /// <summary>
    /// 【核心】确保备战卡 UI 缓存数量满足当前已解锁卡牌数量
    /// </summary>
    /// <param name="targetCount">需要展示的真实卡牌数量</param>
    void Ensure_PrepareCardInstances(int targetCount)
    {
        for (int i = 0; i < targetCount; i++)
        {
            if (i >= prepareCardObjList.Count)
            {
                prepareCardObjList.Add(Create_PrepareCardInstance());
                continue;
            }

            if (prepareCardObjList[i] == null)
            {
                prepareCardObjList[i] = Create_PrepareCardInstance();
            }
        }
    }

    /// <summary>
    /// 【核心】清理备战席 Content 下的开发残余子对象
    /// </summary>
    void Clear_ContentResidualChildren()
    {
        if (PrepareContentObj == null)
        {
            return;
        }

        foreach (Transform child in PrepareContentObj.transform)
        {
            Destroy(child.gameObject);
        }

        prepareCardObjList.Clear();
    }

    /// <summary>
    /// 创建单个备战卡 UI 实例并挂载到布局内容区
    /// </summary>
    /// <returns>创建出的备战卡 UI 对象</returns>
    GameObject Create_PrepareCardInstance()
    {
        if (PrepareCard_Prefab == null || PrepareContentObj == null)
        {
            Debug.LogWarning("备战卡 UI 生成失败: 预制体或内容区未配置。");
            return null;
        }

        GameObject prepareCardObj = Instantiate(PrepareCard_Prefab, PrepareContentObj.transform);
        prepareCardObj.name = "PrepareCard_" + prepareCardObjList.Count;
        return prepareCardObj;
    }

    /// <summary>
    /// 隐藏缓存中当前不需要展示的备战卡 UI
    /// </summary>
    /// <param name="activeCount">当前真实需要展示的卡牌数量</param>
    void Hide_UnusedPrepareCardInstances(int activeCount)
    {
        if (prepareCardObjList == null)
        {
            return;
        }

        for (int i = activeCount; i < prepareCardObjList.Count; i++)
        {
            if (prepareCardObjList[i] != null)
            {
                prepareCardObjList[i].SetActive(false);
            }
        }
    }

    /// <summary>
    /// 备战面板移动位移补间序列
    /// 负责: 封装并挂载DOTween实现移动操作
    /// </summary>
    /// <param name="_endPosition">末端锚点Y游标归属落位</param>
    /// <returns>返回并抛接执行补间排程句柄</returns>
    private Sequence Move_PrepareArea(float _endPosition)
    {
        // 制作动画
        Sequence sequence = DOTween.Sequence();
        Tween prepare_Move = prepareScollRect.DOAnchorPosY(_endPosition, MOVE_DURATION).SetEase(Ease.OutQuad);
        sequence.Append(prepare_Move);
        return sequence;
    }

    /// <summary>
    /// 玩家操作：关闭并收起备战席面板
    /// 负责: 执行面板移动回位的排程动画, 并在结束后恢复展示对战的核心环境UI
    /// </summary>
    public void OnBtn_ClosePrepareArea() 
    {
        Sequence sequence = Move_PrepareArea(prepareViewPort_OriginPos.y);
        sequence.OnComplete(() =>        //运行
        {
            //关闭备战席上下栏的遮挡
            topContainer.SetActive(false);
            bottomContainer.SetActive(false);
            Reset_Conflict_Prepare();

            CC_Conflict.Com_ShowBtn();  //显示按钮
            CC_Conflict.Show_HeroCard_Prepare();    //展示玩家卡牌
        });
        CC_Conflict.MoveDown_TopContainer();

    }

    /// <summary>
    /// 重置备战席替换功能交互授权标记
    /// 负责: 还原至最初始的待命查阅交互判定
    /// </summary>
    public void Reset_Conflict_Prepare() 
    {
        Set_PrepareFlowMode(PrepareFlowMode.None);
        targetPosIndex = -1;
    }

    /// <summary>
    /// 以出战模式打开备战席
    /// </summary>
    /// <param name="_targetPosIndex">目标站位</param>
    public void Open_DeployPrepare(int _targetPosIndex)
    {
        targetPosIndex = _targetPosIndex;
        Set_PrepareFlowMode(PrepareFlowMode.Deploy);
        Show_PrepareArea();
    }

    /// <summary>
    /// 以替换模式打开备战席
    /// </summary>
    /// <param name="_targetPosIndex">目标站位</param>
    public void Open_ReplacePrepare(int _targetPosIndex)
    {
        targetPosIndex = _targetPosIndex;
        Set_PrepareFlowMode(PrepareFlowMode.Replace);
        Show_PrepareArea();
    }

    /// <summary>
    /// 提交当前选中的卡牌
    /// </summary>
    /// <param name="_card">目标卡牌</param>
    public void Commit_SelectedCard(Card _card)
    {
        if (_card == null)
        {
            return;
        }

        switch (prepareFlowMode)
        {
            case PrepareFlowMode.Deploy:
                _card.posIndex = targetPosIndex;
                CC_Conflict.Conflict_RuntimeBoard.Deploy_HeroCardRuntime(_card, targetPosIndex);
                OnBtn_ClosePrepareArea();
                break;
            case PrepareFlowMode.Replace:
                _card.posIndex = targetPosIndex;
                CC_Conflict.Conflict_RuntimeBoard.Replace_HeroCardRuntime(_card, targetPosIndex);
                OnBtn_ClosePrepareArea();
                break;
        }
    }

    /// <summary>
    /// 判断备战席中卡牌是否可选
    /// </summary>
    /// <param name="_card">目标卡牌</param>
    /// <returns>是否可选</returns>
    public bool Check_IsSelectableCard(Card _card)
    {
        if (_card == null)
        {
            return false;
        }

        return _card.posIndex < 0;
    }

    /// <summary>
    /// 设置当前备战流程模式
    /// </summary>
    /// <param name="_prepareFlowMode">目标模式</param>
    private void Set_PrepareFlowMode(PrepareFlowMode _prepareFlowMode)
    {
        prepareFlowMode = _prepareFlowMode;
        isReplaceSelect = prepareFlowMode == PrepareFlowMode.Replace;
    }

    /// <summary>
    /// 获取当前备战席属性表动作模式
    /// </summary>
    /// <returns>属性表动作模式</returns>
    private CardAttributeActionMode Get_CardAttributeActionMode()
    {
        switch (prepareFlowMode)
        {
            case PrepareFlowMode.Replace:
                return CardAttributeActionMode.ConfirmReplace;
            case PrepareFlowMode.Deploy:
                return CardAttributeActionMode.Deploy;
            default:
                return CardAttributeActionMode.Deploy;
        }
    }
    //制作动画
    // Sequence sequence = DOTween.Sequence();
    // Tween battle_Move = battleField.transform.DOMove(parent.transform.position, MOVE_DURATION).SetEase(Ease.OutQuad);
    // Tween prepare_Move = parent.transform.DOMove(parent_Origin, MOVE_DURATION).SetEase(Ease.OutQuad);
    // sequence.Join(prepare_Move);
    // sequence.Join(battle_Move);
    // //运行
    // sequence.OnComplete(() =>
    // {
    //     //显示按钮
    //     GetComponent<CC_Fight>().Com_HideBtn();
    // });


    // 检查是否在出战列表中
    // if (!prepareCardList.Any(heroCardFight => deployed. == card.Id))
    // {
    //     posIndex
    // }
    // prepareCardList
    // heroCardDick
    //把所有卡牌循环跳过出战卡牌
    // for (int i = 0; i < playerAllCards.Count; i++)
    // {
    //     if (playerFightCard.Contains(playerAllCards[i]))
    //     {
    //         Debug.Log("出战卡牌跳过");
    //         continue;
    //     }
    //     //将剩下的卡牌放入备战席
    //     playerAllCards[i].transform.parent = transform;//调整父对象为备战席
    //     Debug.Log("备战席分配中");
    //     //更新实例卡牌的记录初始位置
    //     playerAllCards[i].GetComponent<PlayerCard_UIManager>().originPos = playerAllCards[i].transform.position;
    //     playerAllCards[i].GetComponent<PlayerCard_UIManager>().AutoModifyCardFightState();
    // }

        //======动态更新备战席======//


        //======分配卡牌进入备战席======//

        //======打开备战席按钮======//

        //======关闭备战席按钮======//[确认队伍]

}
