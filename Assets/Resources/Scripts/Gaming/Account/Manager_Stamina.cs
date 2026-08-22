using System;
using System.Collections;
using UnityEngine;

public class Manager_Stamina : MonoBehaviour
{
    //======体力管理器配置参数======//
    [Tooltip("体力上限")] public int MAX_STAMINA = 100; //体力上限
    public const int RECOVERY_SECONDS = 420; // 7分钟 = 420秒 
    //======体力管理器可修改参数======//
    [Tooltip("当前体力值")] public int CurrentStamina { get; private set; } //当前体力值
    public int SecondsUntilNextRecovery { get; private set; }// 当前体力恢复计时器
    private int staminaRecoverValue = 1;// 体力自恢复值
    //======事件订阅式数据传输======//
    public event Action<int> OnStaminaChanged; // 事件声明
    //======单例模式======//
    public static Manager_Stamina Instance { get; private set; }
    private DateTime _lastRecoveryTime;
    private Coroutine _recoveryCoroutine;// 体力恢复协程
    private void Awake()
    {
        if (Instance == null)
        {
            Instance = this;
            DontDestroyOnLoad(gameObject);
            //加载体力数据
            LoadStaminaData();
        }
        else
        {
            Destroy(gameObject);
        }
    }
    void Start()
    {
        //启动恢复体力协程
        if (_recoveryCoroutine != null) StopCoroutine(_recoveryCoroutine);
        _recoveryCoroutine = StartCoroutine(StaminaRecoveryRoutine());
    }
    //======加载体力数据（离线数据）以及首次登陆======//
    private void LoadStaminaData()
    {
        //判断是否为首次登陆
        CurrentStamina = MAX_STAMINA;
        SecondsUntilNextRecovery = RECOVERY_SECONDS;
        // CurrentStamina = PlayerPrefs.GetInt("CurrentStamina", MAX_STAMINA);
        // SecondsUntilNextRecovery = PlayerPrefs.GetInt("RecoveryTimer", RECOVERY_SECONDS);

        // // 获取上次退出时间
        // string lastExitTimeStr = PlayerPrefs.GetString("LastExitTime", "");
        // if (!string.IsNullOrEmpty(lastExitTimeStr))
        // {
        //     DateTime lastExitTime = DateTime.Parse(lastExitTimeStr);
        //     TimeSpan offlineTime = DateTime.Now - lastExitTime;

        //     // 计算离线期间可恢复的体力
        //     int totalOfflineSeconds = (int)offlineTime.TotalSeconds;
        //     int totalRecovery = totalOfflineSeconds / RECOVERY_SECONDS;
        //     int remainingSeconds = totalOfflineSeconds % RECOVERY_SECONDS;

        //     // 应用离线恢复
        //     if (totalRecovery > 0)
        //     {
        //         CurrentStamina = Mathf.Min(MAX_STAMINA, CurrentStamina + totalRecovery);
        //     }

        //     // 调整恢复计时器
        //     SecondsUntilNextRecovery = Mathf.Max(0, SecondsUntilNextRecovery - remainingSeconds);

        //     // 如果体力已满，重置计时器
        //     if (CurrentStamina >= MAX_STAMINA)
        //     {
        //         SecondsUntilNextRecovery = RECOVERY_SECONDS;
        //     }
        // }
        //更新体力UI
        StaminaChanged(); // 通知所有订阅者
    }
    //======增加体力======//
    public void AddStamina(int _amount)
    {
        CurrentStamina = Mathf.Clamp(CurrentStamina + _amount, 0, MAX_STAMINA);
        SaveStaminaData();
        //通知事件传输UI
        StaminaChanged(); // 通知所有订阅者
    }
    //======减少体力======//
    public void SubStamina(int _amount)
    {
        CurrentStamina = Mathf.Clamp(CurrentStamina - _amount, 0, MAX_STAMINA);
        SaveStaminaData();
        StaminaChanged(); // 通知所有订阅者
    }
    //======体力消耗广播订阅者======//
    private void StaminaChanged()
    {
        OnStaminaChanged?.Invoke(CurrentStamina); // 通知所有订阅者
    }
    //======保存体力数据======//
    private void SaveStaminaData()
    {
        // PlayerPrefs.SetInt("CurrentStamina", CurrentStamina);
        // PlayerPrefs.SetInt("RecoveryTimer", SecondsUntilNextRecovery);
        // PlayerPrefs.SetString("LastExitTime", DateTime.Now.ToString());
        // PlayerPrefs.Save();
    }
    //======游戏退出时保存体力======//
    public void OnGameQuit()
    {

    }
    //======体力恢复协程======//
    private IEnumerator StaminaRecoveryRoutine()
    {
        while (true)
        {
            // 等待1秒
            yield return new WaitForSeconds(1f);

            if (CurrentStamina < MAX_STAMINA)
            {
                SecondsUntilNextRecovery--;

                // 当倒计时结束，恢复体力
                if (SecondsUntilNextRecovery <= 0)
                {
                    AddStamina(staminaRecoverValue);
                    SecondsUntilNextRecovery = RECOVERY_SECONDS;//重置计时器
                    Debug.Log($"恢复" + staminaRecoverValue + "点体力，当前体力: {CurrentStamina}/{MAX_STAMINA}");
                }
            }
            else
            {
                // 体力已满时重置计时器
                SecondsUntilNextRecovery = RECOVERY_SECONDS;
            }
        }
    }
}
