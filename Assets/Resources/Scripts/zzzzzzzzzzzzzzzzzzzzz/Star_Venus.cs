using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

public class Star_Venus : MonoBehaviour
{
    // Start is called before the first frame update
    int currentLevelIndex = 1;//当前关卡的整形索引
    int unlockedLevelIndex;//通关了的关卡索引

    public GameObject victoryUIprefab;//通关UI预制体
    
    void Start()
    {
        //先读取
        unlockedLevelIndex = PlayerPrefs.GetInt("unlockedLevelIndex");

    }

    // Update is called once per frame
    void Update()
    {
        
    }

    public void triggerVictory()
    {
        if(currentLevelIndex > unlockedLevelIndex)//如果当前的关卡数大于通关数，并且触发胜利就保存当前关卡
        {
            unlockedLevelIndex = currentLevelIndex;//当前关卡数赋予通关数
            PlayerPrefs.SetInt("unlockedLevelIndex",unlockedLevelIndex);//保存当前通关数
        }
        //SceneManager.LoadScene("Stars");
        //打开VictoryUI预制体 
        GameObject endUICanvas = GameObject.FindGameObjectWithTag("EndScreenUI");//获得当前场景下的画布 //Tag作为关卡场景区分
        GameObject victoryUI = Instantiate(victoryUIprefab,endUICanvas.transform);//创建胜利UI的预制体
    }
}
