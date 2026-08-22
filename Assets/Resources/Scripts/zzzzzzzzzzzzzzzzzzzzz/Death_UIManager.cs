using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEditor;

public class Death_UIManager : MonoBehaviour
{
    // Start is called before the first frame update
    //控制死亡UI预制体
    void Start()
    {
        Time.timeScale = 0f;//死亡界面UI出现暂停游戏
        
    }
    void Awake()
    {
        
    }

 
    public void OnReplayButton()
    {   
        string currentSceneName = SceneManager.GetActiveScene().name;//获取当前场景的名字
        Time.timeScale = 1f;
        SceneManager.LoadScene(currentSceneName);
    }

    public void OnBackButton()
    {
        Time.timeScale = 1f;
        SceneManager.LoadScene("LoadScene");
    }

    public void OnQuitButton()
    {
        Time.timeScale = 1f;
        Application.Quit();
        //EditorApplication.ExitPlaymode();//退出Play测试模式
    }
}
