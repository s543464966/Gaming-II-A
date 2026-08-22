using UnityEngine;
using UnityEngine.UI;
using TMPro;

public class InventoryUIFramePrefab : MonoBehaviour
{
    public Example_SO_Item_ZbXX example_SO_Item_ZbXX;//装备引用
    public GameObject itemUICardPrefab;//保存UICard的预制体
    private Transform parentUItransfrom;//预制体创建的位置

    public Image itemImage;
    public TMP_Text itemName;
    //public TMP_Text itemAtk;
    //public TMP_Text itemDescribe;//物品简介
    void Start()
    {
        //parentUItransfrom = GetComponentInParent<Equip_UIManager>().transform;
        parentUItransfrom = GameObject.Find("UIHome").transform;//获得画布位置
        // itemImage.sprite = example_SO_Item_ZbXX.itemSprite;
        // itemName.text = example_SO_Item_ZbXX.itemName;
    }
    public void ReceiveItemSO(Example_SO_Item example_item)
    {

        //example_SO_Item_ZbXX = example_item;
        //example_SO_Item_ZbXX = example_item as Example_SO_Item_ZbXX;
        // example_SO_Item_ZbXX = (Example_SO_Item_ZbXX)example_item;//将父类强转子类
        UpdateUI();
    }
    // Update is called once per frame
    private void UpdateUI()
    {
        // itemImage.sprite = example_SO_Item_ZbXX.itemSprite;
        // itemName.text = example_SO_Item_ZbXX.itemName;
    }

    public void OnUICardButton()
    {
        GameObject newItemUICardPrefab = Instantiate(itemUICardPrefab,parentUItransfrom);//创建itemUICard预制体
        ItemUICardPrefab itemUICardScript = newItemUICardPrefab.GetComponent<ItemUICardPrefab>();
        itemUICardScript.ReceiveItemData(example_SO_Item_ZbXX);//传递引用保存的SO数据过去
    }
}
