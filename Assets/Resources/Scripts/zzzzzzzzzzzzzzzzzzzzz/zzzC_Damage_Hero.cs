using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UIElements;

// public class zzzC_Damage_Hero : C_Damage  // 通过每个设定好的SO_CharactorData来给相应角色赋值。
// {
//     // [HideInInspector] public GameObject bossHpRed;

//     // public void AttackTarget(GameObject _target)  //对目标造成伤害
//     // {
//     //     _target.GetComponent<C_Damage_Monster>().AttackDamage(atk);
//     // }


//     // public void Damage(float _damage, int _atkCrit, float _atkCritDamge) //造成伤害
//     // {
//     //     if(_atkCrit > 0) //判断是否暴击
//     //     {
//     //         System.Random random = new System.Random();
//     //         int randomValue = random.Next(1, 101);
//     //         if(_atkCrit >= randomValue)
//     //         {
//     //             _damage = _damage * ( 2f + _atkCritDamge);
//     //         }
//     //         SumDamage(_damage);   //造成伤害
//     //     }
//     //     else 
//     //     {
//     //         SumDamage(_damage);   //造成伤害
//     //     }
//     // }

//     // public void SumDamage(float _damage) //造成伤害
//     // {
//     //     if(_damage > 0)
//     //     {
//     //         _damage = _damage - apr;
//     //         ShowDamageTest(transform.position,""+_damage,Color.red); //展示伤害飘字
//     //         if(_damage > 0)
//     //         {
//     //             hp -= _damage;
//     //             if(SO_Monster.monsterRank == 0) {bossHpRed.GetComponent<BossHp>().SetHP(new Vector3 (hp/hpMax,1,1));}
//     //             if(hp <= 0) //判断为死亡
//     //             {
//     //                 GetComponent<CC_Monster>().OnDie();
//     //                 // if(SO_Monster.monsterRank > 1) { GetStarmana(); } //击杀高阶怪物获得一个星能之力
//     //                 // Destroy(gameObject); 
//     //             }
//     //         }
//     //     }
//     // } 
//     // public void RushWaveImprove(int _Wave) //造成伤害
//     // {
//     //     hp = hp + _Wave;
//     // }

//     // public void GetStarmana() //击杀高阶怪物获得一个星能之力
//     // {
//     //     Fighting_StarmanaSelect.GetComponent<Fighting_StarmanaSelect>().StarmanaSortingNum(1);
//     // }
// }