using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

public class Study_UIManager : MonoBehaviour
{
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        
    }
    public void OnHerosButton()
    {
        SceneManager.LoadScene("Heros");//跳转英雄界面
    }
    // public void OnFightButton()//跳转Fight场景
    // {
    //     SceneManager.LoadScene("Main interface");
    // }

    // public void OnStoreButton()//跳转Store场景
    // {
    //     SceneManager.LoadScene("Store");
    // }

    // public void OnEquipButton()//跳转Equip场景
    // {
    //     SceneManager.LoadScene("Equip");
    // }
}
