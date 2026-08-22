using Unity.Mathematics;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class zzzBullet : MonoBehaviour
{
    //传入通用属性
    [HideInInspector] public float flySpeed; // 子弹飞行速度
    [HideInInspector] public GameObject attacker;   //攻击者
    [HideInInspector] public float damage;  //伤害
    [HideInInspector] public int atkPierce; //穿透次数
    [HideInInspector] public int atkCrit;
    [HideInInspector] public float atkCritDamage;

    //通用属性
    public GameObject explosionPrefab;
    [HideInInspector] public Rigidbody2D rigidBody;
    [HideInInspector] public HashSet<Collider2D> HashCollider = new HashSet<Collider2D>();
    [HideInInspector] public int atkPierceNum;  //穿透次数记录，初始为1

    public void Awake()
    {
        rigidBody = GetComponent<Rigidbody2D>();
        
        //初始化通用属性
        atkPierce = 1;
        flySpeed = 20f;
    }
    private void Start() 
    {
        StartCoroutine(DestroyObj());
    }

    public void SetSpeed(Vector2 direction) //施加飞行的力；
    {
        rigidBody.velocity =  direction * flySpeed;
    }

    // public virtual void OnTriggerEnter2D(Collider2D _other) //与怪物碰撞，触发数值与伤害。
    // { 
    //     if (_other.gameObject.layer == LayerMask.NameToLayer("Monster") && !HashCollider.Contains(_other))
    //     {
    //         atkPierceNum ++;
    //         Instantiate(explosionPrefab,transform.position,quaternion.identity);//击中展示爆炸效果
    //         if( _other.gameObject.GetComponent<M_Damage_Monster>() != null)
    //         {
    //             //数据传递：攻击者（attacker）
    //             // _other.GetComponent<M_Damage_Monster>().attacker = attacker;
    //             // _other.gameObject.GetComponent<M_Damage_Monster>().Damage(damage,atkCrit,atkCritDamage);
    //             HashCollider.Add(_other);
    //             if(atkPierceNum >= atkPierce)
    //             {
    //                 HashCollider.Remove(_other);
    //                 Destroy(gameObject);
    //             }
    //         }
    //         // damage -= damage * -0.2f; // 伤害每穿透一次都会衰减一次
    //     }
    // }

    public IEnumerator DestroyObj() //超出一定时间后销毁
    {
        yield return new WaitForSeconds(5f);
        Destroy(gameObject);
    }
}

