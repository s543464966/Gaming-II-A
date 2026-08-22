using System.Collections;
using System.Collections.Generic;
using UnityEngine;

// [CreateAssetMenu]
public class Example_SO_Item : MonoBehaviour
{
    //一个例子
    [Tooltip("物品图片")]
    public Sprite itemSprite;
    [Tooltip("物品名字")]
    public string itemName;
    [Tooltip("攻击力")]
    public int atk;
    [Tooltip("生命值")]
    public int hp;

    public string itemType;//类型

    public int oxy;//氧气

    public int ar;//护甲
}
