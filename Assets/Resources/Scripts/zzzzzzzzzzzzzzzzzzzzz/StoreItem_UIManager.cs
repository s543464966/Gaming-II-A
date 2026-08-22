using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.UIElements;

public class StoreItem_UIManager : MonoBehaviour
{
    public RectTransform storePageOriginPosition;
    private Vector2 temp;
    public float movingLimit;
    // Start is called before the first frame update
    void Start()
    {
        Debug.Log("记录初始值");
        temp = storePageOriginPosition.anchoredPosition;//记录初始值
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    public void LimitPageMoving()
    {   
        
        Vector2 storePageCurrentPosition = gameObject.GetComponent<RectTransform>().anchoredPosition;//先获取当前的位置
        
        Debug.Log("获取当前位置");
        Debug.Log(storePageCurrentPosition);
        float newY = Mathf.Clamp(storePageCurrentPosition.y,temp.y , temp.y + movingLimit );//设置页面移动限制
        
        Vector2 newPosition = new Vector2(storePageOriginPosition.anchoredPosition.x, newY);//新的位置
        storePageOriginPosition.anchoredPosition = newPosition;//更新位置//不能修改RectTransfrom的y位置，只能用向量进行修改
        Debug.Log(storePageOriginPosition.anchoredPosition);
    }
}
