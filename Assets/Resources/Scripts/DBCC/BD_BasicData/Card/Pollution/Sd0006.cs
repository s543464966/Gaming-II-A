using System.Collections;
using UnityEngine;

public class Sd0006 : MonoBehaviour
{
    // [HideInInspector] public float damage;
    // [HideInInspector] public float effectAreaPlus;
    // float moveSpeedPlus = -0.15f;
    // float atkArea = 10;
    // float keepTime = 5;
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
    //         Collider2D[] coliderObjs = Physics2D.OverlapCircleAll(transform.position,atkArea*(1+effectAreaPlus),LayerMask.GetMask("Monster"));//寻找范围内的敌对层单位总数位置以碰撞器collider返回
    //             foreach ( Collider2D coliderObj in coliderObjs) 
    //             { 
    //                 StartCoroutine(MakeEffect(coliderObj));
    //                 // coliderObj.GetComponent<M_Damage_Monster>().Damage(damage,0,0);
    //                 Debug.Log("sm1001造成伤害"+damage);
    //             }
    //         if(n >= keepTime)   //持续时间
    //         {
    //             Destroy(gameObject);
    //             yield break;
    //         }
    //         yield return new WaitForSeconds(1f);
    //     }

    // }
    // IEnumerator MakeEffect(Collider2D _coliderObj)
    // {
    //     _coliderObj.GetComponent<CC_Monster>().moveSpeedPlus += moveSpeedPlus;   //施加减速
    //     yield return new WaitForSeconds(1f);
    //     if(_coliderObj != null )
    //     {
    //         _coliderObj.GetComponent<CC_Monster>().moveSpeedPlus -= moveSpeedPlus;   //恢复减速
    //     }
    // }
}
