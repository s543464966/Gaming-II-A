using UnityEngine;
using UnityEngine.UI;
using TMPro;

public class ItemUICardPrefab : MonoBehaviour
{
    public Image itemImage;//图片
    public TMP_Text itemName;//名字
    public TMP_Text itemAtk;
    public TMP_Text itemHP;
    public TMP_Text itemAr;
    public GameObject itemUICardPrefab;//自身预制体
    public GameObject inventoryUIFramePrefab;//仓库中的小物体图标
    //private Example_Equip_DataManager example_Equip_DataManager;//引用放了Equip数据层脚本的对象
    private Example_SO_Item_ZbXX item_SO;//装备引用
    private Inventory_UIManager inventory_UIManager;//引用仓库UI脚本
    // Start is called before the first frame update
    void Start()
    {
        inventory_UIManager = GameObject.Find("Img_Inventory").GetComponent<Inventory_UIManager>();//获取仓库UI脚本
        //example_Equip_DataManager = GameObject.Find("Img_HeroBasicMessage").GetComponent<Example_Equip_DataManager>();//先从有该脚本的物体对象里获得该脚本
    }

    // Update is called once per frame
    void Update()
    {
        
    }
    public void ReceiveItemData(Example_SO_Item_ZbXX example_SO_Item_ZbXX)//用来接收框传递过来的SO数据 
    {
        item_SO = example_SO_Item_ZbXX;//保存该物品SO数据
        // itemImage.sprite = example_SO_Item_ZbXX.itemSprite;//进行赋值
        // itemName.text =   example_SO_Item_ZbXX.itemName;
        // itemAtk.text = "Atk: " + example_SO_Item_ZbXX.atk.ToString();
        // itemHP.text = "HP: " + example_SO_Item_ZbXX.hp.ToString();
        // itemAr.text = "Ar: "+example_SO_Item_ZbXX.ar.ToString();
    } 

    public void OnEquipItemButton()//将装备穿戴上
    {
        
        //调用数据层脚本计算并将该物品SO传递过去
        Example_Equip_DataManager example_Equip_DataManager = GameObject.Find("Img_HeroBasicMessage").GetComponent<Example_Equip_DataManager>();
        // if(example_Equip_DataManager == null){
        //     Debug.Log("该变量为空");
        // }
        example_Equip_DataManager.ReceiveItemSO(item_SO);//给数据脚本发SO对象
        //穿戴上将该SO保存在列表仓库里的引用进行删除
        OnRemoveItemButton();
    }
    public void OnRemoveItemButton()
    {
        //Example_SO_Item_ZbXX item = itemUICardPrefab.GetComponent<InventoryUIFramePrefab>().example_SO_Item_ZbXX;
        //Example_SO_Item_ZbXX item = inventoryUIFramePrefab.GetComponent<InventoryUIFramePrefab>().example_SO_Item_ZbXX;
        //Manager_Inventory.RemoveItem(item_SO);//删除该物品SO的引用

        //重新排序仓库列表
        // Manager_Inventory.ReOrderding(item_SO);
        //刷新仓库UI
        inventory_UIManager.UpdateInventory();//
        OnUICardCloseButton();
        
    }
    public void OnUICardCloseButton()
    {
        Destroy(itemUICardPrefab);
    }
}
