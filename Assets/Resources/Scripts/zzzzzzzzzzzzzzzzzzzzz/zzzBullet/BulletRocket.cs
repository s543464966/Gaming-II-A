using System.Collections;
using System.Collections.Generic;
using System.Reflection;
using TMPro;
using Unity.Mathematics;
using Unity.VisualScripting;
using UnityEngine;

public class BulletRocket : MonoBehaviour
{
    [Tooltip("子弹飞行速度")]
    public float flySpeed = 15;
    [Tooltip("子弹伤害")]
    public float atk;
    public float lerp;
    public GameObject explosionPrefab;
    private Rigidbody2D rigidBody;
    private Vector3 targetPos;
    private Vector3 direction;
    private bool arrived;

    void Awake()
    {
        rigidBody = GetComponent<Rigidbody2D>();
    }

    public void SetTarget(Vector2 _target)
    {
        arrived = false;
        targetPos = _target;
    }

    private void FixedUpdate()
    {
        direction = (targetPos - transform.position).normalized;

        if(!arrived)
        {
            transform.right = Vector3.Slerp(transform.right,direction,lerp/Vector2.Distance(transform.position,targetPos));
            rigidBody.velocity = transform.right * flySpeed;
        }
        if(Vector2.Distance(transform.position,targetPos)<= 1f && !arrived)
        {
            arrived = true;
        }

    }

    // private void OnTriggerEnter2D(Collider2D other)
    // {
    //     if (other.gameObject.layer == LayerMask.NameToLayer("Monster"))
    //     {
    //         Instantiate(explosionPrefab,transform.position,quaternion.identity);
    //         if( other.gameObject.GetComponent<M_Damage_Monster>() != null)
    //         {
    //             // other.gameObject.GetComponent<M_Damage_Monster>().Damage(atk,0,0);
    //         }
    //         Destroy(gameObject);
    //     }
    // }
}
