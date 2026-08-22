using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UIElements;

public class Sd0002 : MonoBehaviour
{
    // [HideInInspector] public float damage;
    // [HideInInspector] public float atkcrit;
    // [HideInInspector] public float atkcritDamage;
    // [HideInInspector] public float effectAreaPlus;
    // float atkArea = 5;
    // float waitTime = 5f;

    // void Start()
    // {
    //     StartCoroutine(Explosion());
    //     // atkArea += effectAreaPlus;
    // }

    // IEnumerator Explosion()
    // {
    //         yield return new WaitForSeconds(waitTime);
    //         Collider2D[] _others = Physics2D.OverlapCircleAll(transform.position,atkArea*(1+effectAreaPlus),LayerMask.GetMask("Monster"));//寻找范围内的敌对层单位总数位置以碰撞器collider返回
    //             foreach ( Collider2D _other in _others) 
    //             { 
    //                 // _other.gameObject.GetComponent<M_Damage_Monster>().Damage(damage,0,0);
    //             }
    //         Destroy(gameObject);
    // }
}
