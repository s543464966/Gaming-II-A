using System.Collections;
using UnityEngine;

public class zzzStarmana004 : MonoBehaviour
{
    // public GameObject attacker;
    // GameObject attackerMask;
    // public float damage;
    // float speedSlow = -0.3f;
    // float atkArea = 5;
    // float timer = 10;
    // float num = 1;
    // // float interval = 1;

    // void Start()
    // {
    //     // attackerMask = gameObject;
    //     StartCoroutine(Tissls());
    // }

    // IEnumerator Tissls()
    // {
    //     while(true)
    //     {
    //         Collider2D[] objColiders = Physics2D.OverlapCircleAll(transform.position,atkArea,LayerMask.GetMask("Monster"));//寻找范围内的敌对层单位总数位置以碰撞器collider返回
    //             foreach ( Collider2D objColider in objColiders) 
    //             { 
                    
    //                 // objColider.gameObject.GetComponent<CC_Monster>().aeSlowSpeed = speedSlow;
    //                 Debug.Log("检查减速" + speedSlow);
                    
    //                 // if(num >= timer-1)objColider.gameObject.GetComponent<CC_Monster>().aeSlowSpeed = 0;
                
    //                 // objColider.gameObject.GetComponent<M_Damage_Monster>().Damage(damage*2,0,0);
    //             }
    //         num ++;
    //         if(num >= timer) 
    //         {
    //             Destroy(gameObject);
    //             yield break;
    //         }
    //         yield return new WaitForSeconds(1f);
    //     }
    // }
}
