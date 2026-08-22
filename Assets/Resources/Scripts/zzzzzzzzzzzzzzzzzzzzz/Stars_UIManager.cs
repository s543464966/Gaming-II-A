using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public class Stars_UIManager : MonoBehaviour
{
    public GameObject[] galaxysUI_0;//星系按钮数组暗的
    public GameObject[] galaxysUI_1;//星系按钮数组亮的
    // Start is called before the first frame update
    public Button[] starsButton;//保存星球按钮数组；
    private int unlockedLevelIndex;//关键在于获取解锁关卡数

    void Start()
    {
        unlockedLevelIndex = PlayerPrefs.GetInt("unlockedLevelIndex");//先获取解锁的关卡数
        Debug.Log(unlockedLevelIndex);
        for(int i = 0; i < starsButton.Length ; i++)//先全部按钮取消交互性
        {
            starsButton[i].interactable = false;
        }

        for(int i = 0; i <=unlockedLevelIndex ; i++)//通过获取解锁的关卡数后进行后一关的交互性
        {
            starsButton[i].interactable = true;
        }
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    public void OnVenusStarButton()
    {
        SceneManager.LoadScene("_VenusStar");
    }
    public void OnReturnButton()
    {
        SceneManager.LoadScene("Main interface");
    }
    public void OnFirstButton_0()
    {
        galaxysUI_1[0].SetActive(true);
        galaxysUI_0[1].SetActive(true);
        galaxysUI_0[2].SetActive(true);
        galaxysUI_0[3].SetActive(true);
        //隐藏
        
        galaxysUI_1[1].SetActive(false);
        galaxysUI_1[2].SetActive(false);
        galaxysUI_1[3].SetActive(false);
    }
    public void OnSecondButton_0()
    {
        //隐藏其他星系的1显示0；
        //显示
        galaxysUI_1[1].SetActive(true);
        galaxysUI_0[0].SetActive(true);
        galaxysUI_0[2].SetActive(true);
        galaxysUI_0[3].SetActive(true);
        //隐藏
        galaxysUI_1[0].SetActive(false);
        galaxysUI_1[2].SetActive(false);
        galaxysUI_1[3].SetActive(false);
    }

    public void OnThirdButton_0()
    {
        // Transform child = transform.Find("Btn_Stars_First");//寻找第一星系的对象
        // GameObject childGameObject = child.gameObject;
        // childGameObject.SetActive(false);
        //显示
        galaxysUI_1[2].SetActive(true);
        galaxysUI_0[0].SetActive(true);
        galaxysUI_0[1].SetActive(true);
        galaxysUI_0[3].SetActive(true);
        //隐藏
        galaxysUI_1[0].SetActive(false);
        galaxysUI_1[1].SetActive(false);
        galaxysUI_1[3].SetActive(false);
        
    }

    public void OnFourthButton_0()
    {
        //显示
        galaxysUI_1[3].SetActive(true);
        galaxysUI_0[0].SetActive(true);
        galaxysUI_0[1].SetActive(true);
        galaxysUI_0[2].SetActive(true);
        //隐藏
        galaxysUI_1[0].SetActive(false);
        galaxysUI_1[1].SetActive(false);
        galaxysUI_1[2].SetActive(false);
    }
}
