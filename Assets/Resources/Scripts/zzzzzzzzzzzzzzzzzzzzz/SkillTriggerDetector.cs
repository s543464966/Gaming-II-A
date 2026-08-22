using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SkillTriggerDetector : MonoBehaviour
{
    // Start is called before the first frame update
    //手动引用
    public Manager_FightCardTimeline manager_FightCardTimeline;
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {

    }
    //======执行中断调用卡牌======//
    private void OnTriggerEnter2D(Collider2D other)//[timeline卡碰撞]
    {
        Debug.Log("碰撞检测");
        // 将碰撞的卡牌加入队列
        //Manager_ActionQueue.Instance.EnqueueAction(other.gameObject);
    }
}
