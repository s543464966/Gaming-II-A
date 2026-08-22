using System;
using UnityEngine;

[Serializable]
//======可序列化的玩家装备数据======//
public class SaveData_Equips
{
    [Header("模块: 装备基础存档数据")]
    [Tooltip("装备绑定的SO编号")] public string equipId; //装备绑定的SO编号
    [Tooltip("拥有数量")] public int getNum;  //拥有数量
    // public bool isEquipFight; //是否出战

}
