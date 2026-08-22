using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class CC_Card : MonoBehaviour
{
    // =========================================================
    // 1. 数据源与配置
    // =========================================================
    //获取数据中心
    private GameData GameData => DBCC_DataBase.Instance.GameData;   //GameData别名[因为单例原因]
    [Header("模块: UI结构引用")]
    [Tooltip("上半部 Grid (挂载 Content)")] [SerializeField] private Transform topContent; // 上半部 Grid (挂载 Content)
    [Tooltip("下半部 Grid (挂载 Content)")] [SerializeField] private Transform bottomContent; // 下半部 Grid (挂载 Content)
    
    [Header("模块: 动态视窗控制")]
    [Tooltip("中间分界线 (用于隐藏)")] [SerializeField] private GameObject midDividerObj; // 中间分界线 (用于隐藏)
    [Tooltip("下半部整体 (用于隐藏)")] [SerializeField] private GameObject bottomScrollView; // 下半部整体 (用于隐藏)
    
    [Header("模块: 资源配置")]
    [Tooltip("必须挂载 C_Card 脚本")] [SerializeField] private GameObject cardPrefab; // 必须挂载 C_Card 脚本
    
    [Header("模块: 基础显示控制")]
    [Tooltip("激活英雄页面按钮")] [SerializeField] private Button Btn_HeroTab; // 激活英雄页面按钮
    [Tooltip("激活随从页面按钮")] [SerializeField] private Button Btn_MinionTab; // 激活随从页面按钮
    [Tooltip("卡牌计数文本")] [SerializeField] private TMP_Text TMP_CardCount; // 卡牌计数文本
    
    [Header("模块: 详情页属性表引用")]
    [Tooltip("属性表")] [SerializeField] private Card_Attribute Card_Attribute; // 属性表

    // --- 内部状态 --- (对象池)
    private List<C_Card> topPool = new List<C_Card>(); // 上部对象池(已解锁)
    private List<C_Card> bottomPool = new List<C_Card>(); // 下部对象池(未解锁)
    
    // --- 内部状态 --- (交互控制)
    private CardAttributeActionMode lockedActionMode = CardAttributeActionMode.Buy; // 未解锁时进入购买
    private CardAttributeActionMode intensifyActionMode = CardAttributeActionMode.Intensify; // 已解锁时进入强化

    // ----------------------------------------------------------------------------------------------------------
    // ==========================================
    // 1. 生命周期与初始化 (Lifecycle & Init)
    // ==========================================
    
    private void OnEnable() // 每次实例被激活的时候更新UI
    {
        // 每次打开，重新刷新数据
        SwitchTab();
    }

    /// <summary>
    /// 【核心】初始化仓库界面
    /// 负责: 清除开发时残留节点并进行事件绑定(预留)
    /// </summary>
    public void Init_PageCard() // 初始化
    {
        // 清空开发时残留数据
        foreach(Transform child in topContent)  //上半部分显示区域
        {
            Destroy(child.gameObject);
        }
        foreach(Transform child in bottomContent)  //下半部分显示区域
        {
            Destroy(child.gameObject);
        }

        Debug.Log("卡牌展示区域开发时残留对象清除!");
    }
    // ==========================================
    // 2. 界面更新逻辑 (UI Updates)
    // ==========================================
    
    /// <summary>
    /// 【核心】切换分类 (英雄/随从)
    /// 负责: 触发 UI 列表刷新
    /// </summary>
    public void SwitchTab() // CardType type
    {
        //if (_currentType == type) return;
        
        //_currentType = type;
        
        // (可选) 更新页签高亮状态
        // UpdateTabVisuals(); 
        
        // 刷新显示UI
        Update_CardUI();
    }
    /// <summary>
    /// 【核心】手动刷新 UI
    /// 负责: 1.获取已解锁与未解锁数据, 2.调整分别的对象池, 3.处理无未解锁卡牌时的动态布局
    /// </summary>
    public void Update_CardUI()
    {
        if (GameData.Sys_Card == null) return;

        // 1. 获取两组数据 (已解锁 / 未解锁)
        List<Card> unlockedList = GameData.Sys_Card.Get_DisplayCardList(true);
        List<Card> lockedList = GameData.Sys_Card.Get_DisplayCardList(false);

        // 2. 刷新上半部分 (已解锁)
        Adjust_CardPool(topContent, topPool, unlockedList);
        TMP_CardCount.text = unlockedList.Count + " / " + GameData.Sys_Card.Get_CardList().Count;
        // 3. 动态布局逻辑
        if (lockedList.Count > 0)
        {
            // --- 有未解锁卡牌 ---
            // 显示下半部和分界线
            midDividerObj.SetActive(true);
            bottomScrollView.SetActive(true);
            
            // 填充数据
            Adjust_CardPool(bottomContent, bottomPool, lockedList);
        }
        else
        {
            // --- 全部解锁 ---
            // 隐藏下半部和分界线
            // 此时 TopScrollView 的 LayoutElement.FlexibleHeight = 1 会自动占满剩余空间
            midDividerObj.SetActive(false);
            bottomScrollView.SetActive(false);
        }
    }
    /// <summary>
    /// 调整上下显示池子大小 (对象池逻辑)
    /// 负责: 1.实例化扩充指定对象池, 2.绑定卡牌最新状态和引用实例显隐
    /// </summary>
    /// <param name="_Content">绑定的父级区域</param>
    /// <param name="_ObjPool">控制的对象池集合</param>
    /// <param name="_DataList">驱动数据列表</param>
    private void Adjust_CardPool(Transform _Content, List<C_Card> _ObjPool, List<Card> _DataList)
    {
        // 1. 扩容
        while (_ObjPool.Count < _DataList.Count)
        {
            GameObject Card_Obj = Instantiate(cardPrefab, _Content);
            C_Card cardScript = Card_Obj.GetComponent<C_Card>();

            if(cardScript != null)
            {
                _ObjPool.Add(cardScript);
            }
        }

        // 2. 赋值与显隐
        for (int i = 0; i < _ObjPool.Count; i++)
        {
            if (i < _DataList.Count)    //需要显示的显示
            {
                _ObjPool[i].gameObject.SetActive(true);
                // 【核心连通】: 确定属性表动作模式
                CardAttributeActionMode cardAttributeActionMode = _DataList[i].isUnlocked ? intensifyActionMode : lockedActionMode;
                // 【核心连通】: 将数据、状态、以及场景中的属性表引用传递给 C_Card
                _ObjPool[i].Init_CollectionCard(_DataList[i], cardAttributeActionMode);
                _ObjPool[i].Card_Attribute = Card_Attribute;
            }
            else    //不需要的就隐藏
            {
                _ObjPool[i].gameObject.SetActive(false);
            }
        }
    }
    // public void ManageCardDataSync_inLevelFight(Card changedCard, C_Damage cardFightTempData)   //在关卡战斗中
    // {
    //     changedCard.hp = cardFightTempData.hp;   //将战斗中的数据实时到仓库上记录
    // }
    //======仓库英雄数据库======//
    // private void HeroSO2Dict()
    // {
    //     //  加载所有卡牌SO
    //     SO_Card[] allHeroCard_SO = Resources.LoadAll<SO_Card>("Card/Hero");
    //     if (allHeroCard_SO.Length == 0)
    //     {
    //         Debug.LogError("No CardDataSO found in Resources/CardData folder!");
    //         return;
    //     }
    //     // 建立 ID 到 SO 的字典
    //     heroCardDict = allHeroCard_SO.ToDictionary(card => card.cardId);
    // }
    //======从JSON加载仓库数据======//
    // public void LoadFromSaveData(SaveData saveData)
    // {
    //     if (DBCC_DataBase.Instance != null)
    //     {
    //         // 判断存档数据里对应的系统初始化
    //         if (saveData.isInit_HeroSystem == false)    //未初始化
    //         {
    //             //  首次上线给予玩家默认卡组
    //             FirstInitDefaultCards();
    //             //  记录数据
    //             Debug.Log("仓库英雄系统初始化完毕!");
    //         }
    //         else if (saveData.isInit_HeroSystem == true) //初始化过直接加载进来
    //         {
    //             //  将存档里的数据提取对应的更新
    //             inventoryCards.Clear();
    //             var saveData_HeroCards = saveData.saveData_HeroCards;
    //             //  遍历复现添加
    //             foreach (var saveCard in saveData_HeroCards)
    //             {
    //                 // 用存档里记录的唯一 ID 去查 SO
    //                 if (heroCardDict.TryGetValue(saveCard.cardID_SO, out SO_Card soCard))
    //                 {
    //                     // 创建一个游戏里的Card数据类
    //                     Card card = new Card(soCard);
    //                     //  更新当前血量
    //                     card.currentHealth = saveCard.currentHealth;
    //                     //  后续询问是否有穿戴装备

    //                     //  添加进英雄仓库里
    //                     inventoryCards.Add(card);
    //                 }
    //                 else
    //                 {
    //                     Debug.LogError($"[LoadHeroCards] 资源表里找不到 ID = {saveCard.cardID_SO} 的 SO_Card！");
    //                 }
    //             }
    //             Debug.Log("玩家仓库系统加载完毕!");
    //         }
    //     }
    // }
    //======保存数据到Json======//  SO保存为对应ID
    // public void ExportToSaveData(SaveData saveData)
    // {
    //     //  清空数据
    //     saveData.saveData_HeroCards.Clear();
    //     //  将该系统的临时数据转换并记录进存档数据中
    //     foreach (var card in inventoryCards)
    //     {
    //         //  新建一个卡牌数据可序列化类
    //         SaveData_HeroCard saveData_HeroCard = new SaveData_HeroCard();
    //         saveData_HeroCard.cardID_SO = card.cardBaseData.cardId;
    //         saveData_HeroCard.currentHealth = card.currentHealth;

    //         //  添加进可序列化列表里
    //         saveData.saveData_HeroCards.Add(saveData_HeroCard);
    //     }
    //     saveData.isInit_HeroSystem = true;  //标记该系统初始化完成
    //     Debug.Log("仓库英雄卡牌保存完毕!");
    // }
}
