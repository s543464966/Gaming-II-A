using UnityEngine;
using UnityEngine.UI;
using TMPro;

public class C_Commodity : MonoBehaviour
{
    [Tooltip("持久化数据")]
    public Commodity commodity { get; private set; }

    [Header("模块: UI引用")]
    [Tooltip("商品按钮")] [SerializeField] private Button Btn_Commodity; // 商品按钮
    [Tooltip("购买按钮")] [SerializeField] private Button Btn_Buy; // 购买按钮
    [Tooltip("商品图标")] [SerializeField] private Image Img_CommodityIcon; // 商品图标
    [Tooltip("货币类型图标")] [SerializeField] private Image Img_CurrencyType; // 货币类型图标
    [Tooltip("商品标题文字")] [SerializeField] private TMP_Text TMP_CommodityName; // 商品标题文字
    [Tooltip("商品价格文字")] [SerializeField] private TMP_Text TMP_CommodityPrice; // 商品价格文字
    [Tooltip("售罄遮罩")] [SerializeField] private GameObject soldOutOverlay; // 售罄遮罩

    [Header("模块: 动态分类容器")]
    [Tooltip("卡牌类型商品显示的UI容器")] [SerializeField] private GameObject container_HeroCard; // 卡牌类型商品显示的UI容器
    [Tooltip("道具/骰子类型商品显示的UI容器")] [SerializeField] private GameObject container_Item; // 道具/骰子类型商品显示的UI容器

    [Header("模块: 选中态组件配置")]
    [Tooltip("选中高亮框图对象")] [SerializeField] private Image Img_CommodityBorder; // 选中高亮框图对象
    
    // --- 内部状态 --- (UI纹理缓存与组件引用)
    private Sprite normalSprite; // 正常态边框贴图
    private Sprite selectedSprite; // 选中态边框贴图
    private CC_Mall CC_Mall; // 强引用：我的管理者

    // ----------------------------------------------------------------------------------------------------------

    // ==========================================
    // 1. 初始化分配 (Initial)
    // ==========================================

    /// <summary>
    /// 【核心】初始化商品UI组件
    /// 负责: 绑定父级Mall引用及预设框图资源, 并初始化为未选中态
    /// </summary>
    /// <param name="_CC_Mall">商场父级组件</param>
    /// <param name="_normalBorderSprite">普通态边框贴图</param>
    /// <param name="_selectedBorderSprite">选中态边框贴图</param>
    public void Init_Commodity(CC_Mall _CC_Mall, Sprite _normalBorderSprite, Sprite _selectedBorderSprite)
    {
        CC_Mall = _CC_Mall;
        normalSprite = _normalBorderSprite;
        selectedSprite = _selectedBorderSprite;
        Set_SelectState(false);
        
    }

    // ==========================================
    // 2. 状态刷新与填充 (Update)
    // ==========================================

    /// <summary>
    /// 【核心】刷新商品格子UI内容
    /// 负责: 1.更新持有数据, 2.分类容器调度和图标名称装填, 3.处理价格和售罄逻辑
    /// </summary>
    /// <param name="_commodity">商品基本数据结构体</param>
    public void Update_CommodityUI(Commodity _commodity)
    {
        commodity = _commodity;   // 更新当前持有的数据

        if (_commodity == null || _commodity.SO_Commodity == null)
        {
            // --- 空格子状态 ---
            if (container_HeroCard) container_HeroCard.SetActive(false);
            if (container_Item) container_Item.SetActive(false);

            if (Img_CommodityIcon) Img_CommodityIcon.gameObject.SetActive(false);
            if (Img_CurrencyType) Img_CurrencyType.gameObject.SetActive(false);
            
            if (TMP_CommodityName) TMP_CommodityName.text = "";
            if (TMP_CommodityPrice) TMP_CommodityPrice.text = "";
            if (soldOutOverlay) soldOutOverlay.SetActive(false);
            if (Btn_Commodity) Btn_Commodity.interactable = false;
            if (Btn_Buy) Btn_Buy.interactable = false;
        }
        else
        {
            // --- 有商品状态 ---

            // 根据商品类型激活对应的容器 (使用 switch-case 泛化)
            switch (_commodity.SO_Commodity.tabType)
            {
                case MallTabType.Hero:
                    if (container_HeroCard) container_HeroCard.SetActive(true);
                    if (container_Item) container_Item.SetActive(false);
                    break;
                case MallTabType.Minion:
                    // 未来可以增加: if (container_Dice) container_Dice.SetActive(false);
                    if (container_HeroCard) container_HeroCard.SetActive(true);
                    if (container_Item) container_Item.SetActive(false);
                    break;
                case MallTabType.Item:
                // case MallTabType.Dice: // 当添加骰子枚举后可以在这里展开
                default:
                    if (container_HeroCard) container_HeroCard.SetActive(false);
                    if (container_Item) container_Item.SetActive(false);
                    break;
            }

            if (Img_CommodityIcon)
            {
                Img_CommodityIcon.gameObject.SetActive(true);
                Img_CommodityIcon.sprite = _commodity.commoditySprite;
            }

            if (TMP_CommodityName) TMP_CommodityName.text = _commodity.commodityName;

            if (TMP_CommodityPrice) TMP_CommodityPrice.text = _commodity.GetFinalPrice().ToString();

            // 售罄与打折状态表现
            if (soldOutOverlay) soldOutOverlay.SetActive(_commodity.IsSoldOut);
            if (Img_CurrencyType) Img_CurrencyType.gameObject.SetActive(true);
            // 购买货币类型

            // 如果已售罄，则不允许点击（或者允许点击看详情，但商城Buy单那里做了校验，这里看您的设计，暂且允许点击看详情）
            if (Btn_Commodity) Btn_Commodity.interactable = true;
            if (Btn_Buy) Btn_Buy.interactable = true;
        }
    }

    // ==========================================
    // 3. UI 交互接口与回调 (Interaction)
    // ==========================================

    /// <summary>
    /// 设置选中高亮发光状态
    /// 负责: 根据布尔参数切换底图样式
    /// </summary>
    /// <param name="_isSelected">是否进入选中状态</param>
    public void Set_SelectState(bool _isSelected)
    {
        if (Img_CommodityBorder != null)
        {
            Img_CommodityBorder.sprite = _isSelected ? selectedSprite : normalSprite;
        }
    }

    /// <summary>
    /// 格子实体点击回调事件
    /// 负责: 把自身的选择信息推送到商城管理者集中处理
    /// </summary>
    public void OnBtn_CommodityClicked()
    {
        // 直接调用控制器的公开方法
        if (CC_Mall != null)
        {
            CC_Mall.Clicked_Commodity(this, commodity);
        }
    }
    /// <summary>
    /// 直接点击购买的回调
    /// 负责: 通知管理台不仅选中且立刻唤起付费二级面板
    /// </summary>
    public void OnBtn_BuyClicked()
    {
        // 直接调用控制器的公开方法
        if (CC_Mall != null)
        {
            CC_Mall.Clicked_Commodity(this, commodity);
            CC_Mall.Show_BuyConfirmPanel();
        }
    }
}
