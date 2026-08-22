using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class zzzFighting_Protection : MonoBehaviour   //刷怪
{
    private int hp = 10; //波数停止刷怪

    public void Protection_AddHP(int _hp) 
    {
        hp += _hp;
    }

    void OnTriggerEnter2D(Collider2D _other)  //持续刷新
    {
        if (_other.gameObject.layer == LayerMask.NameToLayer("Monster"))
        {
            Destroy(_other.gameObject);
            hp -= 1;
            Debug.Log("怪物进攻成功，护盾剩余：" + hp);
            if( hp <= 0)
            {
                Debug.Log("挑战失败，游戏结束");
                //【对接】关卡挑战失败！
            }
        }
    } 
}
