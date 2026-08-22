using System.Collections;
using System.Collections.Generic;
using DG.Tweening;
using UnityEngine;

public class C_FightDamageUI : MonoBehaviour
{
    private float floatLength;
    [Tooltip("浮动时间")] public float float_duration; //浮动时间

    // ----------------------------------------------------------------------------------------------------------

    //模块：Initial - 初始化
    void Start()
    {
        //高度Y轴
        floatLength = gameObject.GetComponent<RectTransform>().rect.height / 2;
        DamageFloat();
    }

    // Update is called once per frame
    void Update()
    {

    }
    //======伤害浮动效果======//
    private void DamageFloat()
    {
        //漂浮动画
        transform.DOMoveY(transform.position.y + floatLength, float_duration).SetEase(Ease.Linear)
        .OnComplete(() =>
        {
            Destroy(gameObject);
        });
    }
    //可以封装在这里显示
}
