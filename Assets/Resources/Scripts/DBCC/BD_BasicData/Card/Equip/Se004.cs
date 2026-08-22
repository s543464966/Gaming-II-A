using UnityEngine;

public class Se004 : C_Ability_T
{
    public void Start()
    {
        SetSpeed(); //设置飞行速度
    }

    // public override void UseSkill()
    // {

    //     //获取必要数据
    //     float mtk = hero.GetComponent<C_FightDamage>().mtk;

    //     //计算技能伤害数值  
    //     float realDamage = mtk;

    //     // target.GetComponent<C_FightDamage>().Get_RealDamage(realDamage);
    //     // Debug.Log("技能0001使用成功，造成伤害: " + realDamage);
    //     // target = null;
    // }
}