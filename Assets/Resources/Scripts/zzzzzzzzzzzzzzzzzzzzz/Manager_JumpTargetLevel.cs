using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

public class Manager_JumpTargetLevel : MonoBehaviour
{
    // Start is called before the first frame update
    string targetLevel;//保留指定关卡进行跳转

    //点击关卡按钮后进行指定关卡跳转方法
    public void JumpToTargetLevel()
    {
        //将保存的引用进行判断
        if (targetLevel == "XG")//小怪
        {
            SceneManager.LoadScene("Fight01");
        }
        else if (targetLevel == "JY")//精英
        {
            SceneManager.LoadScene("Fight02");
        }
        else if (targetLevel == "Boss")//Boss
        {
            SceneManager.LoadScene("FightBoss");
        }
        else if (targetLevel == "BlackMarket")//黑市
        {
            SceneManager.LoadScene("BlackMarket");
        }
        else if (targetLevel == "Ruin")//遗迹
        {
            SceneManager.LoadScene("Ruins");
        }
        else if (targetLevel == "Supply")//补给
        {
            SceneManager.LoadScene("Supply");
        }
    }

    public void SaveToLevel(string level)//对外保存指定关卡接口
    {
        targetLevel = level;
    }
}
