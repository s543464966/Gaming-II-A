using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.UI;

public class C_Level : MonoBehaviour
{
    [Header("模块: 关卡结构引配")]
    [Tooltip("该关卡数据类")] private Level thisLevelData; // 该关卡数据类
    [Tooltip("关卡前进的路线(路面图片)")] public List<Image> LevelRoad; // 关卡前进的路线(路面图片)
    [Tooltip("关卡状态UI反映")] public Image levelStateUI; // 关卡状态UI反映
    
    // --- 内部状态 --- (节点管理器)
    [HideInInspector] public LevelRoute_UI LevelRoute_UI; // 章节路线管理脚本

    // ==========================================
    // 1. 初始化预处理与绑定 (Initial)
    // ==========================================

    /// <summary>
    /// 【核心】绑定下级装载与初次刷新
    /// </summary>
    /// <param name="_level">独立携带的纯净关卡结构</param>
    /// <param name="_levelRoute_UI">所属控制的统一路由台管理器</param>
    public void Init_LevelBtnUI(Level _level, LevelRoute_UI _levelRoute_UI)
    {
        LevelRoute_UI = _levelRoute_UI;
        thisLevelData = _level; //保存引用的level数据

        Bind_LevelStateEvent();
        Update_LevelUI();
    }

    private void OnEnable()
    {
        Bind_LevelStateEvent();
        Update_LevelUI();
    }

    private void OnDisable()
    {
        // 销毁或失活时必须解绑，防爆内存
        if (thisLevelData != null)
        {
            thisLevelData.OnLevelStateChangedEvent -= Update_LevelUI;
        }
    }

    /// <summary>
    /// 绑定节点状态更新事件
    /// </summary>
    void Bind_LevelStateEvent()
    {
        if (thisLevelData == null) return;

        thisLevelData.OnLevelStateChangedEvent -= Update_LevelUI;
        thisLevelData.OnLevelStateChangedEvent += Update_LevelUI;
    }

    // ==========================================
    // 2. 状态刷新重绘
    // ==========================================

    /// <summary>
    /// 【核心】节点装束分发式渲染与反挂
    /// 负责: 1.切换层内Icon态, 2.重定向多岔路开关贴图, 3.处理安全禁点并更新组件可交互态
    /// </summary>
    public void Update_LevelUI()
    {
        if (thisLevelData == null) return;

        //根据level存储的情况，来显示相应的UI
        levelStateUI.sprite = thisLevelData.levelTypeIcon; //关卡类型图标

        //当前关卡的三条路线是否存在UI现实
        for (int i = 0; i < LevelRoad.Count; i++)
        {
            if (thisLevelData.levelrRoad[i] == null)
            {
                LevelRoad[i].gameObject.SetActive(false);
                continue;
            }
            LevelRoad[i].sprite = thisLevelData.levelrRoad[i];
        }
        
        //  这里可以防止玩家在查看章节路线的时候重复点击当前关卡造成性能浪费
        if(thisLevelData.isUnlocked == false)  //未解锁
        {
            GetComponent<Button>().interactable = false;
        }
        else    //已解锁
        {
            if(thisLevelData.isCompleted == true)  //已完成
            {
                GetComponent<Button>().interactable = false;
            }
            else    //未完成
            {
                if(thisLevelData.isBeforeSelecting == true)    //正在被前面的关卡选择路线
                {
                    GetComponent<Button>().interactable = true;
                }
                else if(thisLevelData.isSelected == true) // 当前正在挑战的关卡
                {
                    GetComponent<Button>().interactable = true;
                }
                else    //未被前面的关卡进行选择路线 即Not或当前进行的关卡
                {
                    GetComponent<Button>().interactable = false;
                }   
            }
        }
    }

    //======星级情况======//
    // private void UpdateStarBarUI()
    // {
    //     if (thisLevelData.isCompleted == true)
    //     {
    //         starBar.SetActive(true);
    //         //根据星级情况创建UI动画
    //     }
    // }


    // ==========================================
    // 3. UI层回调事件区 (Interactions)
    // ==========================================

    /// <summary>
    /// 按钮操作捕获总接口
    /// 负责: 委托 Sys_Chapter 系统处理节点选择逻辑
    /// </summary>
    public void OnBtn_LevelEnter()
    {
        if (thisLevelData != null && thisLevelData.isSelected == true)
        {
            Debug.LogWarning("你已经在此关卡内了。");
            return;
        }

        if (LevelRoute_UI != null)
        {
            LevelRoute_UI.On_LevelNodeClicked(thisLevelData);
        }
    }
}
