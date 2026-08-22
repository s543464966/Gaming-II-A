// using System;
// using System.Collections;
using System.Collections.Generic;
using UnityEngine;
// using System.Runtime.CompilerServices;
// using Unity.Mathematics;
// using Unity.VisualScripting;
// using UnityEditor.Tilemaps;
// using UnityEngine.PlayerLoop;
// using UnityEngine.UIElements;

public class Protection : MonoBehaviour
{
    //获取初始化组件:
    [Tooltip("设定武器OS数据")] public SO_Equip weapon_SO_Data;

    //初始化实时数据:
    // [HideInInspector] public GameObject attacker;
    [HideInInspector] public string equipVar;
    [HideInInspector] public Sprite equipSprite;
    [HideInInspector] public string equipName;
    [HideInInspector] public float ar;
    [HideInInspector] public float arMax;
    [HideInInspector] public float ad;
    [HideInInspector] public float adMax;
    [HideInInspector] public float Charge;
    [HideInInspector] public int ChargeMax;
    // [HideInInspector] public float atkChargeTime;
    [HideInInspector] public float weightItem;

    //初始化实时数据:
    protected Transform parent;

    
}