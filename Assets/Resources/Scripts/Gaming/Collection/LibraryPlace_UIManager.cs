using System.Collections;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class LibraryPlace_UIManager : MonoBehaviour
{
    [Header("UI References")]
    [SerializeField] private Image libCardImage;// 对象图片
    [SerializeField] private Image libCardFrame;
    [SerializeField] private GameObject lockOverlay;// 锁图标
    [SerializeField] private GameObject newIndicator;
    [SerializeField] private TMP_Text libCardName;// 名字
    [SerializeField] private Button infoButton;// 图鉴对象详细信息按钮

    [Header("Frame Colors")]
    [SerializeField] private Color commonColor = Color.gray;
    [SerializeField] private Color uncommonColor = Color.green;
    [SerializeField] private Color rareColor = Color.blue;
    [SerializeField] private Color legendaryColor = Color.yellow;
    //======卡牌或物品类======//
    private SO_Card cardData;
    // Start is called before the first frame update
    void Start()
    {

    }
    //======图鉴里卡牌UI的初始化======//
    public void Initialize_Card(SO_Card data, bool isUnlocked, Sprite lockedPic)
    {
        cardData = data;//记录该图鉴位的数据来源
        // 设置基础UI
        libCardName.text = data.name;

        // 设置卡牌图片
        if (isUnlocked)
        {
            libCardImage.sprite = data.cardImage;
            // 将锁的UI去掉
            lockOverlay.SetActive(false);
        }
        else
        {
            // 未解锁时给锁的对象添加锁的图标
            lockOverlay.SetActive(true);
            lockOverlay.GetComponent<Image>().sprite = lockedPic;
        }

        // 设置按钮交互
        infoButton.interactable = isUnlocked;
    }
    //======图鉴里物品UI的初始化======//
    //======未解锁的对象进行解锁动画======//
    //======查看图鉴对象详细信息======//
    public void OnCheckDetailInformance()
    {
        //区分点击的图鉴对象是什么类
    }
}
