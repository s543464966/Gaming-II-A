using Unity.Mathematics;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using DG.Tweening;
using System.Linq;
using UnityEngine.UI;

public class S0007 : C_Ability_T //技能0007：吸血/伤害恢复类技能（当前逻辑被注释）
{
    public void Start()
    {
        SetSpeed(); //设置飞行速度
    }

    public override void Ability_Release()
    {
        
    }
}
