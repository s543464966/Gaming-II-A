using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public class Fight_UIManager : MonoBehaviour
{
    public GameObject[] sceneUI_0;//暗的场景功能数组
    public GameObject[] sceneUI_1;//亮的场景功能数组
    private bool isSetting = false;//显示设置界面首先为false
    public GameObject settingUI;//设置UI对象
    public GameObject gameLevelsUI;//关卡界面
    public GameObject gameLevelsUIMask;//关卡的遮罩
    public GameObject gameLevelsReturnButton;//
    // Start is called before the first frame update
    //加载动画的Canvas
    public Loading_UIManager loading_UIManager;
    //各页面下的实例对象数组
    public GameObject[] fight_GameObjs;//Fight页面
    public GameObject[] store_GameObjs;//Store页面
    public GameObject[] equip_GameObjs;//Equip页面
    public GameObject[] talent_GameObjs;//Talent页面

    void Awake() {
        OnFightButton();//先初始化界面
    }
    void Start()
    {
        //这里或者Awake里来读取最初始的数据
    }

    // Update is called once per frame
    void Update()
    {
        
    }
    public void OnStarsButton()//打开星球场景
    {
        //SceneManager.LoadScene("Stars");
        gameLevelsUIMask.SetActive(true);
        gameLevelsUI.SetActive(true);
        gameLevelsReturnButton.SetActive(true);
    }

    public void CloseGameLevelUI()
    {
        gameLevelsUIMask.SetActive(false);
        //gameLevelsUI.SetActive(false);
        gameLevelsReturnButton.SetActive(false);
    }

    public void isSettingButton()//设置UI界面状态
    {
        isSetting = !isSetting;//取反操作
        settingUI.SetActive(isSetting);
        //Time.timeScale = 1f;
    }

    public void OnFightButton()//显示Fight场景UI
    {
        //将Fight 0-->1 
        sceneUI_0[0].SetActive(false);
        sceneUI_1[0].SetActive(true);
        //将其他的 1-->0
        //不显示
        sceneUI_1[1].SetActive(false);
        sceneUI_1[2].SetActive(false);
        sceneUI_1[3].SetActive(false);
        DisableUI(store_GameObjs);
        DisableUI(equip_GameObjs);
        DisableUI(talent_GameObjs);
        //显示
        sceneUI_0[1].SetActive(true);
        sceneUI_0[2].SetActive(true);
        sceneUI_0[3].SetActive(true);
        EnableUI(fight_GameObjs);
    }
    public void OnStoreButton()//显示Store场景
    {
        //SceneManager.LoadScene("Store");
        //将Store 0-->1 
        sceneUI_0[1].SetActive(false);
        sceneUI_1[1].SetActive(true);
        //将其他的 1-->0
        //不显示
        sceneUI_1[0].SetActive(false);
        sceneUI_1[2].SetActive(false);
        sceneUI_1[3].SetActive(false);
        DisableUI(fight_GameObjs);
        DisableUI(equip_GameObjs);
        DisableUI(talent_GameObjs);
        //显示
        sceneUI_0[0].SetActive(true);
        sceneUI_0[2].SetActive(true);
        sceneUI_0[3].SetActive(true);
        EnableUI(store_GameObjs);
    }

    public void OnEquipButton()//显示Equip场景
    {
        //SceneManager.LoadScene("Equip");
        //将Equip 0-->1 
        sceneUI_0[2].SetActive(false);
        sceneUI_1[2].SetActive(true);
        //将其他的 1-->0
        //不显示
        sceneUI_1[0].SetActive(false);
        sceneUI_1[1].SetActive(false);
        sceneUI_1[3].SetActive(false);
        DisableUI(fight_GameObjs);
        DisableUI(store_GameObjs);
        DisableUI(talent_GameObjs);
        //显示
        sceneUI_0[0].SetActive(true);
        sceneUI_0[1].SetActive(true);
        sceneUI_0[3].SetActive(true);
        EnableUI(equip_GameObjs);
    }

    public void OnStudyButton()//显示Study场景
    {
        //SceneManager.LoadScene("Study");
        //将Study 0-->1 
        sceneUI_0[3].SetActive(false);
        sceneUI_1[3].SetActive(true);
        //将其他的 1-->0
        //不显示
        sceneUI_1[0].SetActive(false);
        sceneUI_1[1].SetActive(false);
        sceneUI_1[2].SetActive(false);
        DisableUI(fight_GameObjs);
        DisableUI(store_GameObjs);
        DisableUI(equip_GameObjs);
        //显示
        sceneUI_0[0].SetActive(true);
        sceneUI_0[1].SetActive(true);
        sceneUI_0[2].SetActive(true);
        EnableUI(talent_GameObjs);
    }

    public void OnPlayButton()//点击Play按钮
    {
        
        //Debug.Log("OnClickplayButton");
        //SceneManager.LoadScene("Playing");//加载Playing场景
        //loading_UIManager.OnLoadButton("Playing");
        Loading_UIManager.Instance.OnLoadScene("Playing");
        //monsterRush.isCreateMonster();
        //playButton.gameObject.SetActive(false);
        
    }

    //禁用UI对象组
    void DisableUI(GameObject[] uiObjs)//接收UI组
    {
        foreach(GameObject uiObj in uiObjs)//对其中每个UI对象
        {
            if(uiObj.GetComponent<CanvasGroup>() == null)//检测是否拥有CanvasGroup组件
            {
                uiObj.AddComponent<CanvasGroup>();
            }
            CanvasGroup canvasGroup = uiObj.GetComponent<CanvasGroup>();//获得该组件
            canvasGroup.alpha = 0;//设置透明度为0隐藏
            canvasGroup.interactable = false;//禁止交互
            canvasGroup.blocksRaycasts = false;// 禁用触控
        }
    }
    //启用UI对象组
    void EnableUI(GameObject[] uiObjs)
    {
        foreach (GameObject uiObj in uiObjs)
        {
            if (uiObj.GetComponent<CanvasGroup>() == null)
            {
                uiObj.AddComponent<CanvasGroup>();
            }
            CanvasGroup canvasGroup = uiObj.GetComponent<CanvasGroup>();
            canvasGroup.alpha = 1;//恢复透明度
            canvasGroup.interactable = true;//允许交互
            canvasGroup.blocksRaycasts = true;// 允许触控
        }
    }
}
