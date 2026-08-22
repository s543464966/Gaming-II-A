using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class InventoryCards_UIManager : MonoBehaviour
{
    //======卡牌仓库UI配置======//
    [SerializeField] public GameObject cardPlacePrefab;   //卡牌预制体
    //======卡牌仓库相关组件======//
    private GridLayoutGroup gridLayoutGroup; // 卡牌仓库的GridLayoutGroup组件
    //======组件参数======//
    private Vector2 spacing;//间隔
    private Vector2 sizePrefab;//预制体尺寸大小
    private int rowCountRule;//行数个数规定
    private float minHeight;//最小高度限制
    //======卡牌仓库panel======//
    [Tooltip("卡牌仓库模块总对象")] public GameObject card_OBJ; //卡牌仓库模块总对象
    void Awake()
    {
        //获取基础组件
        gridLayoutGroup = GetComponent<GridLayoutGroup>();
        sizePrefab = cardPlacePrefab.GetComponent<RectTransform>().sizeDelta;

        rowCountRule = gridLayoutGroup.constraintCount;
        spacing = gridLayoutGroup.spacing;
        minHeight = GetComponentInParent<RectTransform>().rect.height;//父对象的高度
    }
    void OnEnable()
    {
        //动态加载仓库
        // if (Manager_InventoryCards.Instance != null)
        // {
        //     //拿取数据
        //     List<Card> cards = Manager_InventoryCards.Instance.inventoryCards;
        //     UpdateCardInventorySize(cards); //调用更新UI
        // }
    }
    void Start()
    {
        EnsureOrder();
    }
    //======动态更新仓库卡牌页面长度======//
    private void UpdateCardInventorySize(List<Card> _currentCardData)//上下拉伸锚点解决方案
    {
        // 计算行数（向上取整）
        int rowCount = Mathf.CeilToInt(_currentCardData.Count / (float)rowCountRule);
        // 计算总高度 = 行数×物品高度 + (行数-1)×垂直间隔
        float totalHeight = rowCount * sizePrefab.y + Mathf.Max(0, rowCount - 1) * spacing.y;
        // 增加最小高度限制
        float contentHeight = Mathf.Max(minHeight, totalHeight);
        // 获取父容器高度
        RectTransform parentRT = transform.parent.GetComponent<RectTransform>();
        float parentHeight = parentRT.rect.height;
        // 计算需要的边距
        float requiredHeight = contentHeight - parentHeight;
        // 设置自身区域高度
        GetComponent<RectTransform>().sizeDelta = new Vector2(GetComponent<RectTransform>().sizeDelta.x, requiredHeight);
        Debug.Log(contentHeight);
        Debug.Log(minHeight);

        //更新完高度进行可视化展示
        CardInventoryVisionUI(_currentCardData);
    }
    //======仓库卡牌可视化======//
    private void CardInventoryVisionUI(List<Card> _VisionCardData)  //传入想看的图鉴数据列表
    {
        // 清除现有内容
        foreach (Transform child in transform)
        {
            Destroy(child.gameObject);
        }
        // 创建仓库卡牌实例
        foreach (Card card in _VisionCardData)
        {
            CreateCardInstance_Inventory(card);
        }
    }
    //======创建实例仓库卡牌======//
    private void CreateCardInstance_Inventory(Card _entry)
    {
        // 创建仓库卡牌实例
        GameObject cardPlace = Instantiate(cardPlacePrefab, transform);
        //根据card数据类分配UI数据可视化==以下全是UI修改
        cardPlace.GetComponent<InventoryCardPlace_UIManager>().InitInventoryCardBtnUI(_entry);
    }
    //======玩家卡牌仓库UI按钮======//
    public void OnPlayerCardInventoryButton()
    {
        //判断是否为战斗状态
        // if (Manager_InventoryCards.Instance.isChallengeState)
        // {
        //     //在战斗状态取消打开仓库并给战斗中提示
        //     Debug.Log("正在战斗ing!!!");
        // }
        // else
        // {
        //     //未在战斗状态可以打开
        //     card_OBJ.SetActive(true);
        // }
    }
    //======开发时确保流程======//
    private void EnsureOrder()
    {
        if (card_OBJ.activeSelf == true)
        {
            card_OBJ.SetActive(false);
        }
    }
}
