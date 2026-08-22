using System;
using System.Collections.Generic;
using System.Threading;
using TMPro;
using UnityEngine;
using UnityEngine.UI;
// using UnityEngine.UIElements;
public class zzzCC_Level : MonoBehaviour   //刷怪
{
    private int moneyGolden; //金币数
    private GameObject UI_TopBar;
    private GameObject MoneyBox;
    private GameObject pausedBox;
    private GameObject countdown;
    private bool paused;
    // public Text countdownText; // 用于显示倒计时的Text UI组件
    public float duration = 10.0f; // 设置倒计时的总时长（秒）
    private float timeLeft = 0f; // 剩余时间

    private DateTime startTime; // 倒计时开始时间

    public void Start() 
    {
        //初始化
        moneyGolden += zzzSD_Player.moneyGolden;   //获取金币
        MoneyBox = GameObject.Find("MoneyBox");  //获取展示金币的物体
        Sum_MoneyGolden(0); //展示金币
        pausedBox = GameObject.Find("Paused");
        countdown = GameObject.Find("Countdown");
        pausedBox.GetComponent<Button>().onClick.AddListener(PausedGame);
        paused = false;

        duration = duration * 60f;
        timeLeft = duration; // 初始化剩余时间为总时长
        startTime = DateTime.Now; // 记录倒计时开始的时间点
        // UpdateCountdownDisplay(); // 更新倒计时显示
    }

    private void Update() 
    {
        TimeSpan elapsedTime = DateTime.Now - startTime;
        float timePassed = (float)elapsedTime.TotalSeconds;

        // 更新剩余时间
        timeLeft = duration - timePassed;

        // 如果倒计时结束
        if (timeLeft <= 0)
        {
            timeLeft = 0; // 确保时间不会变成负数
            // EndCountdown(); // 触发倒计时结束的事件
        }
        else
        {
            UpdateCountdownDisplay(); // 更新倒计时的显示
        }
    }

    void UpdateCountdownDisplay()
    {
        // 将剩余时间转换为分钟和秒
        int minutes = (int)(timeLeft / 60);
        int seconds = (int)(timeLeft % 60);

        // 格式化显示倒计时
        countdown.GetComponentInChildren<TextMeshProUGUI>().text = string.Format("{0:00}:{1:00}", minutes, seconds);
    }

    public void PausedGame()    //暂停对战
    {
        if (paused == false)
        {
            Time.timeScale = 0;
            paused = true;
        }
        else
        {
            Time.timeScale = 1;
            paused = false;
        }
    }

    public void Sum_MoneyGolden(int _moneyGolden) 
    {
        zzzSD_Player.moneyGolden += _moneyGolden;   //修改金币
        MoneyBox.GetComponentInChildren<TextMeshProUGUI>().text = $"{zzzSD_Player.moneyGolden}";  //修改展示的金币数值
    }

    public void Paused(int _moneyGolden) 
    {
        zzzSD_Player.moneyGolden += _moneyGolden;   //修改金币
    }

    public void Sum_1(int _moneyGolden) 
    {
        zzzSD_Player.moneyGolden += _moneyGolden;   //修改金币
    }


}
