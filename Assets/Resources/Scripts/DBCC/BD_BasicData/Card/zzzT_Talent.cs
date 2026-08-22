using System;
using System.Collections.Generic;
using DG.Tweening;
using JetBrains.Annotations;
using UnityEngine;

public class zzzT_Talent : MonoBehaviour
{
}

//     //设定必要数据与组件
//     [HideInInspector] public GameObject target; //技能目标
//     [HideInInspector] public List<int> talentSelectedList; //天赋列表 （0-4,5-8,9-12,共计3类4层，通过索引获取对应天赋，0表示未选择，1表示选择）

//     //模块：Talent

//     // ----------------------------------------------------------------------------------------------------------

//     //模块：Entry
//     public void Update_TalentList(List<int> _talentSelectedList, Fight_EntryTrigger _fight_EntryTrigger) //更新天赋列表并激活天赋效果
//     {
//         //更新每层的天赋
//         talentSelectedList = _talentSelectedList;

//         //根据天赋列表，激活对应的天赋效果
//         for (int i = 0; i < talentSelectedList.Count; i++)
//         {
//             int talentIndex = talentSelectedList[i];
//             if(talentSelectedList[i] == 1)
//             {
//                 switch(i)
//                 {
//                     case 1:
//                         Talent01(_fight_EntryTrigger);
//                         break;
//                     case 2:
//                         Talent02(_fight_EntryTrigger);
//                         break;
//                     case 3:
//                         Talent03(_fight_EntryTrigger);
//                         break;
//                     case 4:
//                         Talent04(_fight_EntryTrigger);
//                         break;
//                     case 5:
//                         Talent05(_fight_EntryTrigger);
//                         break;
//                     case 6:
//                         Talent06(_fight_EntryTrigger);
//                         break;
//                     case 7:
//                         Talent07(_fight_EntryTrigger);
//                         break;
//                     case 8:
//                         Talent08(_fight_EntryTrigger);
//                         break;
//                     case 9:
//                         Talent09(_fight_EntryTrigger);
//                         break;  
//                     case 10:
//                         Talent10(_fight_EntryTrigger);
//                         break;
//                     case 11:
//                         Talent11(_fight_EntryTrigger);
//                         break;
//                     case 12:
//                         Talent12(_fight_EntryTrigger);
//                         break;
//                 }
//             }
//         }
//     }

//     //所有12种天赋效果
//     public virtual void Talent01(Fight_EntryTrigger _fight_EntryTrigger)
//     {
//         _fight_EntryTrigger.Add_Entry(gameObject,1,1);
//     }

//     public virtual void Talent02(Fight_EntryTrigger _fight_EntryTrigger)
//     {
//         _fight_EntryTrigger.Add_Entry(gameObject,1,1);
//     }

//     public virtual void Talent03(Fight_EntryTrigger _fight_EntryTrigger)
//     {
//         _fight_EntryTrigger.Add_Entry(gameObject,1,1);
//     }

//     public virtual void Talent04(Fight_EntryTrigger _fight_EntryTrigger)
//     {
//         _fight_EntryTrigger.Add_Entry(gameObject,1,1);
//     }

//     public virtual void Talent05(Fight_EntryTrigger _fight_EntryTrigger)
//     {
//         _fight_EntryTrigger.Add_Entry(gameObject,1,1);
//     }   

//     public virtual void Talent06(Fight_EntryTrigger _fight_EntryTrigger)
//     {
//         _fight_EntryTrigger.Add_Entry(gameObject,1,1);
//     }

//     public virtual void Talent07(Fight_EntryTrigger _fight_EntryTrigger)
//     {
//         _fight_EntryTrigger.Add_Entry(gameObject,1,1);
//     }

//     public virtual void Talent08(Fight_EntryTrigger _fight_EntryTrigger)
//     {
//         _fight_EntryTrigger.Add_Entry(gameObject,1,1);
//     }

//     public virtual void Talent09(Fight_EntryTrigger _fight_EntryTrigger)
//     {
//         _fight_EntryTrigger.Add_Entry(gameObject,1,1);
//     }

//     public virtual void Talent10(Fight_EntryTrigger _fight_EntryTrigger)
//     {
//         _fight_EntryTrigger.Add_Entry(gameObject,1,1);
//     }

