// using System.Collections.Generic;
// using UnityEngine;

// public class PlayerAutoAttack : MonoBehaviour
// {   
//     Vector3 position;
//     public int attackPower;
//     public int knockbackForce;
//     public Transform MonsterPos;//获取鼠标位置

//     public float attackRange;
//     public LayerMask monsterMask;

//     private List<GameObject> detect;
//     private float disCompare;
//     private int x;

//     // Start is called before the first frame update
//     void Start()
//     {
//         // position = transform.localPosition;
//         // monsterPos = MonsterPos.position;
//         disCompare = attackRange;
//         detect = new List<GameObject>();
//     }

//     // void IsFacingRight(bool IsFacingRight){//改变SwordTransform的方向
//     //     if(IsFacingRight){
//     //         transform.localPosition = position;
//     //     }else{
//     //         transform.localPosition = new Vector3(-position.x,position.y,position.z);
//     //     }
//     // }
//     // private void OnTriggerEnter2D(Collider2D collider) {//通过Sword的触发碰撞体来得到被打的对象
//     //     IDamageable damageable = collider.GetComponent<IDamageable>();

//     //     if(damageable != null)
//     //     {
//     //         Vector3 _position = transform.parent.position;
//     //         Vector2 direction = collider.transform.position - _position;

//     //         attackPower = 1;
//     //         damageable.OnHit(attackPower,direction.normalized * knockbackForce);
//     //     }
//     // }
    
//     void Update()
//     {
//         detect.Clear();
//         Collider2D[] objColiders = Physics2D.OverlapCircleAll(transform.position,attackRange,monsterMask); //寻找玩家的图层位置以碰撞器collider返回
//         if(objColiders != null){
//         foreach ( Collider2D objColider in objColiders){ //找到玩家的collider返回给变量
//             GameObject detectedObj = objColider.gameObject;
//             detect.Add(detectedObj);
//             }
        
//         x = detect.Count;

//         for (int i = 0; i < x; i++){
//             float dis = Vector2.Distance(detect[i].transform.position,transform.position);
//             if(disCompare > dis){
//                 disCompare = dis;
//                 GameObject AttackMonster = detect[i];
//             }
//             }
//         }
//     }
// }

