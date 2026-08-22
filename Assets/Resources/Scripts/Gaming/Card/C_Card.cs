using System.Collections;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

[RequireComponent(typeof(CanvasGroup))]
public class C_Card : MonoBehaviour
{
    //======占位白卡的行列位置属性======//
    // public int blankCard_Row;//行数
    // public int blankCard_Column;//列数
    [Header("模块: UI - 界面")]
    [Tooltip("卡牌形象主图")] public Image CardMain_Img; // 卡牌形象主图
    [Tooltip("卡牌边框图")] public Image CardBorder_Img; // 卡牌边框图

    [Header("模块: 状态容器")]
    [Tooltip("解锁状态/战斗状态的父节点")] public GameObject Unlocked_UIContainer; // 解锁状态/战斗状态的父节点
    [Tooltip("未解锁状态的父节点")] public GameObject Locked_UIContainer; // 未解锁状态的父节点
    
    [Header("模块: 解锁/战斗 UI")]
    [Tooltip("攻击类型图")] public Image CardAttackBar_Img; // 卡牌攻击类型图
    [Tooltip("攻击力数值")] public TMP_Text Atk_TMP; // 攻击力数值展示
    [Tooltip("生命条预制体")] public RectTransform HPBar_Prefab; // 血条Transform
    [Tooltip("生命预制体")] public RectTransform HP_Prefab; // 血量Transform
    [Tooltip("生命值数值展示")] public TMP_Text HP_TMP; // 生命值数值展示
    [Tooltip("护盾预制体")] public RectTransform DP_Prefab; // 护盾Transform
    [Tooltip("Mana条预制体")] public GameObject ManaBar_Prefab; // Mana条对象
    [Tooltip("Mana预制体")] public GameObject Mana_Prefab; // Mana预制体
    [Tooltip("解锁状态下卡牌职业")] public Image Unlocked_CareerType_Image; // 解锁状态下卡牌职业
    [Tooltip("解锁状态下卡牌元素")] public Image Unlocked_ElementType_Image; // 解锁状态下卡牌元素
    
    [Header("模块: 锁定 UI")]
    [Tooltip("锁定时的提示字")] public TMP_Text Lock_Cost_TMP; // 锁定时的提示字
    [Tooltip("未解锁状态下的卡牌职业")] public Image Locked_CareerType_Image; // 未解锁状态下的卡牌职业
    [Tooltip("未解锁状态下卡牌元素")] public Image Locked_ElementType_Image; // 未解锁状态下卡牌元素
    
    [Header("模块: 辅助属性引用")]
    [Tooltip("卡牌属性属性表")] public Card_Attribute Card_Attribute; // 卡牌属性属性表
    
    // --- 内部状态 --- (数据支撑)
    private float hpRatio; // 生命比例
    private float dpRatio; // 护盾比例
    private Card card; // 卡牌数据
    private CardAttributeActionMode cardAttributeActionMode = CardAttributeActionMode.Deploy; // 属性表动作模式

    // ----------------------------------------------------------------------------------------------------------
    // ==========================================
    // 1. 初始化流程 (Initial)
    // ==========================================
    
    /// <summary>
    /// 【核心】战斗模式初始化
    /// 负责: 1.绑定卡牌数据, 2.初始化基础图文, 3.判断出战状态并灰置交互
    /// </summary>
    /// <param name="_card">战斗使用的基础卡片数据</param>
    /// <param name="_cardAttributeActionMode">属性表动作模式</param>
    public void Init_PrepareCard(Card _card, CardAttributeActionMode _cardAttributeActionMode)
    {
        card = _card;
        //更改Card的基本信息(待改进)，还需要将所有需要更换的信息，进行设定
        // hp
        Init_UI_CardFigure();
        Switch_VisualUIState(true, true, _cardAttributeActionMode);
        Set_PrepareSelectable(true);
    }
    // ==========================================
    // 2. 仓库模式初始化
    // ==========================================
    
    /// <summary>
    /// 【核心】仓库模式初始化
    /// 负责: 1.判断当前是否解锁, 2.分发处理解锁与锁定布局的状态, 3.强制可交互操作
    /// </summary>
    /// <param name="_card">传参的卡牌逻辑表</param>
    /// <param name="_cardAttributeActionMode">属性表动作模式</param>
    public void Init_CollectionCard(Card _card, CardAttributeActionMode _cardAttributeActionMode)
    {
        card = _card;
        // 基础显示复用
        Init_UI_CardFigure();
        
        // 处理解锁/锁定状态
        if (_card.isUnlocked)
        {
            // --- 分支 1: 已解锁 ---
            Switch_VisualUIState(true, false, _cardAttributeActionMode); // 切换到解锁布局
        }
        else
        {
            // --- 分支 2: 未解锁 ---
            Switch_VisualUIState(false, false, _cardAttributeActionMode); // 切换到锁定布局
        }

        // 确保可交互
        GetComponent<CanvasGroup>().alpha = 1.0f;
        GetComponent<CanvasGroup>().interactable = true;
    }

    // ==========================================
    // 3. 辅助组件方法与交互
    // ==========================================
    
