using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using TMPro;
using UnityEngine.UI;


public class Example_FinalHeroAttribute_UIManager : MonoBehaviour//这个是最终显示出来的UI层
{
    //UI层引用属性词条
    public TMP_Text[] texts;//0_氧气 1_血量 2_攻击力 3_护甲
    //引用装置框SO
    private Example_SO_Item[] devices_SO;//记录装置栏SO 0-3 = 4个装置
    //引用装置框UI
    public Image[] deviceFrameImages;//0-3为4个装置
    //引用装备栏
    public Image[] equipFrameImages;//0-武器 1-头盔 2-护盾 3-6可以是装置（或者分开储存）↑
    private Example_SO_Item[] equips_SO;//引用记录装备栏SO 0-武器 1-头盔 2-护盾 3-6可以是装置（或者分开储存）↑
    //引用EquipUICard的预制体
    public GameObject equippedUICard;//引用UICard
    
    public EquippedUICard_UIManager equippedUICard_UIManager;//引用已经装上了的装备页面Card的UIManager

    public int equips_Number;//维护装备数
    public int devices_Number;//维护装置数
    // Start is called before the first frame update
    void Awake()
    {
        //New出SO数组
        equips_SO = new Example_SO_Item[equips_Number];
        devices_SO = new Example_SO_Item[devices_Number];
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    public void UpdateAttributeUI(int oxy, int hp, int atk, int ar)//根据穿戴装备传递过来的数据更新总属性词条UI
    {
        texts[0].text = "Oxy: " + oxy.ToString();
        texts[1].text = "Hp: " + hp.ToString();
        texts[2].text = "Atk: " + atk.ToString();
        texts[3].text = "Ar: "+ ar.ToString();
        //还要有英雄属性即 最终属性 = 英雄属性 + 物品加成； 天赋加成
    }



    //保存装备的SO以及更新显示装备UI的方法[可优化]
    public void WearEquipsSO(Example_SO_Item equip, int number)
    {
        //保存记录EquipSO，为了触发UICard做准备
        equips_SO[number] = equip;
        //顺便将装备UI显示出来
        equipFrameImages[number].sprite = equips_SO[number].itemSprite;
        //Debug.Log(equips_SO[0]);
        UpdateEquippedImgUI();//当装备SO数组更新的时候，提前先更新Card上的UI信息
    }

    public void WearDevicesSO(Example_SO_Item device, int number)
    {
        //保存记录DeviceSO
        devices_SO[number] = device;

        deviceFrameImages[number].sprite = device.itemSprite;
    }

    public void DroppedToEquipsSO(int number)//为了响应丢弃装备给该脚本new出的SO数组的公共接口
    {
        //将记录的SO数组的第number个进行置空(因为装备卸下来了)
        equips_SO[number] = null;
        //更新英雄UI面板的装备面板
        UpdateHeroEquipUI(number);
        //再去更新EquippedUICard上的数据和UI层
        equippedUICard_UIManager.UpdateEquippedUI(equips_SO,number);
        
    }

    public void UpdateHeroEquipUI(int number)//未来优化想做的接口
    {
        //顺便将装备UI显示出来
        if(equips_SO[number] == null)
        {
            equipFrameImages[number].sprite = default;
        }else{
            equipFrameImages[number].sprite = equips_SO[number].itemSprite;
        }
    }

    public void UpdateEquippedImgUI()//只要装备信息更新，就会提前告诉EquippedUICard上，避免需要点击相应的按钮才能更新自己的，但其他装备已经穿戴上了
    {
        for(int i = 0 ; i< equips_Number ; i++)//对该脚本保存的最新SO数组进行循环
        {
            if(equips_SO[i] == null)//如果该数组成员为空，那提前给UICard上也为空
            {
                equippedUICard_UIManager.AvoidEmptyObject(equips_SO,i);
            }else//如果该数组成员不为空，提前将信息更新
            {
                equippedUICard_UIManager.AvoidEmptyObject(equips_SO,i);
            }
        }
    }
    //这里可以做点击按钮触发equipUICardPrefab了
    public void OnEquipWeaponButton()//这里是点击武器进去的(同时更新数据和UI面板) 
    {
        
        equippedUICard_UIManager.UpdateEquippedUI(equips_SO , 0);//将保存好的SO数组和从武器界面进去的序号传过去
        if(equippedUICard.activeSelf == false){
            equippedUICard.SetActive(true);//激活equippedUICard
        }
        // Transform parentUItransfrom = GameObject.Find("UIHome").transform;//获取最外面的画布canvas对象
        // GameObject newEquipUICard = Instantiate(equipUICardPrefab , parentUItransfrom);//
        
    }
    //还有其他地方进去的，讲究从哪点进去就是哪个的画面      [装备]and[装置]都可以
    public void OnEquipHelmetButton()//这里是装备头盔的
    {
        equippedUICard_UIManager.UpdateEquippedUI(equips_SO , 1);
        equippedUICard.SetActive(true);
    }
}
