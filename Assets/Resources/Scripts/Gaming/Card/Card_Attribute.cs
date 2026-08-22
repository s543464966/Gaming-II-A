using System.Collections.Generic;
using System.Linq;
using DG.Tweening;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class Card_Attribute : MonoBehaviour
{
    //======UI对象======//
    [Header("模块: UI - 界面")]
    [Tooltip("卡牌形象主图")] public Image CardMain_Img; // 卡牌形象主图
    [Tooltip("卡牌边框图")] public Image CardBorder_Img; // 卡牌边框图
    [Tooltip("卡牌名字")] public TMP_Text CardName_TMP; // 卡牌名字
    [Tooltip("攻击类型图")] public Image CardAttackBar_Img; // 卡牌攻击类型图
    [Tooltip("攻击力数值")] public TMP_Text Atk_TMP; // 攻击力数值展示
    [Tooltip("生命条预制体")] public RectTransform HPBar_Prefab; // 血条Transform
    [Tooltip("生命预制体")] public RectTransform HP_Prefab; // 血量Transform
    [Tooltip("生命值数值展示")] public TMP_Text HP_TMP; // 生命值数值展示
    [Tooltip("护盾预制体")] public RectTransform DP_Prefab; // 护盾Transform
    [Tooltip("Mana条预制体")] public GameObject ManaBar_Prefab; // Mana条对象
    [Tooltip("Mana预制体")] public GameObject Mana_Prefab; // Mana预制体
    [Tooltip("按钮功能名称显示")] public TMP_Text TMP_FunctionName; // 按钮功能名称显示
    [Tooltip("数量花费显示")] public TMP_Text TMP_SpeedCount; // 数量花费显示

    // --- 内部状态 --- (数据支撑)
    private float hpRatio; // 生命比例
    private float dpRatio; // 护盾比例
    private Card card; // 当前卡牌的SO
    private CardAttributeActionMode cardAttributeActionMode = CardAttributeActionMode.Buy; // 当前属性表动作模式

    [Header("模块: 控制按钮")]
    [Tooltip("主按钮")] public Button btn_BuyIntensifyFightingReplace; // 主按钮
    [Tooltip("购买按钮的图片精灵")] public Sprite img_Buy; // 购买按钮的图片精灵
    [Tooltip("出战按钮的图片精灵")] public Sprite img_IntensifyFightingReplace; // 出战按钮的图片精灵

    [Header("模块: 控制器引用")]
    [Tooltip("关卡管理脚本")] public CC_Conflict CC_Conflict; // 关卡管理脚本
    [Tooltip("卡牌图鉴脚本")] public CC_Card CC_Card; // 卡牌图鉴脚本

    // ----------------------------------------------------------------------------------------------------------

    // ==========================================
    // 1. 核心属性更新 (Update Attributes)
    // ==========================================
    
    /// <summary>
    /// 【核心】更新卡牌属性表UI内容
    /// 负责: 1.同步基础图文与交互数据, 2.分流在战斗模式或主页模式下的血量UI上限显示机制
    /// </summary>
    /// <param name="_card">卡牌的逻辑数据类</param>
    public void Update_CardAttribute(Card _card, CardAttributeActionMode _cardAttributeActionMode)
    {
        //显示CardAttribution的UI页面
        if (gameObject.activeSelf == false) gameObject.SetActive(true);

        //保存当前卡牌属性按钮状态
        card = _card;
        cardAttributeActionMode = _cardAttributeActionMode;

        //更新所有UI数据
        CardMain_Img.sprite = _card.SO_Card.cardImage;
        CardName_TMP.text = _card.SO_Card.cardName;
        Update_CardUI_Atk(_card.SO_Card.atk);

        // 按动作模式分流血量显示
        bool isBattleMode = cardAttributeActionMode == CardAttributeActionMode.Deploy ||
                            cardAttributeActionMode == CardAttributeActionMode.ConfirmReplace ||
                            cardAttributeActionMode == CardAttributeActionMode.SelectReplace;
        float displayHP;
        if (isBattleMode)
        {
            // 战斗中：显示当前实际血量
            displayHP = _card.hp;
        }
        else
        {
            // 主页/图鉴中：显示满血预览 (上限)
            displayHP = _card.SO_Card.hpMax;
        }
        Update_CardUI_HP(displayHP,_card.SO_Card.hpMax,0);   //(待改进)护盾值
        
        //(待改进)缺少mana

        //更新当前按钮UI
        Update_ButtonUI();
    }
    /// <summary>
    /// 更新属性表主按钮视图
    /// 负责: 根据动作模式更新底部确认按钮的图标与文字描述
    /// </summary>
    void Update_ButtonUI()
    {
        switch (cardAttributeActionMode)
        {
            case CardAttributeActionMode.Buy: // 购买 (主页-未解锁)
                btn_BuyIntensifyFightingReplace.image.sprite = img_IntensifyFightingReplace;
                // 可以在这里设置按钮文字为 "购买 $100"
                TMP_FunctionName.text = "购买";
                TMP_SpeedCount.text = card.SO_Card.costG;
                break;
            case CardAttributeActionMode.Intensify: // 强化 (主页-已解锁)
                btn_BuyIntensifyFightingReplace.image.sprite = img_IntensifyFightingReplace;
                TMP_FunctionName.text = "强化";
                TMP_SpeedCount.text = string.Empty;
                break;
            case CardAttributeActionMode.Deploy: // 出战 (战斗-备战)
                btn_BuyIntensifyFightingReplace.image.sprite = img_IntensifyFightingReplace;
                TMP_FunctionName.text = "出战";
                TMP_SpeedCount.text = string.Empty;
                break;
            case CardAttributeActionMode.ConfirmReplace: // 确认替换 (战斗-备战席候选卡)
                btn_BuyIntensifyFightingReplace.image.sprite = img_IntensifyFightingReplace;
                TMP_FunctionName.text = "确认替换";
                TMP_SpeedCount.text = string.Empty;
                break;
            case CardAttributeActionMode.SelectReplace: // 选择替换 (战斗-已出战卡)
                btn_BuyIntensifyFightingReplace.image.sprite = img_IntensifyFightingReplace;
                TMP_FunctionName.text = "选择替换";
                TMP_SpeedCount.text = string.Empty;
                break;
        }
    }
    // ==========================================
    // 2. 数值面板填充逻辑 (Fill UI Data)
    // ==========================================

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
    // ==========================================
    // 3. 交互方法与回调机制 (Interaction Callbacks)
    // ==========================================

    /// <summary>
    /// 取消或关闭面板回调
    /// 负责: 隐藏整个详情属性预制体, 并重置备战席的逻辑环境
    /// </summary>
    public void OnCancelButton()
    {
        gameObject.SetActive(false);
    }
    
    /// <summary>
    /// 主功能确认回调
    /// 负责: 根据当前动作模式处理购买 / 强化 / 出战 / 替换等综合业务
    /// </summary>
    public void OnBtn_BuyIntensifyFightingReplace()
    {
        switch (cardAttributeActionMode)
        {
            case CardAttributeActionMode.Buy: //购买
                //  后续调用结算系统，卡牌系统新增卡牌，卡牌UI显示系统刷新最新UI数据
                break;
                
            case CardAttributeActionMode.Intensify: //强化
                //  调用结算系统，卡牌数据系统，卡牌UI显示系统
                break;
            case CardAttributeActionMode.Deploy: //出战
                if (CC_Conflict != null)
                {
                    CC_Conflict.Conflict_Prepare.Commit_SelectedCard(card);
                }
                gameObject.SetActive(false);
                break;
            case CardAttributeActionMode.ConfirmReplace: //确认替换
                if (CC_Conflict != null)
                {
                    CC_Conflict.Conflict_Prepare.Commit_SelectedCard(card);
                }
                gameObject.SetActive(false);
                break;
            case CardAttributeActionMode.SelectReplace: //选择替换
                if (CC_Conflict != null && card != null)
                {
                    CC_Conflict.Conflict_Prepare.Open_ReplacePrepare(card.posIndex);
                }
                gameObject.SetActive(false);
                break;
        }
    }
}