    /// <summary>
    /// 【核心】核心状态切换机制
    /// 负责: 1.记录当前按钮功能状态, 2.控制显示容器开关, 3.若是战斗则同步血量与攻击
    /// </summary>
    /// <param name="_isUnlocked">true=显示战斗/解锁详情UI, false=显示未解锁UI</param>
    /// <param name="_isFight">是否有战斗状态的显隐标识</param>
    /// <param name="_cardAttributeActionMode">属性表动作模式</param>
    public void Switch_VisualUIState(bool _isUnlocked, bool _isFight, CardAttributeActionMode _cardAttributeActionMode)
    {
        // 记录此时状态
        cardAttributeActionMode = _cardAttributeActionMode;
        // 调整显示的对象
        Unlocked_UIContainer.SetActive(_isUnlocked);
        Locked_UIContainer.SetActive(!_isUnlocked);
        Unlocked_CareerType_Image.gameObject.SetActive(!_isFight);
        Unlocked_ElementType_Image.gameObject.SetActive(!_isFight);
        if (_isFight)
        {
            // 在战斗状态下显示
            Update_CardUI_HP(card.hp, card.SO_Card.hpMax, 0);   //(待改进)护盾值也要保存下来
            Update_CardUI_Atk(card.SO_Card.atk);
            //(待改进)缺少mana
        }
        else
        {
            if (_isUnlocked && Unlocked_UIContainer != null) // 已解锁
            {
                Unlocked_CareerType_Image.sprite = card.SO_Card.careerTypeImage;
                Unlocked_ElementType_Image.sprite = card.SO_Card.elementTypeImage;
                // 已解锁显示最大数值
                float Hp = card.SO_Card.hpMax;
                float Atk = card.SO_Card.atk; // 这里如果有成长系数需计算
                Update_CardUI_HP(Hp, card.SO_Card.hpMax, 0);
                Update_CardUI_Atk(Atk);
                CardMain_Img.color = Color.white; // 恢复原色
            }
            else if (!_isUnlocked && Locked_UIContainer != null) // 未解锁
            {
                // 显示一部分
                Locked_CareerType_Image.sprite = card.SO_Card.careerTypeImage;
                Locked_ElementType_Image.sprite = card.SO_Card.elementTypeImage;
                Lock_Cost_TMP.text = card.SO_Card.costG;
                CardMain_Img.color = Color.gray; // 变灰
            }
        }
    }

    /// <summary>
    /// 初始化基础卡牌形象UI
    /// 负责: 仅仅设定外壳资源框架, 如主图
    /// </summary>
    void Init_UI_CardFigure()
    {
        //设置图片
        CardMain_Img.sprite = card.SO_Card.cardImage;
        // //设置Mana条及上限
        // for (int i = 0; i < _SO_Card.manaMax; i++)
        // {
        //     //实例化并设置父对象为魔法条
        //     GameObject manaPrefab = Instantiate(Mana_Prefab, ManaBar_Prefab.transform);
        //     //默认没有蓝量
        //     // manaPrefab.SetActive(false);
        //     manaPrefab.name = "Mana" + i;
        //     manaPrefab.GetComponent<Image>().color = Color.black;

        //     //保存对象
        //     manaPrefabList.Add(manaPrefab);
        // }
    }
    /// <summary>
    /// 动态更新卡牌生命与护盾展示
    /// 负责: 1.计算当前与上限的屏占比, 2.通过公式将RectTransform做相应宽度拉伸渲染
    /// </summary>
    /// <param name="_hp">当前血量</param>
    /// <param name="_hpMax">上限血量</param>
    /// <param name="_dp">护盾点数</param>
    public void Update_CardUI_HP(float _hp, float _hpMax, float _dp)
    {
        //比例判断
        if (_hp + _dp > _hpMax)//大于1超过上限了
        {
            hpRatio = _hp / (_hp + _dp);
            dpRatio = _dp / (_hp + _dp);
        }
        else
        {
            hpRatio = _hp / _hpMax;
            dpRatio = _dp / _hpMax;
        }
        //将计算好的比例调入血量和护盾
        Debug.Log("血条比例:" + hpRatio);
        Vector2 temp_V2 = new Vector2(HPBar_Prefab.rect.width * Mathf.Clamp01(hpRatio), HPBar_Prefab.rect.height);
        HP_Prefab.sizeDelta = temp_V2;
        //将护盾UI移动到血量UI后面衔接
        temp_V2 = HP_Prefab.anchoredPosition;//获取血条基于锚点位置
        temp_V2 = new Vector2(temp_V2.x + HP_Prefab.sizeDelta.x, temp_V2.y);//将血条基于锚点的位置的x加上血条大小的x
        DP_Prefab.anchoredPosition = temp_V2;
        //设置护盾条ui比例
        DP_Prefab.sizeDelta = new Vector2(HPBar_Prefab.rect.width * Mathf.Clamp01(dpRatio), HPBar_Prefab.rect.height);

        //展示血量数值
        HP_TMP.text = (_hp+_dp).ToString();
    }
    /// <summary>
    /// 动态更新卡牌攻击力展示
    /// 负责: 更新数值UI显示
    /// </summary>
    /// <param name="_atk">传入当前攻击力</param>
    public void Update_CardUI_Atk(float _atk)
    {
        //展示Atk数值
        Atk_TMP.text = _atk.ToString();
    }

    /// <summary>
    /// 打开卡牌属性栏回调事件
    /// 负责: 备战席中点击打开属性展示子页面并传递自身引用
    /// </summary>
    public void OnBtn_CardAttribute()
    {
        // 
        Card_Attribute.Update_CardAttribute(card, cardAttributeActionMode);
    }

    /// <summary>
    /// 设置备战席卡牌可选状态
    /// 负责: 根据备战席统一判定结果刷新交互和显示
    /// </summary>
    /// <param name="_isSelectable">是否可选</param>
    public void Set_PrepareSelectable(bool _isSelectable)
    {
        CanvasGroup CanvasGroup = GetComponent<CanvasGroup>();
        if (CanvasGroup == null)
        {
            return;
        }

        CanvasGroup.alpha = _isSelectable ? 1.0f : 0.5f;
        CanvasGroup.interactable = _isSelectable;
    }
}
