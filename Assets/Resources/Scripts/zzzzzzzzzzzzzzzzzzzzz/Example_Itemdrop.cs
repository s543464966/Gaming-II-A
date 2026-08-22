using UnityEngine;


public class Example_Itemdrop : MonoBehaviour
{
    public Example_SO_Item_ZbXX example_SO_Item_ZbXX;
    public SpriteRenderer spriteRenderer;
    
    // Start is called before the first frame update
    void Start()
    {
        // spriteRenderer.sprite = example_SO_Item_ZbXX.itemSprite;

    }

    // Update is called once per frame
    void Update()
    {
        
    }

    public void OnTriggerEnter2D()
    {
        Debug.Log("被触发了");
        // Manager_Inventory.AddItem(example_SO_Item_ZbXX);//保存在仓库里
        Destroy(gameObject);//销毁挂载的对象
    }


}