//     public virtual void Talent11(Fight_EntryTrigger _fight_EntryTrigger)
//     {
//         _fight_EntryTrigger.Add_Entry(gameObject,1,1);
//     }

//     public virtual void Talent12(Fight_EntryTrigger _fight_EntryTrigger)
//     {
//         _fight_EntryTrigger.Add_Entry(gameObject,1,1);
//     }

//     //（待改进）一共是15个天赋和3个技能


// }
    // [HideInInspector] public Skill_Targets Skill_Targets; //技能目标管理器
    // [HideInInspector] public GameObject hero; //技能所属英雄
    // [HideInInspector] public float damage;//记录的伤害
    // [HideInInspector] public CC_Skill skill_script;
// }
    //技能特效[飞行物]

    //技能特效[瞬发]
    // public Canvas canvas;//自己的显示层级
    //======释放特效的对象======//
    // public GameObject usedSkill_Obj;//造成伤害的特效需要赋值这个变量

    // public GameObject target;
    //======记录技能的数值======//
    // [HideInInspector] public float damage;//记录的伤害
    // [HideInInspector] public float realDamage;//记录真实伤害
    // [HideInInspector] public float shield;//护盾
    // [HideInInspector] public float health;//生命值
    // //======特殊技能效果数值======//
    // [HideInInspector] public float attack_change;//增减攻击力
    // [HideInInspector] public int damage_offSet_Num;//伤害抵消次数
    //======释放对象的技能脚本======//
    // [HideInInspector]public CC_Skill skill_script;

    // [HideInInspector] public Rigidbody2D rigidBody;

    // public virtual void UseSkill()
    // {
    //     //各自特效重新维护
    // }


    ////// ----- 通用技能特效释放方法 ----- //////
    // public void SetSpeed() //操控飞行；
    // {
    //     float basicSpeed = 1200f; // 基础飞行速度
    //     Vector2 direction = target.transform.position - transform.position;
    //     float targetAngle = Mathf.Atan2(direction.y, direction.x) * Mathf.Rad2Deg;
    //     transform.rotation = Quaternion.Euler(0, 0, targetAngle);
    //     // Vector2 direction = target.transform.position - tx.transform.position;
    //     // float targetAngle = Mathf.Atan2(direction.y, direction.x) * Mathf.Rad2Deg - 90f;
    //     // Tween rotateTween = tx.transform.DORotate(new Vector3(0, 0, targetAngle), moveDuration / 5)
    //     //  .SetEase(Ease.InOutSine);
    //     // childSequence.Append(rotateTween);
    //     DG.Tweening.Sequence childSequence = DOTween.Sequence();
    //     Debug.Log("成功创建特效实例");
    //     GetComponent<Animator>().SetTrigger("isAttacking");
    //     //  移动到目标
    //     float distance = Vector3.Distance(transform.position, target.transform.position); ;// 计算移动距离和飞行时间
    //     float time = distance / basicSpeed;
    //     Tween moveTween = transform.DOMove(target.transform.position, time)//由慢到快，较强加速感
    //         .SetEase(Ease.InCubic);
    //     childSequence.Append(moveTween);
    //     //  动画完成后减少计数器
    //     childSequence.OnComplete(() =>
    //     {
    //         // activeTweens--;
    //         // 减少透明度
    //         // GetComponent<Image>().DOFade(0f, time / 3);
    //         // 让特效修改为结束状态
    //         // UseSkill();
    //         GetComponent<Animator>().SetTrigger("isAttacked");
    //         // });
    //     });

    // }
    // public void SetPositon()    //设置特效位置
    // {
    //     transform.position = target.transform.position;
    //     // UseSkill();
    // }

    // public void SetPositon()    //设置特效位置
    // {
    //     transform.position = target.transform.position;
    //     UseSkill();
    // }


    ///     //======技能动画结束的销毁回调======//
    // public void SkillTX_Destroy()
    // {
    //     //效果触发将计数器减少
    //     Skill_Targets.ActionSkillEffect_Complate();
    // }
    // public void AnimationEnd()
    // {
    //     //动画播放结束，销毁自己
    //     Destroy(this);
    // }

    // ////// ----- 碰撞触发检测 ----- //////
    // private void OnTriggerEnter2D(Collider2D other)//other为目标卡牌
    // {
    //     if (other.gameObject == target)//&& damage != 0)
    //     {
    //         UseSkill(target);
    //     }

    //     // 减少透明度
    //     // GetComponent<Image>().DOFade(0f, time / 3);
    //     // 让特效修改为结束状态
    //     GetComponent<Animator>().SetTrigger("isAttacked");
    // } 

    // public void SkillTX_AnimationEnd()
    // {
    //     //销毁前将计数器减少
    //     hero.GetComponent<Skill_Targets>().ActionSkillEffect();
    //     Destroy(gameObject);
    // }

    //======销毁特效======//
    // public void SkillTX_Destroy()
    // {
    //     Destroy(gameObject);
    // }

    //======造成伤害的技能效果回调======//

    // public void OnCallBack_Damage()
    // {
    //     if (target != null)
    //     {
    //         //当特效达到一定时候回调造成伤害
    //         // Debug.Log("释放目标："+target.name+"数值为："+damage);
    //         //给目标造成伤害
    //         // target.GetComponent<C_Damage>().GetAtkDamage(damage);
    //         if (usedSkill_Obj == null)
    //         {
    //             Debug.Log("usedSkill_Obj为空,没有赋值");
    //             return;
    //         }
    //         //  这里可以调用被攻击的卡牌的受击反馈动画
    //         Vector2 hitDirection = (target.transform.position - usedSkill_Obj.transform.position).normalized;//方向向量
    //         target.GetComponent<FightCard>().Hit_Normal_FeedbackAction(hitDirection);
    //     }
    // }

    //======造成真实伤害的技能效果回调======//
    // public void OnCallBack_RealDamage()
    // {
    //     if (target != null)
    //     {
    //         //当特效达到一定时候回调造成伤害
    //         Debug.Log("释放目标：" + target.name + "数值为：" + realDamage + "伤害为真实伤害");
    //         //给目标造成真实伤害
    //         target.GetComponent<C_Damage>().GetRealDamage(realDamage);
    //         if (usedSkill_Obj == null)
    //         {
    //             Debug.Log("usedSkill_Obj为空,没有赋值");
    //             return;
    //         }
    //         //  这里可以调用被攻击的卡牌的受击反馈动画
    //         Vector2 hitDirection = (target.transform.position - usedSkill_Obj.transform.position).normalized;//方向向量
    //         target.GetComponent<FightCard>().Hit_RealDamage_FeedbackAction();
    //     }
    // }
    // //======施加护盾的技能效果回调======//
    // public void OnCallBack_Shield()
    // {
    //     if (target != null)
    //     {
    //         Debug.Log("释放目标：" + target.name + "数值为：" + shield);
    //         //给目标施加护盾
    //         target.GetComponent<C_Damage>().GetDp(shield);
    //     }
    // }
    // //======恢复生命值的技能效果回调======//
    // public void OnCallBack_Health()
    // {
    //     if (target != null)
    //     {
    //         Debug.Log("释放目标：" + target.name + "数值为：" + health);
    //         //给目标施加护盾
    //         target.GetComponent<C_Damage>().GetHP(health);
    //     }
    // }
    // //======增减攻击力的技能效果回调======//
    // public void OnCallBack_AtkChange()//[这里不做增减的区分，需要传入时做区分]
    // {
    //     if (target != null)
    //     {
    //         Debug.Log("释放目标：" + target.name + "数值为：" + attack_change);
    //         //给目标增减攻击力数值
    //         target.GetComponent<C_Damage>().SumAtk(attack_change);
    //         //负面buff影响反馈，先用真伤的测试
    //         target.GetComponent<FightCard>().Hit_RealDamage_FeedbackAction();
    //     }
    // }
    // //======添加伤害抵消的技能效果回调======//
    // public void OnCallBack_DamageOffset()//[这里不做增减的区分，需要传入时做区分]
    // {
    //     if (target != null)
    //     {
    //         Debug.Log("释放目标：" + target.name + "伤害抵消次数增加为：" + damage_offSet_Num);
    //         //给目标添加伤害抵消
    //         target.GetComponent<C_Damage>().Set_Damage_Offset(damage_offSet_Num);
    //         //增益buff的反馈
    //         target.GetComponent<FightCard>().Add_Buff_FeedbackAction();
    //     }
    // }
