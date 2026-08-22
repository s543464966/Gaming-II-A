using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

[RequireComponent(typeof(GridLayoutGroup))]
[RequireComponent(typeof(RectTransform))]
public class Library_UIManager : MonoBehaviour
{
    //======图鉴UI配置======//
    public GameObject libPlacePrefab;   //图鉴预制体
    public Sprite lockedPic;//没解锁的图片
    //======图鉴相关组件======//
    private GridLayoutGroup gridLayoutGroup; // 图鉴的GridLayoutGroup组件
    //======组件参数======//
    private Vector2 spacing;//间隔
    private Vector2 sizePrefab;//预制体尺寸大小
    private int rowCountRule;//行数个数规定
    private float minHeight;//最小高度限制
    //======图鉴panel======//
    [Tooltip("图鉴模块总对象")] public GameObject lib_OBJ; //图鉴模块总对象
    void Awake()
    {
        //获取基础组件
        gridLayoutGroup = GetComponent<GridLayoutGroup>();
        sizePrefab = libPlacePrefab.GetComponent<RectTransform>().sizeDelta;

        rowCountRule = gridLayoutGroup.constraintCount;
        spacing = gridLayoutGroup.spacing;
        minHeight = GetComponentInParent<RectTransform>().rect.height;//父对象的高度
    }
    // void OnEnable() //每次打开都会更新
    // {
    //     //动态加载图鉴
    //     if (Manager_Library.Instance != null)
    //     {
    //         //默认显示英雄卡牌页面
    //         List<LibraryData> heroCard = Manager_Library.Instance.heroCard;
    //         UpdateLibrarySize(heroCard);
    //     }
    // }
    void Start()
    {
        EnsureOrder();
    }
    //======动态更新图鉴页面长度======//
    private void UpdateLibrarySize(List<LibraryData> _currentLibData)//上下拉伸锚点解决方案
    {
        // 计算行数（向上取整）
        int rowCount = Mathf.CeilToInt(_currentLibData.Count / (float)rowCountRule);
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
        LibraryVisionUI(_currentLibData);
    }
    //======图鉴可视化======//
    private void LibraryVisionUI(List<LibraryData> _VisionLibData)  //传入想看的图鉴数据列表
    {
        // 清除现有内容
        foreach (Transform child in transform)
        {
            Destroy(child.gameObject);
        }
        // 创建图鉴实例
        foreach (LibraryData lib in _VisionLibData)
        {
            //需要图鉴数据管理器就是实时被更新的
            //先判断该对象是否获得解锁过[根据不同的窗口来调用记录不同类型的列表来判断是否解锁]
            //bool isUnlocked = PlayerInventory.Instance.HasCard(entry.cardData.cardID);
            bool isUnlocked = true;
            CreateLibInstance(lib, isUnlocked);
        }
    }
    //======创建实例图鉴======//[通用]
    private void CreateLibInstance(LibraryData entry, bool isUnlocked)
    {
        // 已解锁的对象
        GameObject libBlank = Instantiate(libPlacePrefab, transform);
        // 调用图鉴预制体上的UI初始化脚本，,将数据和解锁状态传入UI脚本
        if (entry.cardData != null)//[英雄和怪物]
        {
            //卡牌图鉴
            libBlank.GetComponent<LibraryPlace_UIManager>().Initialize_Card(entry.cardData, isUnlocked, lockedPic);
        }
        //后续可以区分其他数据类型...

    }
    //======按钮：切换不同的具体图鉴======//
    // public void OnHeroLibButton()//英雄
    // {
    //     if (!lib_OBJ.activeSelf)
    //     {
    //         lib_OBJ.SetActive(true);
    //     }
    //     //切换英雄
    //     UpdateLibrarySize(Manager_Library.Instance.heroCard);
    // }
    // public void OnGwLibButton()//怪物
    // {
    //     //切换怪物
    //     UpdateLibrarySize(Manager_Library.Instance.gwCard);
    // }
    public void OnItemLibButton()//装备
    {
        //切换装备
    }
    //======开发时确保流程======//
    private void EnsureOrder()
    {
        if (lib_OBJ.activeSelf == true)
        {
            lib_OBJ.SetActive(false);
        }
    }
}
