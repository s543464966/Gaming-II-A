using System.Collections;
using System.Collections.Generic;
using DG.Tweening;
using UnityEngine;
using UnityEngine.UI;

public class FightCardTimeline_UIManager : MonoBehaviour
{   //挂载tl卡上
    //基础信息
    [HideInInspector]public GameObject LinkedCard;//所关联的卡牌
    public Vector2 originPos;//起始位置
    //======基础UI属性======//
    public Image tlCard_Main;
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        
    }
    //======回到初始位置======//
    public void ReturnToOrigin()
    {
        transform.position = originPos;
    }
    //======响应安全销毁接口======//
    // public void TLCardSafeDestroy(Init_FightingCard init_FightingCard)
    // {
    //     List<GameObject> tlAllCard = init_FightingCard.tlAllCard;
    //     for (int i = 0; i < tlAllCard.Count; i++)
    //     {
    //         if (tlAllCard[i] == gameObject)
    //         {
    //             for (int j = i; j < tlAllCard.Count - 1; j++)
    //             {
    //                 tlAllCard[j] = tlAllCard[j + 1];
    //             }
    //             tlAllCard.Remove(tlAllCard[tlAllCard.Count - 1]);
    //             Destroy(gameObject);
    //         }
    //     }
    // }
}
