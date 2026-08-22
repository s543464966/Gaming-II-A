using System.Collections;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class CC_Mall : MonoBehaviour
{
    // =========================================================
    // 1. 数据源与配置
    // =========================================================
    //获取数据中心
    private GameData GameData => DBCC_DataBase.Instance.GameData;   //GameData别名[因为单例原因]

    [Header("模块: UI结构引用")]
    [Tooltip("商品预制体")] public GameObject commodityPrefab; // 商品预制体
    [Tooltip("商品内容的Grid容器")] [SerializeField] private RectTransform commodityContent; // 商品内容的Grid容器

    [Header("模块: 用户资产UI显示区")]
    [Tooltip("金币数量")] [SerializeField] private TMP_Text TMP_GoldAmount; // 金币数量
    [Tooltip("星石数量")] [SerializeField] private TMP_Text TMP_StarStoneAmount; // 星石数量

    [Header("模块: 购买确认弹窗UI")]
    [Tooltip("购买确认弹窗节点")] [SerializeField] private GameObject panel_BuyConfirm; // 购买确认弹窗节点
    [Tooltip("确认提示说明")] [SerializeField] private TMP_Text TMP_ConfirmPrompt; // 确认提示说明
    [Tooltip("确认购买按钮")] [SerializeField] private Button Btn_ConfirmBuy; // 确认购买按钮
    [Tooltip("取消购买按钮")] [SerializeField] private Button Btn_CancelBuy; // 取消购买按钮

    [Header("模块: 布局配置")]
    [Tooltip("一行排布商品个数")] [SerializeField] private int columnsPerRow = 4; // 一行排布商品个数
    [Tooltip("保底渲染格子数，不足部分用空槽填充")] [SerializeField] private int minTotalSlots = 12; // 保底渲染格子数

    [Header("模块: 分类页签")]
    [Tooltip("推荐页签")] [SerializeField] private Button Btn_TabRecommend; // 推荐页签
    [Tooltip("英雄页签")] [SerializeField] private Button Btn_TabHero; // 英雄页签
    [Tooltip("随从页签")] [SerializeField] private Button Btn_TabMinion; // 随从页签
    [Tooltip("道具页签")] [SerializeField] private Button Btn_TabItem; // 道具页签

    [Header("模块: 详情显示区引用")]
    [Tooltip("卡牌类型商品详情的UI容器")] [SerializeField] private GameObject detailContainer_HeroCard; // 卡牌类型商品详情的UI容器
    [Tooltip("道具/骰子类型商品详情的UI容器")] [SerializeField] private GameObject detailContainer_Item; // 道具/骰子类型商品详情的UI容器
    [Tooltip("商品名字")] [SerializeField] private TMP_Text TMP_CommodityName; // 商品名字
    [Tooltip("商品信息")] [SerializeField] private TMP_Text TMP_CommodityInfo; // 商品信息
    [Tooltip("商品价格")] [SerializeField] private TMP_Text TMP_CommodityPrice; // 商品价格
    [Tooltip("商品主图")] [SerializeField] private Image Img_CommodityMain; // 商品主图
    [Tooltip("购买按钮")] [SerializeField] private Button Btn_Buy; // 购买按钮
    [Tooltip("正常边框图片")] [SerializeField] private Sprite normalBorderSprite; // 正常边框图片
    [Tooltip("选中的边框图片")] [SerializeField] private Sprite selectedBorderSprite; // 选中的边框图片

    // --- 内部状态 --- (对象池与交互信息)
    private List<C_Commodity> commodityPool = new List<C_Commodity>(); // 格子对象池
    private C_Commodity currentSelectedCommodityObj; // 当前选中的商品脚本对象
    private Commodity currentSelectedCommodityData; // 当前选中的商品数据
    private MallTabType currentTabType = MallTabType.Hero; // 当前选中的分类，默认英雄页签(先英雄演示)

    // ==========================================
    // 1. 初始化管理
    // ==========================================

    /// <summary>
    /// 每次实例被激活的时候执行
    /// 负责: 1.订阅用户资产变化, 2.刷新UI和初始化商城状态
    /// </summary>
    private void OnEnable()
    {
        Debug.Log("商城界面打开!");

        // 订阅用户资产刷新事件
        if (GameData != null && GameData.Sys_User != null)
        {
            GameData.Sys_User.OnGoldChanged += Refresh_GoldUI;
            GameData.Sys_User.OnStarStoneChanged += Refresh_StarStoneUI;

            // 首次打开立刻全量刷一次当前余额
            Refresh_GoldUI(GameData.Sys_User.gold);
            Refresh_StarStoneUI(GameData.Sys_User.starStone);
        }

        // 每次打开商城，重新刷新数据
        Update_MallUI();
        Update_CommodityDetail(null, null); // 清空详情

        Debug.Log("商城界面刷新完毕!");
    }

    /// <summary>
    /// 实例解除激活回调
    /// 负责: 退订事件, 防止内存泄漏和空引用异常
    /// </summary>
    private void OnDisable()
    {
        // 页面隐藏时退订事件，防止内存泄漏和空引用异常
        if (GameData != null && GameData.Sys_User != null)
        {
            GameData.Sys_User.OnGoldChanged -= Refresh_GoldUI;
            GameData.Sys_User.OnStarStoneChanged -= Refresh_StarStoneUI;
        }
    }

    // ==========================================
    // 2. 局部 UI 刷新逻辑
    // ==========================================
    
    /// <summary>
    /// 刷新金币显示
    /// 负责: 同步用户资产到UI文字
    /// </summary>
    /// <param name="goldAmount">当前金币量</param>
    private void Refresh_GoldUI(int goldAmount)
    {
        if (TMP_GoldAmount) TMP_GoldAmount.text = goldAmount.ToString();
    }

    /// <summary>
    /// 刷新星石显示
    /// 负责: 同步用户资产到UI文字
    /// </summary>
    /// <param name="starStoneAmount">当前星石量</param>
    private void Refresh_StarStoneUI(int starStoneAmount)
    {
        if (TMP_StarStoneAmount) TMP_StarStoneAmount.text = starStoneAmount.ToString();
    }

    /// <summary>
    /// 【核心】商城页面初始化
    /// 负责: 1.绑定4个页签的点击事件, 2.绑定购买事件, 3.清除开发期站位对象
    /// </summary>
    public void Init_PageMall()
    {
        // 绑定分类按钮事件
        if (Btn_TabRecommend) Btn_TabRecommend.onClick.AddListener(() => Switch_Tab(MallTabType.Recommend));
        if (Btn_TabHero) Btn_TabHero.onClick.AddListener(() => Switch_Tab(MallTabType.Hero));
        if (Btn_TabMinion) Btn_TabMinion.onClick.AddListener(() => Switch_Tab(MallTabType.Minion));
        if (Btn_TabItem) Btn_TabItem.onClick.AddListener(() => Switch_Tab(MallTabType.Item));

        // 绑定【点击购买】按钮弹出确认框
        if (Btn_Buy) Btn_Buy.onClick.AddListener(Show_BuyConfirmPanel);

        // 绑定弹窗内的【确认】与【取消】事件
        if (Btn_ConfirmBuy) Btn_ConfirmBuy.onClick.AddListener(OnBtn_Confirm_BuyCommodity);
        if (Btn_CancelBuy) Btn_CancelBuy.onClick.AddListener(OnBtn_Close_BuyConfirmPanel);

        // 确保弹窗默认关闭
        if (panel_BuyConfirm) panel_BuyConfirm.SetActive(false);

        // 清空开发时残留数据
        foreach (Transform child in commodityContent.transform)
        {
            Destroy(child.gameObject);
        }

        Debug.Log("完成商城页面初始化与清理");
    }

    /// <summary>
    /// 切换分类页签
    /// </summary>
    /// <param name="_tabType">目标商品类型(枚举)</param>
    public void Switch_Tab(MallTabType _tabType)
    {
        currentTabType = _tabType;

        // 切换分类时，取消当前选中
        // (如果有交互脚本，则取消选中态)
        currentSelectedCommodityObj = null;
        currentSelectedCommodityData = null;

        Update_MallUI(); // 重新渲染列表
        Update_CommodityDetail(null, null);
    }

    /// <summary>
    /// 【核心】手动刷新 UI（切换页签 / 购买成功后调用）
    /// 负责: 1.向逻辑层请求当前分类的大票数据, 2.计算出排版的格子总数, 3.拉伸对象池并填充
    /// </summary>
    public void Update_MallUI()
    {
        Debug.Log("正在刷新商城界面!");
        if (GameData.Sys_Mall == null) return;

        // 获取逻辑层经过筛选后的该分页下的商品数据列表
        List<Commodity> displayCommodities = GameData.Sys_Mall.Get_DisplayCommodities(currentTabType);

        Debug.Log($"[CC_Mall] Update_MallUI 触发。当前页签: {currentTabType}, 获取到商品数量: {displayCommodities.Count}");

        // 1. 计算格子逻辑
        int itemCount = displayCommodities.Count;
        // 使用您指定的类似 "每行4个" 规则：算出行数再乘列数，保证底部格子留白填满
        int slotsNeeded = Mathf.CeilToInt(itemCount / (float)columnsPerRow) * columnsPerRow;
        int finalCount = Mathf.Max(minTotalSlots, slotsNeeded);

        // 2. 准备格子 (对象池扩容)
        Adjust_CommodityPool(finalCount);

        // 3. 数据填装
        for (int i = 0; i < commodityPool.Count; i++)
        {
            C_Commodity commodityScript = commodityPool[i];

            if (i < finalCount)
            {
                commodityScript.gameObject.SetActive(true);
                // 填充逻辑：如果有商品数据，就把数据传给格子渲染；如果是占位空格子，就传空
                if (i < itemCount)
                {
                    commodityScript.Update_CommodityUI(displayCommodities[i]);
                }
                else
                {
                    commodityScript.Update_CommodityUI(null);
                }
            }
            else
            {
                // 超出的对象全部隐藏回收
                commodityScript.gameObject.SetActive(false);
            }
        }
    }

    /// <summary>
    /// 动态增减格子的实例 (对象池扩容)
    /// 负责: 根据容量需求实例化预设商品UI并绑定其引用的父级组件与边框贴图
    /// </summary>
    /// <param name="_count">目标需要补足的数量</param>
    private void Adjust_CommodityPool(int _count)
    {
        while (commodityPool.Count < _count)
        {
            GameObject commodityObj = Instantiate(commodityPrefab, commodityContent);
            C_Commodity script = commodityObj.GetComponent<C_Commodity>();

            if (script != null)
            {
                script.Init_Commodity(this, normalBorderSprite, selectedBorderSprite);
                commodityPool.Add(script);
            }
            else
            {
                Debug.LogError("严重错误:Commodity预制体上缺少 C_Commodity 脚本！");
                Destroy(commodityObj);
                break;
            }
        }
    }

    // ==========================================
    // 3. 交互响应区域
    // ==========================================

    /// <summary>
    /// 【供外部格子调用的选中回调】
    /// </summary>
    /// <param name="_clickedObj">发生点击的脚本对象</param>
    /// <param name="_itemData">该对象持有的商品数据</param>
    public void Clicked_Commodity(C_Commodity _clickedObj, Commodity _itemData)
    {
        // 1. 视觉切换逻辑
        if (currentSelectedCommodityObj != null)
        {
            currentSelectedCommodityObj.Set_SelectState(false);
        }

        currentSelectedCommodityObj = _clickedObj;
        currentSelectedCommodityData = _itemData;

        // 接着把刚记录的新对象设定为 selectedBorderSprite 边框高亮
        if (currentSelectedCommodityObj.commodity != null)
        {
            currentSelectedCommodityObj.Set_SelectState(true);
        }

        // 2. 刷新详情面板
        Update_CommodityDetail(_clickedObj, _itemData);
    }

    /// <summary>
    /// 更新详情区 UI 面板
    /// 负责: 1.根据传入参数显隐商品细节, 2.根据分类调度详情容器, 3.判断售罄与禁购状态
    /// </summary>
    /// <param name="_targetObj">选中的商品物体引用</param>
    /// <param name="_commodityData">选中的商品数据信息</param>
    private void Update_CommodityDetail(C_Commodity _targetObj, Commodity _commodityData)
    {
        // 若没有有效对象、或是点了空格子，清空面板
        if (_targetObj == null || _commodityData == null || _commodityData.SO_Commodity == null)
        {
            if (detailContainer_HeroCard) detailContainer_HeroCard.SetActive(false);
            if (detailContainer_Item) detailContainer_Item.SetActive(false);

            if (TMP_CommodityName) TMP_CommodityName.text = "";
            if (TMP_CommodityInfo) TMP_CommodityInfo.text = "暂无商品预览";
            if (TMP_CommodityPrice) TMP_CommodityPrice.text = "";
            if (Img_CommodityMain) Img_CommodityMain.gameObject.SetActive(false);
            if (Btn_Buy) Btn_Buy.interactable = false;
        }
        else
        {
            // 根据商品类型激活对应的详情容器
            switch (_commodityData.SO_Commodity.tabType)
            {
                case MallTabType.Hero:
                case MallTabType.Minion:
                    if (detailContainer_HeroCard) detailContainer_HeroCard.SetActive(true);
                    if (detailContainer_Item) detailContainer_Item.SetActive(false);
                    break;
                case MallTabType.Item:
                default:
                    if (detailContainer_HeroCard) detailContainer_HeroCard.SetActive(false);
                    if (detailContainer_Item) detailContainer_Item.SetActive(true);
                    break;
            }

            // 商品详情正常拼装显示
            if (TMP_CommodityName) TMP_CommodityName.text = _commodityData.commodityName;
            if (TMP_CommodityInfo) TMP_CommodityInfo.text = "内含物:" + _commodityData.SO_Commodity.rewardId + "\r\n数量:" + _commodityData.SO_Commodity.rewardAmount;
            if (TMP_CommodityPrice) TMP_CommodityPrice.text = _commodityData.GetFinalPrice().ToString();

            // 头像部分
            if (Img_CommodityMain)
            {
                Img_CommodityMain.gameObject.SetActive(true);
                Img_CommodityMain.sprite = _commodityData.commoditySprite;
            }

            // 是否打折或者已售罄 (控制是否允许购买，或者变灰按钮)
            if (Btn_Buy)
            {
                Btn_Buy.interactable = !_commodityData.IsSoldOut;
            }
        }
    }

    // ==========================================
    // 4. 购买与确认弹窗逻辑
    // ==========================================

    /// <summary>
    /// 【核心】显示确认购买弹窗 (弹窗第一阶段)
    /// 负责: 唤起防呆二次确认界面并组装提示价格文本
    /// </summary>
    public void Show_BuyConfirmPanel()
    {
        if (currentSelectedCommodityData == null)
        {
            Debug.LogWarning("未选中有效商品，无法发起买单");
            return;
        }

        if (panel_BuyConfirm)
        {
            panel_BuyConfirm.SetActive(true);

            // 拼接提示文本 (列如: "确定要花费 500 金币 购买 英雄召唤券 吗？")
            if (TMP_ConfirmPrompt != null)
            {
                TMP_ConfirmPrompt.text = $"确定要花费 {currentSelectedCommodityData.GetFinalPrice()} {currentSelectedCommodityData.SO_Commodity.currencyType}\r\n购买 {currentSelectedCommodityData.commodityName} 吗？";
            }
        }
        else
        {
            Debug.LogError("[严重异常] panel_BuyConfirm 确认弹窗未配置！为了防止偷扣玩家资产，已拦截此次购买请求。请检查 CC_Mall 上的 Inspector 引用！");
        }
    }

    /// <summary>
    /// 关闭购买确认弹窗
    /// 负责: 隐藏确认二级菜单
    /// </summary>
    public void OnBtn_Close_BuyConfirmPanel()
    {
        if (panel_BuyConfirm) panel_BuyConfirm.SetActive(false);
    }

    /// <summary>
    /// 【核心】【弹窗第二阶段】：点击确认购买，发起交易
    /// 负责: 1.发送买单指令到逻辑层, 2.处理回包, 3.关闭弹窗并刷新UI
    /// </summary>
    public void OnBtn_Confirm_BuyCommodity()
    {
        if (currentSelectedCommodityData == null) return;

        string orderId = currentSelectedCommodityData.SO_Commodity.commodityId;

        // 【核心跨模块】：将购买指令传给 Sys_Mall 逻辑层进行资产扣除和商品发货
        MallBuyResult result = GameData.Sys_Mall.Buy_Commodity(orderId);
        // 这里可以通过购买的返回情况制作不同的UI显示提示
        if (result == MallBuyResult.Success)
        {
            Debug.Log($"[商城] 成功购入商品: {orderId} !");

            // 关闭弹窗
            OnBtn_Close_BuyConfirmPanel();

            // 【连通更新】: 购买成功后，立即让商城刷新整个 UI 列表和详情面板(反映剩余次数/灰显售罄遮罩)
            Update_MallUI();
            Update_CommodityDetail(currentSelectedCommodityObj, currentSelectedCommodityData);
        }
        else
        {
            Debug.LogWarning($"[商城] 买单失败! 错误码: {result}");

            // 如果余额不足，可以把弹窗内容改掉震动一下，或者关闭直接飘字
            if (TMP_ConfirmPrompt != null)
            {
                TMP_ConfirmPrompt.text = $"<color=red>购买失败: 余额不足或售罄 ({result})</color>";
            }
            else
            {
                OnBtn_Close_BuyConfirmPanel();
            }
        }
    }
}
