using System.Collections;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class Stamina_UIManager : MonoBehaviour
{
    //======体力相关UI引用======//
    public TMP_Text staminaCount;
    public Image staminaIcon;
    //======体力相关数据引用======//
    private int MAX_STAMINA;    //体力上限
    void OnEnable() //每次激活时
    {
        MAX_STAMINA = Manager_Stamina.Instance.MAX_STAMINA; //获取体力上限
        // 进入主页面时订阅事件
        Manager_Stamina.Instance.OnStaminaChanged += UpdateStaminaUI;
        // 初始化显示
        UpdateStaminaUI(Manager_Stamina.Instance.CurrentStamina);
    }
    void Start()
    {

    }

    void OnDisable() //每次取消激活时
    {
        // 离开主页面时取消订阅
        Manager_Stamina.Instance.OnStaminaChanged -= UpdateStaminaUI;
    }
    //======更新体力UI======//
    private void UpdateStaminaUI(int _currentStamina)
    {
        staminaCount.text = new string(_currentStamina + "/" + MAX_STAMINA);
    }
}
