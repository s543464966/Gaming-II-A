using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class C_Blank : MonoBehaviour
{
    [Header("模块: UI与逻辑组件")]
    [Tooltip("卡牌备战席")] public Conflict_Prepare Conflict_Prepare;
    public int posIndex;

    // ==========================================
    // 1. 用户交互接口层操作区 (Interactions)
    // ==========================================

    /// <summary>
    /// 打开备战席面板
    /// 负责: 记录当前位序号索引并展开指定配置属性的备战容器视窗
    /// </summary>
    /// <param name="_posIndex">指定的占位索引</param>
    public void OnBtn_ShowPrepareArea(int _posIndex)
    {
        Conflict_Prepare.Open_DeployPrepare(_posIndex);
    }

}
