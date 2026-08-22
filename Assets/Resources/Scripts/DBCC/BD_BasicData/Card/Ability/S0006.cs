using Unity.Mathematics;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using DG.Tweening;
using System.Linq;

public class S0006 : C_Ability_T //技能0006：范围伤害技能
{
    public void Start()
    {
        SetPositon();
    }
    public override void Ability_Release()
    {
        //获取必要数据
        //获取必要数据：施法者的魔法攻击力
        float mtk = hero.GetComponent<C_FightDamage>().mtk;

        //计算技能伤害数值  
        //计算技能伤害数值：攻击力 * 倍率
        // float damage = mtk * SO_Skill_Data.mtkRatio;

        //获取所有带有"GwCard"标签的游戏对象
        GameObject[] targetsArea = GameObject.FindGameObjectsWithTag("Monster");
        List<GameObject> targetList = new List<GameObject>(targetsArea);
        foreach (GameObject targetArea in targetsArea)
        {
            Vector3 pos = targetArea.transform.position;
            float deltaX = Mathf.Abs(pos.x - transform.position.x); // X轴距离（绝对值）
            float deltaY = Mathf.Abs(pos.y - transform.position.y); // Y轴距离（绝对值）

            //判断目标是否在攻击范围内（X轴距离小于350，Y轴距离小于200）
            if (deltaX < 350f & deltaY < 200f) //X
            {
                // targetArea.GetComponent<C_FightDamage>().Get_AtkDamage(damage);
            }
            //或者（X轴距离小于200，Y轴距离小于320）
            else if (deltaX < 200f & deltaY < 320f) //Y
            {
                // targetArea.GetComponent<C_FightDamage>().Get_AtkDamage(damage);
            }
        }
    }
}