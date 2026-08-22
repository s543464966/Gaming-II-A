using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

public class Equip_UIManager : MonoBehaviour
{

    public Inventory_UIManager inventory_UIManager;//获取子对象仓库的引用
    //private bool isInventoryUIMoving = false;// 仓库界面不能移动
    // Start is called before the first frame update
    void Start()
    {
        //获取子对象仓库的脚本组件
        //inventory_UIManager = GetComponentInChildren<Inventory_UIManager>();
        inventory_UIManager.UpdateInventory();//触发更新仓库事件
    }
    
    // Update is called once per frame
    void Update()
    {
        
    }

    public void OnFightButton()//跳转Fight场景
    {
        SceneManager.LoadScene("Main interface");
    }

    public void OnStoreButton()//跳转Store场景
    {
        SceneManager.LoadScene("Store");
    }

    public void OnStudyButton()//跳转Study场景
    {
        SceneManager.LoadScene("Study");
    }
}
