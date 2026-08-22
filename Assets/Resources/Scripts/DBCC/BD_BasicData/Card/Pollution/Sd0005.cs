using System.Collections;
using UnityEngine;

public class Sd0005 : MonoBehaviour
{
    // [HideInInspector] public float damage;
    // [HideInInspector] public Vector2 pos;
    // [HideInInspector] public float effectAreaPlus;
    // float atkArea = 2f;
    // float keepTime = 3;
    // int n = 0;

    // void Start()
    // {
    //     StartCoroutine(MakeDamages());
    // }

    // IEnumerator MakeDamages()
    // {
    //     while(true)
    //     {
    //         n ++;
    //         Collider2D[] coliderObjs = Physics2D.OverlapCircleAll(pos,atkArea*(1+effectAreaPlus),LayerMask.GetMask("Monster"));//寻找范围内的敌对层单位总数位置以碰撞器collider返回
    //             foreach ( Collider2D coliderObj in coliderObjs) 
    //             { 
    //                 // coliderObj.GetComponent<M_Damage_Monster>().Damage(damage,0,0);
    //             }
    //         if(n >= keepTime)   //持续时间
    //         {
    //             Destroy(gameObject);
    //             yield break;
    //         }
    //         yield return new WaitForSeconds(1f);
    //     }
        
    // }
}
