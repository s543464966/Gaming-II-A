using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

//======图鉴数据类======//
public class LibraryData
{
    [Tooltip("卡牌SO引用")] public SO_Card cardData; //卡牌SO引用
                                                 //可能有物品

    public bool isUnlocked;       // 是否解锁
    [Tooltip("是否为新获得")] public bool isNew; //是否为新获得

    public LibraryData(SO_Card data)
    {
        cardData = data;
        isUnlocked = false;
        isNew = false;
    }
}
//======图鉴数据管理器======//
public class CC_Library : MonoBehaviour
{
    //======单例模式======//
    public static CC_Library Instance { get; private set; }
    //======列表======//[全部资源]
    public List<LibraryData> heroCard = new List<LibraryData>();
    public List<LibraryData> gwCard = new List<LibraryData>();
    private void Awake()
    {
        if (Instance == null)
        {
            Instance = this;
            DontDestroyOnLoad(gameObject);
        }
        else
        {
            Destroy(gameObject);
            return;
        }
        // 动态加载所有SO
        // LoadAllSO();
    }
    //======动态加载SO======//
    private void LoadAllSO()
    {
        //判断是否有保存的数据
        // 从Resources文件夹加载所有SO [包括卡牌和装备]
        SO_Card[] allHeroCard_SO = Resources.LoadAll<SO_Card>("Card/Hero");
        SO_Card[] allGWCard_SO = Resources.LoadAll<SO_Card>("Card/Monster001");

        if (allHeroCard_SO.Length == 0 || allGWCard_SO.Length == 0)
        {
            Debug.LogError("No CardDataSO found in Resources/CardData folder!");
            return;
        }

        // 创建图鉴条目数据
        // 英雄
        foreach (SO_Card card in allHeroCard_SO)
        {
            heroCard.Add(new LibraryData(card));
        }
        // 怪物
        foreach (SO_Card card in allGWCard_SO)
        {
            gwCard.Add(new LibraryData(card));
        }
    }
    //======记录解锁图鉴中某个对象======//[新获取的]
    public void LibraryCard_Unlocked(List<LibraryData> targetLib_List, SO_Card targetSO)//传入需要记录的列表和记录对象
    {
        // 找到对应的条目[卡牌的]
        LibraryData target = targetLib_List.Find(t => t.cardData == targetSO);
        if (target != null && !target.isUnlocked)
        {
            target.isUnlocked = true;
            target.isNew = true;
        }
    }
    //======保存图鉴收集数据======//[关键，同时在初始化的时候要判断是否有新加进来的或已获得的]

}
