using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEngine.SceneManagement;
public class Victory_UIManager : MonoBehaviour
{
    //控制通关胜利UI预制体
    // Start is called before the first frame update
    
    void Start()
    {
        Time.timeScale = 0f;
        
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    public void OnNextButton()
    {
        int currentSceneIndex = SceneManager.GetActiveScene().buildIndex;//获取当前场景的索引 //规定好关卡在生成设置里的场景索引就好了
        Time.timeScale = 1f;
        SceneManager.LoadScene(currentSceneIndex + 1);//获取当前关卡场景索引+1 到达下一关
    }
    public void OnReplayButton()
    {
        int currentSceneIndex = SceneManager.GetActiveScene().buildIndex;//获取当前场景的索引
        Time.timeScale = 1f;
        SceneManager.LoadScene(currentSceneIndex);
    }
}
