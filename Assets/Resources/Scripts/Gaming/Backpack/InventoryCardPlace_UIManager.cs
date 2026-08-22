using System.Collections;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class InventoryCardPlace_UIManager : MonoBehaviour
{
    //======卡牌资源======//
    [Tooltip("卡牌攻击类型资源")] public Sprite cardAtk_Asset; //卡牌攻击类型资源
    public Sprite cardMtk_Asset;  //卡牌魔法攻击类型资源
    //======仓库卡牌预制体UI所需要的参数======//
    [Tooltip("该仓库卡牌数据类")] public Card thisCardData; //该仓库卡牌数据类
    public Image cardImg;   //卡牌图片
    [Tooltip("卡牌元素")] public Image cardElement; //卡牌元素
    public Image cardCareer;    //卡牌职业
    [Tooltip("卡牌名字")] public TMP_Text cardName; //卡牌名字
    public TMP_Text cardHealth; //卡牌血量
    [Tooltip("卡牌伤害")] public TMP_Text cardAtk; //卡牌伤害
    // Start is called before the first frame update
    void Start()
    {

    }
    //======初始化仓库卡牌预制体UI======//
    public void InitInventoryCardBtnUI(Card _cardData)
    {
        thisCardData = _cardData; //保存引用
        //修改相关UI
        cardImg.sprite = thisCardData.SO_Card.cardImage;
        //血量用card数据类的current

        //展示装备 如果有的话
        // if (thisCardData.SO_Equip != null)
        // {

        // }
        // else
        // {
        //     Debug.Log(thisCardData.SO_Card.cardName + "该卡未穿戴装备");
        // }
    }
    //======点击卡牌展开详细信息======//
    public void OnInventoryCardDetailedButton()
    {
        //展示该卡的详细信息

        //穿戴装备？
    }
}
