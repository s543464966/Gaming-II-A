using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UIElements;

public class zzzCC_Monster : MonoBehaviour 
{
    private Rigidbody2D rb;
    private Animator animator;
    public float moveSpeed;
    [HideInInspector] public GameObject player; 
    public float knockbackForce;
    public int attackPower;
    private float dirLength;
    [HideInInspector]public float moveSpeedPlus; //移动速度效果加成

    private void Awake()
    {
        rb = GetComponent<Rigidbody2D>();
        // spriteRenderer = GetComponent<SpriteRenderer>();
        // detectionZone = GetComponent<DetectionZone>();
        //detectionZone = transform.Find("DetectionZone").GetComponent<DetectionZone>();
        animator = GetComponent<Animator>();
        player = GameObject.Find("Player");
        // moveSpeed = GetComponent<M_Damage_Monster>().SO_Monster.moveSpeed; //初始化移动速度
        if (moveSpeed < 0) {player = null;}
    }

    private void FixedUpdate() 
    {
        if(player != null)
        {
            // Vector2 dir = (player.transform.position - transform.position);//玩家的位置减去怪物本身的位置得到的距离向量
            Vector2 dir = new Vector3(transform.position.x,player.transform.position.y) - transform.position;//玩家的位置减去怪物本身的位置得到的距离向量
            dirLength = dir.magnitude;
            Vector3 x = new Vector3(-1,1,1);
            Vector3 bx = new Vector3(1,1,1);
            if( dirLength > 0)
            {
                // rb.AddForce(dir.normalized * moveSpeed);//normalized是正常化，不会根据距离的远近速度而有所变化
                // Debug.Log("移动速度" + moveSpeed);
                rb.velocity =  dir.normalized * 0.2f * moveSpeed *( 1 + moveSpeedPlus );
                if(dir.x >= 0)
                {
                    // spriteRenderer.flipX = false;
                    transform.localScale = x;
                }else
                {
                    // spriteRenderer.flipX = true;
                    transform.localScale = bx;
                }
                OnWalk();
            }
            else
            {
                OnWalkStop();
            }   
            // float distance = (transform.position - player.transform.position).magnitude;
            // if(distance <= 1.6f && time <= 0)
            // {
            //     time = atkSpeed;
            //     Debug.Log("怪物发动攻击"); 
            //     player.GetComponent<M_Damage_Player>().DamageAttackSum(atk);
            // }
            // else {time -= Time.deltaTime;}
        }
    }
    
    // IEnumerable Attack()
    // {
    //     GetComponent<M_Damage_Player>().DamageAttackSum(atk);
    //     yield return new WaitForSeconds(1f);
    // }
    // private void OnCollisionEnter2D(Collision2D _other) 
    // {
    //     if(_other.gameObject.tag == "Player")
    //     {
    //         Vector2 direction = _other.transform.position - transform.position;
    //         Vector2 force = direction.normalized * knockbackForce;
    //     }
    // }

// IEnumerator MakeDamage()
//     {
//         Collider2D[] _others = Physics2D.OverlapCircleAll(transform.position,atkArea,LayerMask.GetMask("Monster"));//寻找范围内的敌对层单位总数位置以碰撞器collider返回
//             foreach ( Collider2D _other in _others) 
//             { 
//                 _other.gameObject.GetComponent<M_Damage_Monster>().DamageAttackSum(damage);
//                 Debug.Log("岩石机器人造成伤害：" + damage);
//             }
//         yield return new WaitForSeconds(1f);
    // }


    //控制Walking的动画播放
    public void OnWalk(){
        animator.SetBool("isWalking",true);
    }

    public void OnWalkStop(){
        animator.SetBool("isWalking",false);
    }

    void OnDamage(){
        animator.SetTrigger("isDamage");
    }

    public void OnDie(){
        animator.SetTrigger("isDead");
        gameObject.layer = LayerMask.NameToLayer("TempStorages");
        moveSpeed = 0;
    }

    public void Animation_Destroy(){
        Destroy(gameObject);
    }
}
