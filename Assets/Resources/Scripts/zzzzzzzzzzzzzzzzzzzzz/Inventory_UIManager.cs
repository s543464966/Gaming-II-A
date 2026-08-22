using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.UI;

public class Inventory_UIManager : MonoBehaviour
{
    public GridLayoutGroup gridLayoutGroup;//网格布局组件
    public GameObject itemUIFramePrefab; // 物品UIFrame预制体

    // public RectTransform inventoryPanel;//仓库UI的位置
    // public float moveSpeed = 50f;//移动速度
    // //public float minY;
    // public float targetYOffset = 200f;//面板Y轴移动偏移量

    // private bool isInventoryUIMoving = false;
    // private Vector2 originalUIPosition;//仓库的起始位置引用
    // private Vector2 targetUIPosition;//目标位置的引用

    public RectTransform inventoryPageOriginPosition;//仓库页面的起始位置
    private Vector2 temp;//记录起始位置值
    public float movingLimit;//限制移动的距离

    void Start()
    {
        //记录仓库起始位置
        //originalUIPosition = inventoryPanel.anchoredPosition;

        temp = inventoryPageOriginPosition.anchoredPosition;//记录初始值
        // 计算仓库面板的目标位置
        // targetUIPosition = originalUIPosition + new Vector2(0f, targetYOffset);
        // Debug.Log("目标位置计算完毕");
        
    }
    void Update()
    {
        //不移动了
        // //向上移动
        // if(isInventoryUIMoving && inventoryPanel.anchoredPosition.y < targetUIPosition.y)
        // {
        //     //Debug.Log(isInventoryUIMoving);
        //     //Debug.Log("正在向上移动");
        //     // 计算面板的新位置
        //     float newY = Mathf.Clamp(inventoryPanel.anchoredPosition.y + moveSpeed * Time.deltaTime, originalUIPosition.y, targetUIPosition.y);
        //     Vector2 newPosition = new Vector2(inventoryPanel.anchoredPosition.x, newY);

        //     // 设置面板的新位置
        //     inventoryPanel.anchoredPosition = newPosition;
            
        //     // 到达终点后停止移动
        //     // if (newY == targetUIPosition.y)
        //     // {
        //     //     isInventoryUIMoving = false;
        //     // }

        //     // // 计算面板的新位置
        //     // float newY = inventoryPanel.anchoredPosition.y + moveSpeed * Time.deltaTime;
        //     // Vector2 newPosition = new Vector2(inventoryPanel.anchoredPosition.x, newY);

        //     // // 判断是否到达或超过目标位置
        //     // if (newY >= targetUIPosition.y)
        //     // {
        //     //     newPosition = targetUIPosition;
        //     //     //isInventoryUIMoving = false; // 到达目标位置后停止移动
        //     // }

        //     // // 设置面板的新位置
        //     // inventoryPanel.anchoredPosition = newPosition;   
        // }
        // //向下移动
        // if (!isInventoryUIMoving && inventoryPanel.anchoredPosition.y > originalUIPosition.y)
        // {
        //     // 计算面板的新位置
        //     float newY = Mathf.Clamp(inventoryPanel.anchoredPosition.y - moveSpeed * Time.deltaTime, originalUIPosition.y, targetUIPosition.y);
        //     Vector2 newPosition = new Vector2(inventoryPanel.anchoredPosition.x, newY);

        //     // 设置面板的新位置
        //     inventoryPanel.anchoredPosition = newPosition;

        //     // 到达初始位置后停止移动
        //     if (newY == originalUIPosition.y)
        //     {
        //         //isInventoryUIMoving = false;
        //     }//可取消
        // }
        
    }

    public void UpdateInventory()//调用仓库创建UIFrame预制体
    {
        //这个到时要与UI显示分开，放到数据层里
        //先清理之前的物品
        foreach(RectTransform child in inventoryPageOriginPosition)
        {
            InventoryUIFramePrefab inventoryUIFramePrefab = child.GetComponent<InventoryUIFramePrefab>();//获取子对象的UIFrame脚本
            if(inventoryUIFramePrefab != null)//筛选出包含有该脚本的子对象
            {
                Destroy(child.gameObject);//先清理
            }
        }
        Debug.Log("仓库清理完成");
        
        //再进行调用仓库获得最新的物品资源
        // List<Example_SO_Item> items = Manager_Inventory.GetAllItems();//调用该静态方法返回最新的Item列表
        //Debug.Log("仓库里的数量为：" + items.Count);
        // if(items.Count>0)
        // {
        //     Debug.Log("已经存有物品了");
        // }
        // //而后可以进行创建
        // Debug.Log("获取最新仓库内容");
        // foreach(Example_SO_Item item in items)
        // {
        //     //创建ItemUIFrame预制体//创建预制体的同时会调用预制体里的脚本
        //     GameObject newItemUIFramePrefab = Instantiate(itemUIFramePrefab , inventoryPageOriginPosition);
        //     InventoryUIFramePrefab inventoryUIFramePrefab = newItemUIFramePrefab.GetComponent<InventoryUIFramePrefab>();//获取组件
        //     inventoryUIFramePrefab.ReceiveItemSO(item);

        // }
        
    }


    public void LimitInventoryPageMoving()//配合仓库移动的组件
    {
        Vector2 inventoryPageCurrentPosition = gameObject.GetComponent<RectTransform>().anchoredPosition;//先获取当前的位置
        
        Debug.Log("获取当前位置");
        Debug.Log(inventoryPageCurrentPosition);
        float newY = Mathf.Clamp(inventoryPageCurrentPosition.y,temp.y , temp.y + movingLimit );//设置页面移动限制
        
        Vector2 newPosition = new Vector2(inventoryPageOriginPosition.anchoredPosition.x, newY);//新的位置
        inventoryPageOriginPosition.anchoredPosition = newPosition;//更新位置//不能修改RectTransfrom的y位置，只能用向量进行修改
        Debug.Log(inventoryPageOriginPosition.anchoredPosition);

    }
    // public void MoveInventoryUI()
    // {
    //     isInventoryUIMoving = !isInventoryUIMoving;//切换仓库UI移动状态
    //     Debug.Log("切换状态了");
    // }

    // //每次打开仓库都会调用此方法
    // public void OpenInventoryButton()
    // {
    //     // 获取最新的物品信息
    //     List<Class_Item> items = Manager_Inventory.GetAllItems();

    //     // 设置网格布局的间距
    //     gridLayoutGroup.spacing = new Vector2(10f, 10f); // 设置间距为10x10像素

    //     // 更新库存界面的UI显示
    //     UpdateUI(items);
    // }

    // // 更新库存界面的UI显示
    // public void UpdateUI(List<Class_Item> items) {
    //     // 清空现有的物品槽
    //     foreach (Transform child in transform) {
    //         Destroy(child.gameObject);
    //     }
    
    //     // 创建新的物品槽并显示物品信息
    //     foreach (Class_Item item in items) {
    //         GameObject newItemSlot = Instantiate(itemSlotPrefab, transform);
    //         // 设置物品信息到物品槽上
    //         newItemSlot.GetComponentInChildren<Text>().text = item.Item_Name; // 示例中假设物品名称要显示在 Text 组件中
    //         // 还可以设置物品槽的其他信息，如图标、数量等
    //     }
    // }

}
