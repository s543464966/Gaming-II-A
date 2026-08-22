using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using TMPro;
using System.Security.Cryptography;


public class EquippedUICard_UIManager : MonoBehaviour
{
    //保存引用的一系列UI
    //装备图片UISprite
    public Image[] equippedImages;//0-6 0是Weapon 3-6是装置//为了和前面的头盔护甲装备统一，先这样做了//也可以是分开
    public Image[] equipBackgound;//每个装备了的物品的底色
    //装置图片UISprite
    public Image[] devicedImages;//感觉可以分开来，这里是4个装置 0-3
    
    //保留SO数组引用
    private Example_SO_Item[] example_SO_Items;//(用传进去的赋值)
    //词条文本类
    public TMP_Text item_Name;
    public TMP_Text item_Oxy;
    public TMP_Text item_Hp;
    public TMP_Text item_Atk;
    public TMP_Text item_Ar;//已经分配好对象
    //保存Data的脚本
    public Example_Equip_DataManager example_Equip_DataManager;
    //引用仓库UI脚本
    public Inventory_UIManager inventory_UIManager;
    // Start is called before the first frame update
    void Start()
    {
        //example_SO_Items = new Example_SO_Item[1];
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    //在这里保存装备上来物品的SO，好像不保存也行？//接收SO数组
    //在UICard上将每个UI显示出来
    public void UpdateEquippedUI(Example_SO_Item[] so_Items , int number)//接收传递进来的SO数据以及进入窗口序号
    {
        example_SO_Items = so_Items;//每次点进来是最新的SO数组(传进来的SO数组赋值给该UICard声明的变量上)
        //将SO里的数据写入UI页面上
        // if(example_SO_Items[number] == null)//空的时候
        // {
        //     equippedImages[number].sprite = default;//改为空图片（没装备的时候）
        // }else{
        //     equippedImages[number].sprite = example_SO_Items[number].itemSprite;
        // }
        switch(number)//[使用switch case分支语句实现number等于不同的结果显示不同的UI]
        {
            case 0 : 
                OnEquippedWeaponButton();
                break;
            case 1 :
                OnEquippedHelmetButton();
                break;
            
        }
    }

    //要做个在自身界面中来回切换正确显示//演示
    public void OnEquippedWeaponButton()//武器的EquippedUICard
    {
        int number = 0;//武器的序号
        //0背景底色为蓝色，1-4为白色
        equipBackgound[0].color = Color.blue;
        equipBackgound[1].color = Color.white;
        equipBackgound[2].color = Color.white;
        equipBackgound[3].color = Color.white;
        equipBackgound[4].color = Color.white;
        //数据UI界面只需要重新写一遍覆盖即可
        AvoidEmptyObject(example_SO_Items,number);
        // item_Name.text = example_SO_Items[number].itemName;
        // item_Oxy.text = "Oxy: " + example_SO_Items[number].oxy.ToString();
        // item_Hp.text = "HP: " + example_SO_Items[number].hp.ToString();
        // item_Atk.text = "Atk: " + example_SO_Items[number].atk.ToString();
        // item_Ar.text = "Ar: " + example_SO_Items[number].ar.ToString();
    }

    public void OnEquippedHelmetButton()//头盔的EquippedUICard
    {
        int number = 1;//武器的序号
        //0背景底色为蓝色，1-4为白色
        equipBackgound[0].color = Color.white;
        equipBackgound[1].color = Color.blue;
        equipBackgound[2].color = Color.white;
        equipBackgound[3].color = Color.white;
        equipBackgound[4].color = Color.white;
        //数据UI界面只需要重新写一遍覆盖即可
        AvoidEmptyObject(example_SO_Items,number);
        // item_Name.text = example_SO_Items[number].itemName;
        // item_Oxy.text = "Oxy: " + example_SO_Items[number].oxy.ToString();
        // item_Hp.text = "HP: " + example_SO_Items[number].hp.ToString();
        // item_Atk.text = "Atk: " + example_SO_Items[number].atk.ToString();
        // item_Ar.text = "Ar: " + example_SO_Items[number].ar.ToString();
    }

    // public void OnEquippedDevice1Button()
    // {
    //     int number = 3;//装置的序号
    //     //0背景底色为蓝色，1-4为白色//演示
    //     equipBackgound[1].color = Color.blue;
    //     equipBackgound[0].color = Color.white;
    //     equipBackgound[2].color = Color.white;
    //     equipBackgound[3].color = Color.white;
    //     equipBackgound[4].color = Color.white;
    //     //数据UI界面只需要重新写一遍覆盖即可
    //     item_Name.text = example_SO_Items[number].itemName;
    //     item_Oxy.text = example_SO_Items[number].oxy.ToString();
    //     item_Hp.text = example_SO_Items[number].hp.ToString();
    //     item_Atk.text = example_SO_Items[number].atk.ToString();
    //     item_Ar.text = example_SO_Items[number].ar.ToString();
    // }
    // public void OnEquippedDevice2Button()
    // {
    //     int number = 4;//装置的序号
    //     //0背景底色为蓝色，1-4为白色//演示
    //     equipBackgound[2].color = Color.blue;
    //     equipBackgound[0].color = Color.white;
    //     equipBackgound[1].color = Color.white;
    //     equipBackgound[3].color = Color.white;
    //     equipBackgound[4].color = Color.white;
    //     //数据UI界面只需要重新写一遍覆盖即可
    //     item_Name.text = example_SO_Items[number].itemName;
    //     item_Oxy.text = example_SO_Items[number].oxy.ToString();
    //     item_Hp.text = example_SO_Items[number].hp.ToString();
    //     item_Atk.text = example_SO_Items[number].atk.ToString();
    //     item_Ar.text = example_SO_Items[number].ar.ToString();
    // }
    public void DisassembleEquipButton()
    {
        //要判断是哪种装备要卸载下来(用什么方法)
        //可以通过当前是在哪个界面即谁是激活状态/或者是谁的颜色是蓝色→相当于在当前界面
        if(equipBackgound[0].color == Color.blue)//为蓝色相当于在当前界面 现在是武器的界面
        {
            //调用Data脚本里的集成卸下方法
            example_Equip_DataManager.DropItemToInventory(example_SO_Items[0],0);
        }
        if (equipBackgound[1].color == Color.blue)//这里是头盔界面
        {
            example_Equip_DataManager.DropItemToInventory(example_SO_Items[1], 1);
        }
        // //（先更新到仓库列表里）
        // Manager_Inventory.AddItem(example_SO_Items[0]);//先做示例
        // //卸下装备数据
        // example_Equip_DataManager.SubTempData(example_SO_Items[0]);
        // //更新英雄数据面板
        // example_Equip_DataManager.TransfromDataToFinal();
        // //要告诉传SO数组的将该SO去除 //然后在UI上显示
        // example_Equip_DataManager.UpdateEquipsSO(0);
        // //刷新UI仓库
        // inventory_UIManager.UpdateInventory();
        //调用Data脚本里的集成卸下方法
        //example_Equip_DataManager.DropItemToInventory(example_SO_Items[0],0);
        //再关闭该页面
        CloseEquippedUICard();
    }
    public void AvoidEmptyObject(Example_SO_Item[] example_SO_Items, int number)
    {
        //如果对象不在了就给默认值
        if(example_SO_Items[number] == null)
        {
            equippedImages[number].sprite = default;//改为空图片（没装备的时候）
            item_Name.text = default;
            item_Oxy.text = default;
            item_Hp.text = default;
            item_Atk.text = default;
            item_Ar.text = default;
            
        }else
        {
            equippedImages[number].sprite = example_SO_Items[number].itemSprite;
            item_Name.text = example_SO_Items[number].itemName;
            item_Oxy.text = "Oxy: " + example_SO_Items[number].oxy.ToString();
            item_Hp.text = "HP: " + example_SO_Items[number].hp.ToString();
            item_Atk.text = "Atk: " + example_SO_Items[number].atk.ToString();
            item_Ar.text = "Ar: " + example_SO_Items[number].ar.ToString();
        }
    }
    public void CloseEquippedUICard()
    {
        gameObject.SetActive(false);//将自身设置为不活动状态
    }
}
