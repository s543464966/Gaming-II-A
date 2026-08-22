using System.Collections;
using System.Collections.Generic;
using Unity.Mathematics;
using UnityEngine;

public class Arrow_UIManager : MonoBehaviour
{
    // Start is called before the first frame update
    //引用星能卡牌预制体的Rect组件
    public RectTransform starCard_Prefab;
    //最初位置
    private Vector2 Init_Pos;
    //Rect组件
    private RectTransform selfRect;//箭头的Rect组件
    float r_lengest;//半径长度
    void Awake() {
        selfRect = gameObject.GetComponent<RectTransform>();
        Init_Pos = selfRect.position;
        //计算好星能卡牌的最长半径圆
        float w = Mathf.Pow(starCard_Prefab.rect.width/2.0f,2);
        float h = Mathf.Pow(starCard_Prefab.rect.height/2.0f,2);
        r_lengest = Mathf.Pow(w,0.5f);
        //计算
    }
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    public void FollowFinger(Vector2 fingerPos)
    {   //接收触控位置
        //计算距离向量
        Vector2 distance = fingerPos - Init_Pos;
        //将自身拉伸过去
        selfRect.sizeDelta = new Vector2(distance.magnitude-r_lengest,selfRect.sizeDelta.y);
        //调整自身的旋转角度
        //与手指触控的角度
        float currentAngle = Mathf.Atan2(distance.y,distance.x);
        Debug.Log(currentAngle * Mathf.Rad2Deg);
        //实时修改箭头的Z轴
        currentAngle = currentAngle * Mathf.Rad2Deg + 180;
        selfRect.rotation = Quaternion.Euler(0, 0, currentAngle);
    }
}
