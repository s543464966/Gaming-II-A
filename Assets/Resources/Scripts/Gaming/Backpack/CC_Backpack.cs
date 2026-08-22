using System.Collections;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class CC_Backpack: MonoBehaviour//静态类仓库可以在任何场景里直接调用
{   
    // =========================================================
    // 1. 数据源与配置
    // =========================================================
    //获取数据中心
    private GameData GameData => DBCC_DataBase.Instance.GameData; // GameData别名[因为单例原因]
    [Header("模块: 格子配置")]
    [Tooltip("格子预制体")] public GameObject item_Prefab; // 格子预制体
    [Tooltip("内容")] [SerializeField] private RectTransform itemContent; // 内容
    [Header("模块: 布局配置")]
    [Tooltip("最小视图格子限制")] [SerializeField] private int minTotalSlots = 30; // 最小视图格子限制
    [Tooltip("每行个数")] [SerializeField] private int columnsPerRow = 6; // 每行个数
    [Header("模块: 分类页签")]
    [Tooltip("显示全部按钮")] [SerializeField] private Button Btn_ViewAll; // 显示全部按钮
    [Tooltip("显示材料按钮")] [SerializeField] private Button Btn_ViewMaterial; // 显示材料按钮
    [Tooltip("显示道具按钮")] [SerializeField] private Button Btn_ViewProp; // 显示道具按钮

    [Header("模块: 详情显示区引用")]
    [Tooltip("物品名称")] [SerializeField] private TMP_Text TMP_ItemName; // 物品名称
    [Tooltip("物品描述")] [SerializeField] private TMP_Text TMP_ItemInfo; // 物品描述
    [Tooltip("详情区的大图")] [SerializeField] private Image Img_ItemMain; // 详情区的大图 (可选)
    [Tooltip("正常边框的图片资源")] [SerializeField] private Sprite NormalBorderSprite; // 正常边框的图片资源
    [Tooltip("被选择的图片资源")] [SerializeField] private Sprite SelectedBorderSprite; // 被选择的图片资源
    [Tooltip("默认提示文本")] [SerializeField] private string defaultTip = "请选择一个物品"; // 默认提示文本

    // ==========================================
    // 2. 内部缓存 (对象池)
    // ==========================================
    // --- 内部状态 --- (对象与分类池)
    private List<C_Item> itemPool = new List<C_Item>(); // 缓存对象池
    private C_Item currentSelectedItem; // 当前选中的那个格子脚本
    private ItemType currentItemType = ItemType.None; // 当前选中的分类
    
    // ==========================================
    // 3. 生命周期与初始化 (Lifecycle & Init)
    // ==========================================
    
    private void OnEnable() // 每次实例被激活的时候更新UI
    {
        // 每次打开背包，重新刷新数据
        Update_BackpackUI();
        Update_ItemDetail(null); // 清空详情
    }
    /// <summary>
    /// 【核心】初始化仓库界面
    /// 负责: 1.绑定分类按钮事件, 2.清除开发时残留节点
    /// </summary>
    public void Init_PageBackPack() // 初始化仓库界面
    {
        // 绑定分类按钮事件
        Btn_ViewAll.onClick.AddListener(() => Switch_Type(ItemType.None));
        Btn_ViewMaterial.onClick.AddListener(() => Switch_Type(ItemType.Material));
        Btn_ViewProp.onClick.AddListener(() => Switch_Type(ItemType.Prop));
        
        foreach(Transform child in itemContent.transform)
        {
            Destroy(child.gameObject);
        }
        Debug.Log("仓库开发时残留对象清除!");
    }
    // ==========================================
    // 4. 业务方法 (Business Logic)
    // ==========================================
    
    /// <summary>
    /// 【核心】切换分类
    /// 负责: 1.修改当前选中分类, 2.取消当前选中物品高亮, 3.重新渲染列表并清空详情
    /// </summary>
    /// <param name="_ItemType">要切换到的物品分类</param>
    public void Switch_Type(ItemType _ItemType)
    {
        currentItemType = _ItemType;
        
        // 切换分类时，取消当前选中
        if (currentSelectedItem != null) 
            currentSelectedItem.Set_SelectState(false);
        currentSelectedItem = null; //重置
        
        Update_BackpackUI(); // 重新渲染列表
        Update_ItemDetail(null);
    }
    /// <summary>
    /// 【核心】更新背包UI展示
    /// 负责: 1.计算分类后的需求格子数量, 2.按需扩充对象池, 3.遍历填装数据渲染
    /// </summary>
    public void Update_BackpackUI() // 手动刷新 UI (当你在逻辑层 AddItem 或 RemoveItem 后调用此方法)
    {
        if (GameData.Sys_Inventory == null) return;

        // 获取经过【筛选】和【拆分】后的 UI 数据列表
        // 传入需要显示物品类型的UI显示表
        List<Item> displayItems = GameData.Sys_Inventory.Get_DisplayItemList(currentItemType); 
        
        // 1. 计算格子逻辑
        int itemCount = displayItems.Count;
        // 计算公式：(数量 / 6) 向上取整 * 6
        int slotsNeeded = Mathf.CeilToInt(itemCount / (float)columnsPerRow) * columnsPerRow;
        // 最小视图限制
        int finalCount = Mathf.Max(minTotalSlots, slotsNeeded); 

        // 2. 准备格子 (对象池化处理)
        Adjust_ItemPool(finalCount);

        // 3. 数据填装
        for (int i = 0; i < itemPool.Count; i++)
        {
            C_Item C_Item = itemPool[i];    //拿到第x个格子
            if (i < finalCount)  //修改要显示的格子具体怎么显示
            {
                C_Item.gameObject.SetActive(true);
                // 填充逻辑：如果有物品则传数据，没有则传 null
                if (i < itemCount)
                {
                    // 有物品：填入数据
                    C_Item.Update_ItemUI(displayItems[i]);
                }
                else
                {
                    // 没物品（补齐的空格子）：填入 null(保留默认空格子的UI)
                    C_Item.Update_ItemUI(null);
                }
            }
            else    //不符合要显示的格子就取消显示
            {
                C_Item.gameObject.SetActive(false);
            }
        }
    }
    /// <summary>
    /// 动态增减格子的实例 (对象池扩容)
    /// 负责: 当对象池内容不足时, 实例化新预制体补充并初始化组件
    /// </summary>
    /// <param name="_count">目标保底数量</param>
    private void Adjust_ItemPool(int _count)
    {
        // while 循环会一直执行，直到 List 长度达标
        while (itemPool.Count < _count)
        {
            // 1. 生成
            GameObject Item_Obj = Instantiate(item_Prefab, itemContent);
            // 2. 获取脚本 (昂贵操作，只在生成时做一次)
            C_Item itemScript = Item_Obj.GetComponent<C_Item>();
            
            if (itemScript != null)
            {
                // 3. 初始化并存入列表
                itemScript.Init_Item(this, NormalBorderSprite, SelectedBorderSprite);
                itemPool.Add(itemScript); 
            }
            else
            {
                Debug.LogError("严重错误：Item预制体上缺少 C_Item 脚本！");
                Destroy(Item_Obj); // 删掉错误的物体防止报错
                break; // 强制退出防止死循环
            }
        }
    }
    // ==========================================
    // 5. 交互响应区域 (Interaction)
    // ==========================================
    
    /// <summary>
    /// 物品格子被点击时的回调
    /// 负责: 1.切换视觉高亮反馈, 2.刷新右侧详情面板显示内容
    /// </summary>
    /// <param name="_ClickedItem">被点击的物品格子引用</param>
    public void Clicked_Item(C_Item _ClickedItem)
    {
        // 1. 视觉切换逻辑
        // 如果之前有选中的，先把它的框变回普通
        if (currentSelectedItem != null)
        {
            currentSelectedItem.Set_SelectState(false);
        }

        // 记录新的选中，并变更为高亮框
        currentSelectedItem = _ClickedItem;
        currentSelectedItem.Set_SelectState(true);

        // 2. 刷新详情面板
        Update_ItemDetail(_ClickedItem.item);
    }
    /// <summary>
    /// 更新详情区 UI
    /// 负责: 在侧边栏展示选中物品的图文信息, 若无数据则显示默认文本
    /// </summary>
    /// <param name="_item">目标物品数据</param>
    private void Update_ItemDetail(Item _item) // 更新详情区 UI
    {
        if (_item == null || _item.SO_Item == null)
        {
            // 没有选中物品时
            TMP_ItemName.text = "";
            TMP_ItemInfo.text = "请选择一个物品"; // 默认提示
            if (Img_ItemMain) Img_ItemMain.gameObject.SetActive(false);
            // 如果你想把整个面板隐藏: detailPanel.SetActive(false);
        }
        else
        {
            // 选中了物品
            // detailPanel.SetActive(true);
            TMP_ItemName.text = _item.SO_Item.itemName;
            TMP_ItemInfo.text = _item.SO_Item.info;
            
            if (Img_ItemMain) 
            {
                Img_ItemMain.gameObject.SetActive(true);
                Img_ItemMain.sprite = _item.SO_Item.itemSprite;
            }
        }
    }
}
