using System.Collections;
using System.Collections.Generic;
using UnityEngine;

//======关卡增益场景初始化总控======//
// public class Init_LevelBuff : MonoBehaviour
// {
//     [Header("关卡配置")]
//     // public SO_Level levelSOData; //关卡SO数据类
//     private Level currentLevel; //当前关卡数据类
//     //======休整点关卡模块======//
//     public GameObject restUnit;
//     //...后续关卡类型模块

//     //======根据进入的关卡类型激活并初始化对应模块======//
//     void Awake()
//     {
//         //读取关卡管理器获取关卡类型数据
//         // currentLevel = CC_Chapter.Instance.GetCurrentLevelData();
//         // levelSOData = currentLevel.levelData;

//         //区分关卡类型进行激活并实现对应模块
//         // if (levelSOData.type == LevelType.Rest)
//         // {
//         //     //休整点UI模块
//         //     RestUnitEnter();
//         // }
//     }
//     //======休整点UI模块入口======//
//     private void RestUnitEnter()
//     {
//         //激活模块
//         if (restUnit.activeSelf == false) restUnit.SetActive(true);
//         // restUnit.GetComponent<Rest_UIManager>().levelSOData = levelSOData;
//     }
//     //======下一关按钮======//
//     public void OnNextLevelButton()
//     {

//         //先触发跳转场景，然后马上调整关卡页面实例canvas顺序
//         if (Loading_UIManager.Instance != null) Loading_UIManager.Instance.OnLoadScene("Home");
//         //调整关卡页面canvas顺序
//         if (Chapter_UI.Instance != null) Chapter_UI.Instance.AddCanvasOrder();

//     }
//     //======返回按钮======//
//     public void OnReturnHomeButton()
//     {
//         //先触发跳转场景，然后马上调整关卡页面实例canvas顺序
//         if (Loading_UIManager.Instance != null) Loading_UIManager.Instance.OnLoadScene("Home");
//         //调整关卡页面canvas顺序
//         if (Chapter_UI.Instance != null) Chapter_UI.Instance.AddCanvasOrder();
//     }
// }
