using Unity.Mathematics;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class zzzzzzCC_Effect : MonoBehaviour
{
    // public void Ae_Stun(float _aeStun, float _damage) //击晕效果
    // {
    //     this.GetComponent<CC_Monster>().aeStunSpeed = -1;
    //     StartCoroutine(StunTimer(_aeStun));
    // }
    //     private IEnumerator StunTimer(float _aeStun)
    //     {
    //         // Debug.Log("击晕开始:" + _aeStun);
    //         yield return new WaitForSeconds(_aeStun);
    //         this.GetComponent<CC_Monster>().aeStunSpeed = 0;
    //         // Debug.Log("击晕结束" + this.GetComponent<Controller_Monster>().aeStunSpeed);   
    //     }

    // public void Ae_Burn(float _aeBurn)  //灼烧效果
    // {
    //     for(int i=0 ; i < _aeBurn ; i++)
    //     {
    //         StartCoroutine(BurnTimer(i));
    //     }
    // }
    //     private IEnumerator BurnTimer(float _aeBurn)
    //     {
    //         yield return new WaitForSeconds(_aeBurn);
    //         // Debug.Log("灼烧成功:" + _aeBurn + "次数:" + _aeBurn);
    //         // this.GetComponent<Controller_Monster>().aeStunSpeed = 0;
    //         // Debug.Log("灼烧结束" + this.GetComponent<Controller_Monster>().aeStunSpeed);   
    //     }

    // public void Ae_Posion(float _aePosion)  //中毒效果
    // {
    //     // float speed = _other.GetComponent<Controller_Monster>().speed;

    //     // this.GetComponent<Controller_Monster>().aeStunSpeed = -1;
    //     for(int i=0 ; i < _aePosion ; i++)
    //     {
    //         StartCoroutine(PosionTimer(i));
    //     }
    // }
    //     private IEnumerator PosionTimer(float _aePoint)
    //     {
    //         yield return new WaitForSeconds(_aePoint);
    //         // Debug.Log("灼烧成功:" + _aePoint + "次数:" + _aePoint);
    //         // this.GetComponent<Controller_Monster>().aeStunSpeed = 0;
    //         // Debug.Log("击晕结束" + this.GetComponent<Controller_Monster>().aeStunSpeed);   
    //     }
    // public void Ae_Freeze(float _aeFreeze) //冰冻效果
    // {
    //     this.GetComponent<CC_Monster>().aeStunSpeed = -1;
    //     StartCoroutine(FreezeTimer(_aeFreeze));
    // }
    //     private IEnumerator FreezeTimer(float _aeFreeze)
    //     {
    //         // Debug.Log("击晕开始:" + _aeFreeze);
    //         yield return new WaitForSeconds(_aeFreeze);
    //         this.GetComponent<CC_Monster>().aeStunSpeed = 0;
    //         // Debug.Log("击晕结束" + this.GetComponent<Controller_Monster>().aeStunSpeed);   
    //     }

    // public void Ae_Palsy(float _aePalsy) //麻痹效果
    // {
    //     this.GetComponent<CC_Monster>().aeStunSpeed = -1;
    //     StartCoroutine(PalsyTimer(_aePalsy));
    // }
    //     private IEnumerator PalsyTimer(float _aePalsy)
    //     {
    //         // Debug.Log("击晕开始:" + _aePalsy);
    //         yield return new WaitForSeconds(_aePalsy);
    //         this.GetComponent<CC_Monster>().aeStunSpeed = 0;
    //         // Debug.Log("击晕结束" + this.GetComponent<Controller_Monster>().aeStunSpeed);   
    //     }

    //击退
        // private;




    //嘲讽
        private float mockeryArea;
        private GameObject attackerMask;
        private GameObject attacker;
        // public void MockeryOn(float _atkArea, GameObject _attackerMask, GameObject _attacker) //开启
        // {
        //     mockeryArea = _atkArea;
        //     attackerMask = _attackerMask;
        //     attacker = _attacker;
        //     // GetComponent<M_Damage_Player>().MockeryState = 1;
        //     Collider2D[] _others = Physics2D.OverlapCircleAll(transform.position,mockeryArea,LayerMask.GetMask("Monster"));//寻找范围内的敌对层单位总数位置以碰撞器collider返回
        //         foreach ( Collider2D _other in _others) 
        //         { 
        //             _other.gameObject.GetComponent<CC_Monster>().player = attackerMask;
        //         }
        // }

        // public void MockeryOff() //关闭嘲讽
        // {
        //     Collider2D[] _others = Physics2D.OverlapCircleAll(transform.position,mockeryArea,LayerMask.GetMask("Monster"));//寻找范围内的敌对层单位总数位置以碰撞器collider返回
        //         foreach ( Collider2D _other in _others) 
        //         { 
        //             _other.gameObject.GetComponent<CC_Monster>().player = attacker;
        //         }
        // }
}

