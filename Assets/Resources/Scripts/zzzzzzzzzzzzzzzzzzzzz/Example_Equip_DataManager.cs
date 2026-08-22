using UnityEngine;
using System.Collections.Generic;
public class Example_Equip_DataManager : MonoBehaviour
{   
    //这里保存引用的属性UI的脚本
    public Example_FinalHeroAttribute_UIManager example_FinalHeroAttribute_UIManager;
    //保存引用仓库UI脚本
    public Inventory_UIManager inventory_UIManager;
    //private Example_SO_Item_ZbXX temp_Item_SO;
    
    //临时保存上次物品加成的值
    int temp_Item_Oxy;//氧气
    int temp_Item_Hp;//生命值
    int temp_Item_Atk;//攻击力
    int temp_Item_Ar;//护甲

    private Example_SO_Item[] equips_SO;//引用记录装备栏SO 0-武器 1-头盔 2-护盾 
    public int equips_Number;//维护装备数
    
    // Start is called before the first frame update
    void Awake()
    {
        equips_SO = new Example_SO_Item[equips_Number];//new出的数组在Data里（要优化→将Final_UIManager的一部分优化过来）
    }
    void Start()
    {
        //example_FinalHeroAttribute_UIManager = GetComponent<Example_FinalHeroAttribute_UIManager>();//获得该脚本
        // if (example_FinalHeroAttribute_UIManager == null)
        // {
        //     Debug.LogError("Example_FinalHeroAttribute_UIManager is null!");
        // }
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    //这里进行与UICardPrefab的SO接收交互
    public void ReceiveItemSO(Example_SO_Item_ZbXX item_SO)
    {
        
        //接收后进行数据的计算
        //先获取当前的数据,然后再加上传进来的值
        // temp_Item_Oxy = temp_Item_Oxy + item_SO.oxy;
        // temp_Item_Hp = temp_Item_Hp + item_SO.hp;
        // temp_Item_Atk = temp_Item_Atk + item_SO.atk;
        // temp_Item_Ar = temp_Item_Ar + item_SO.ar;
        
        //这里可以通过物品的类型词条与框的名字进行判断来区分显示哪个 [这里可以是装备的Equip的]
        // if("Btn_" + item_SO.itemType == example_FinalHeroAttribute_UIManager.equipFrameImages[0].name)//这里是武器Weapon
        {
            if(equips_SO[0] != null)//说明前面已经有装备上了的[更换路线]
            {
                //先将之前保存的装备属性删除(将原来的属性减掉)
                // temp_Item_Oxy = temp_Item_Oxy - equips_SO[0].oxy;
                // temp_Item_Hp = temp_Item_Hp - equips_SO[0].hp;
                // temp_Item_Atk = temp_Item_Atk - equips_SO[0].atk;
                // temp_Item_Ar = temp_Item_Ar - equips_SO[0].ar;
                DropItemToInventory(equips_SO[0],0);
            }
            //不管是null还是不null 在不null的情况下将值进行删除相当于也变成了null
            AddTempData(item_SO);//将数据保存进去
            // equips_SO[0] = item_SO;//将该SO保存到该数组[存入缓存数组]

            // example_FinalHeroAttribute_UIManager.WearEquipsSO(item_SO,0);//传递SO数据过去，并且把装备里的武器序号传过去[可优化]
            Debug.Log("进来武器分区");
        }

        //这里是头盔Helmet
        // if("Btn_" + item_SO.itemType == example_FinalHeroAttribute_UIManager.equipFrameImages[1].name)
        {
            if(equips_SO[1] != null)
            {
                DropItemToInventory(equips_SO[1],1);
            }

            AddTempData(item_SO);//进入到该分支里即是头盔装备
            // equips_SO[1] = item_SO;//

            // example_FinalHeroAttribute_UIManager.WearEquipsSO(item_SO,1);
        }
        //因为装备和装置分开处理，所以这里可以是[Device]的
        
        // //数据计算完毕进行传递给UI层显示
        TransfromDataToFinal();//这个显示的可以优化到数据被操作了以后同步更新到UI层 所以可以放进Add和Sub里
        // example_FinalHeroAttribute_UIManager.UpdateAttributeUI(temp_Item_Oxy,temp_Item_Hp,temp_Item_Atk,temp_Item_Ar);
        
    }

    public void DropItemToInventory(Example_SO_Item dropItem_SO,int number)
    {
        // CC_Backpack.AddItem(dropItem_SO);//先将该SO放进仓库里
        //Manager_Inventory.ReOrderding();//重新排序仓库列表
        SubTempData(dropItem_SO);//将之前的数据进行删除
        //清空该记录SO数组对应对象
        equips_SO[number] = null;
        TransfromDataToFinal();//将面板数值数据发送过去
        UpdateEquipsSO(number);
        inventory_UIManager.UpdateInventory();//刷新仓库UI界面
    }
    
    public void AddTempData(Example_SO_Item_ZbXX item_SO)
    {
        // //先获取当前的数据,然后再加上传进来的值
        // temp_Item_Oxy = temp_Item_Oxy + item_SO.oxy;
        // temp_Item_Hp = temp_Item_Hp + item_SO.hp;
        // temp_Item_Atk = temp_Item_Atk + item_SO.atk;
        // temp_Item_Ar = temp_Item_Ar + item_SO.ar;
    }
    public void SubTempData(Example_SO_Item item_SO)//给外部脚本调用该脚本的私有成员//公共接口
    {
        temp_Item_Oxy = temp_Item_Oxy - item_SO.oxy;
        temp_Item_Hp = temp_Item_Hp - item_SO.hp;
        temp_Item_Atk = temp_Item_Atk - item_SO.atk;
        temp_Item_Ar = temp_Item_Ar - item_SO.ar;

    }

    public void UpdateEquipsSO(int number)//外部调用该数据层接口将卸下的装备序号告诉tempSO数组
    {
        example_FinalHeroAttribute_UIManager.DroppedToEquipsSO(number);
    }

    //外部调用传输天赋类接口[增加]
    public void AddTempData_Talent(Example_SO_Talent talent_SO)
    {
        if(talent_SO.atk != 0)
        {
            temp_Item_Atk = temp_Item_Atk + talent_SO.atk;
        }
        //temp_Item_Oxy = temp_Item_Oxy + item_SO.oxy;
        //temp_Item_Hp = temp_Item_Hp + item_SO.hp;
        
        //temp_Item_Ar = temp_Item_Ar + item_SO.ar;
        TransfromDataToFinal();//更新了数据后调用UI接口更新UI层
    }

    //外部调用传输天赋类接口[减少]
    public void SubTempData_Talent(Example_SO_Talent talent_SO)
    {
        if(talent_SO.atk != 0)
        {
            temp_Item_Atk = temp_Item_Atk - talent_SO.atk;
        }

        TransfromDataToFinal();//更新了数据后调用UI接口更新UI层
    }

    //外部调用数据层将激活的天赋方法数据进行减少接口
    public void ResetHeroActivatedData_Talent(string targetname)
    {
        //获取当前英雄最新的天赋库
        Dictionary<string, List<Example_SO_Talent>> hero_Talent = Manager_Talent.GetAllHeroTalents();
        //通过循环遍历将当前英雄的天赋列表里的天赋数值进行清除
        for(int i = 0;i < hero_Talent[targetname].Count; i++)
        {
            //将该天赋列表里面的每个SO传入[减少]接口
            SubTempData_Talent(hero_Talent[targetname][i]);
        }


    }

    public void TransfromDataToFinal()//将数据传递给UI层显示
    {
        //数据计算完毕进行传递给UI层显示
        example_FinalHeroAttribute_UIManager.UpdateAttributeUI(temp_Item_Oxy,temp_Item_Hp,temp_Item_Atk,temp_Item_Ar);
    }
}
