using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class LootBag : MonoBehaviour
{
    public GameObject lootPrefab;
    // public List<SO_Prop> lootList = new List<SO_Prop>();    
    // public string ItemName;
    // public int LuckeyRate;


    // private SO_Prop DropLootItem()
    // {
    //     int RandomNume = Random.Range(1,10001);
    //     List<SO_Prop> LuckyItems = new List<SO_Prop>();
    //     foreach(SO_Prop item in lootList)
    //     {
    //         if( RandomNume <= item.luckyRate)
    //         {
    //             LuckyItems.Add(item);
    //         }
    //     }


    //     if(LuckyItems.Count > 0)
    //     {
    //         SO_Prop dropItem = LuckyItems[Random.Range(0,LuckyItems.Count)];
    //         return dropItem;
    //     }
    //     return null;
    //     // return gameObject lootPrefab;
    // }


    // public void InsDropItem(Vector3 Pos)
    // {
    //     // SO_Prop dropItem = DropLootItem();
    //     // if(dropItem != null)
    //     // {
    //     //     GameObject lootItme = Instantiate(lootPrefab,Pos,Quaternion.identity);
    //     //     lootItme.GetComponent<SpriteRenderer>().sprite = dropItem.propSprite;
    //     //     lootItme.GetComponent<ItemPickUp>().so_Prop = dropItem;
    //     // }
    // }
}