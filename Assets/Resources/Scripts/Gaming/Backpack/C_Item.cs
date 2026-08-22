using UnityEngine;
using UnityEngine.UI;
using TMPro;
using System;

public class C_Item : MonoBehaviour
{
    [Header("模块: 基础数据组件")]
    [Tooltip("物品按钮")] [SerializeField] private Button Btn_Item; // 物品按钮
    [Tooltip("物品图片")] [SerializeField] private Image Img_Item; // 物品图片
    [Tooltip("物品数量")] [SerializeField] private TMP_Text TMP_Count; // 物品数量
    [Tooltip("选中效果对象")] [SerializeField] private GameObject selectObj; // 选中效果对象
    [Tooltip("持有数据")] public Item item { get; private set; } // 持有数据
    [Header("模块: 选中态配置")]
    [Tooltip("边框图片的Image组件")] [SerializeField] private Image Img_ItemBorder; // 边框图片的Image组件
    
    // --- 内部状态 --- (UI纹理与单例)
    private Sprite normalSprite; // 普通状态的边框图
    private Sprite selectedSprite; // 选中高亮的边框图
    private CC_Backpack CC_Backpack; // 强引用: 我的管理者
    
    // ==========================================
    // 1. 初始化 (Initial)
    // ==========================================

    /// <summary>
    /// 【核心】初始化格子数据
    /// 负责: 绑定背包装配系统并初始化未选中状态的视觉
    /// </summary>
    /// <param name="_CC_Backpack">背包管理者</param>
    /// <param name="_NormalBorderSprite">正常边框切图</param>
    /// <param name="_SelectedBorderSprite">高亮边框切图</param>
    public void Init_Item(CC_Backpack _CC_Backpack,Sprite _NormalBorderSprite,Sprite _SelectedBorderSprite)
    {
        CC_Backpack = _CC_Backpack;
        normalSprite = _NormalBorderSprite;
        selectedSprite = _SelectedBorderSprite;
        Set_SelectState(false);
    }
    // ==========================================
    // 2. 界面更新 (UI Update)
    // ==========================================
    
    /// <summary>
    /// 【核心】刷新Item格子UI内容
    /// 负责: 根据背包系统分发的道具数据渲染图标、数量, 或者重置为空白状态
    /// </summary>
    /// <param name="_Item">需要渲染的格子数据</param>
    public void Update_ItemUI(Item _Item)
    {
        item = _Item;   // 更新当前持有的数据
        if (_Item == null || _Item.SO_Item == null) //(默认空格子的UI)
        {
            // --- 空格子状态 ---
            Img_Item.gameObject.SetActive(false);   //把图标的显示变为false
            TMP_Count.text = "";
            Btn_Item.interactable = false; 
        }
        else
        {
            // --- 有物品状态 ---
            Img_Item.gameObject.SetActive(true);
            Img_Item.sprite = item.SO_Item.itemSprite;
            // 直接显示 data 里的数量，因为这是 Sys_Inventory 处理过的临时对象
            // 数量大于1才显示
            TMP_Count.text = item.itemCount > 1 ? item.itemCount.ToString() : "";
            Btn_Item.interactable = true;
        }
    }
    // ==========================================
    // 3. 选中态交互 (Select State)
    // ==========================================
    
    /// <summary>
    /// 设置选中状态
    /// 负责: 更换 Sprite 以展现选中反馈
    /// </summary>
    /// <param name="_isSelected">是否被选中</param>
    public void Set_SelectState(bool _isSelected)
    {
        if (Img_ItemBorder != null)
        {
            // 如果选中，用高亮图；否则用普通图
            Img_ItemBorder.sprite = _isSelected ? selectedSprite : normalSprite;
        }
    }
    // ==========================================
    // 4. 事件回调 (Event Callback)
    // ==========================================
    
    /// <summary>
    /// 点击格子回调
    /// 负责: 触发按钮点击并把当前格子回传给管理者中心处理交互
    /// </summary>
    public void OnBtn_ItemClicked() // 点击自身时触发
    {
        // 直接调用控制器的公开方法，告诉它 "我被点了"
        if (CC_Backpack != null)
        {
            CC_Backpack.Clicked_Item(this);
        }
    }
}
