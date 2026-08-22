using System.Collections;
using System.Collections.Generic;
using DG.Tweening;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

public class StarCardWheel_UIManager : MonoBehaviour, IPointerDownHandler, IPointerUpHandler, IDragHandler
{
    //基础属性
    private GraphicRaycaster graphicRaycaster;//UI射线检测
    private List<RaycastResult> raycastResults;//点击位置射线投射存放找到的UI对象列表
    private GameObject clickUI_StarCard;//临时存放选中卡牌
    private int index;//重新排序索引值
    //public GameObject handCards_Zone;//手牌操作区域
    private Vector2 circle_Center;//圆心
    public float circle_Center_RelaitiveDown;//相距底部长度[可调]
    private float radius;//圆盘的半径//可算
    public float spacing_Angle;//间距角度[私有]
    public float duration_Time;//持续时间
    private float screen_Width;//屏幕宽度
    //上一次位置的temp值
    private List<GameObject> current_StarCards;//玩家此时持有的星能之力卡牌列表
    //实现滑动的变量------------
    private int originalSiblingIndex;//选中卡牌最初的UI显示层级
    private float maxLimitAngle;//限制对象的最大限制角度
    private float minLimitAngle;//限制对象的最小限制角度
    private float starCardAngleRange;//星能之力卡牌移动范围角度
    public GameObject minLimit;//最小限制对象
    public GameObject maxLimit;//最大限制对象
    public float baseSpeed = 0.1f;// 基础旋转速度
    public float damping = 0.95f;// 阻尼系数，决定减速的快慢
    public float maxSpeed_Direct = 5.0f;// 最大速度限制
    private bool isDragging = true;// 是否正在拖动
    private Vector2 startTouchPosition; // 起始触控位置
    private Vector2 drag_StartTouchPosition;//滑动时的上一帧位置

    //进行移动方向的布尔值------------------
    private bool isUp = false;
    private bool isLeftORRight = false;
    //private bool isDown = false;
    private bool selectMode = true;
    void Awake() 
    {
        StarCardWheel_Init();
    }
    //初始化
    void StarCardWheel_Init()
    {
        //找到父对象canvas
        graphicRaycaster = gameObject.GetComponentInParent<GraphicRaycaster>();
        raycastResults = new List<RaycastResult>();//初始化列表
        //将列表初始化new
        current_StarCards = new List<GameObject>();
        //拿到屏幕高度的一半
        float screen_Height_Half = gameObject.GetComponentInParent<Canvas>().GetComponent<RectTransform>().rect.height / 2;
        Debug.Log(screen_Height_Half);
        screen_Width = gameObject.GetComponentInParent<Canvas>().GetComponent<RectTransform>().rect.width;
        //拿到区域对象的坐标
        //RectTransform childZone_RectTransfrom = GameObject.Find("HandCards_Zone").GetComponent<RectTransform>();
        RectTransform childZone_RectTransfrom = gameObject.GetComponent<RectTransform>();
        //设置圆心[虚拟的]//相对底部的R[可调]
        //circle_Center = new Vector2(0f,-(circle_Center_RelaitiveDown+screen_Height_Half));//利用使用区域的中心和相对R得到可变化的半径

        circle_Center = new Vector2(0f, -circle_Center_RelaitiveDown);//相对于轮盘的半径
        GameObject testObject = new GameObject("TestGame");//可视化检测
        testObject.transform.parent = gameObject.transform;
        testObject.transform.localPosition = circle_Center;
        //计算半径
        //radius = childZone_RectTransfrom.localPosition.y - circle_Center.y ; //+ handCards_Zone.GetComponent<RectTransform>().rect.height *0.1f;

        radius = Mathf.Abs(circle_Center.y);//对圆心的Y取绝对值
        Debug.Log(childZone_RectTransfrom.localPosition.y);
        Debug.Log(circle_Center);
        Debug.Log(radius);
        //限制角度初始化
        maxLimitAngle = Mathf.Atan2(maxLimit.GetComponent<RectTransform>().localPosition.y - circle_Center.y, maxLimit.GetComponent<RectTransform>().localPosition.x - circle_Center.x);
        minLimitAngle = Mathf.Atan2(minLimit.GetComponent<RectTransform>().localPosition.y - circle_Center.y, minLimit.GetComponent<RectTransform>().localPosition.x - circle_Center.x);
        maxLimitAngle = maxLimitAngle * Mathf.Rad2Deg;//转成角度制
        minLimitAngle = minLimitAngle * Mathf.Rad2Deg;
        starCardAngleRange = maxLimitAngle - minLimitAngle;//计算总的角度范围
    }

    //添加进持有卡组的卡牌更新方法
    public void AddToHandCards(GameObject added_StarCard)//需要一个实例化对象
    {
        //将选择的卡放入持有的卡牌列表里
        current_StarCards.Add(added_StarCard);//加一张牌就将允许滑动角度调整
        //调用计算整卡移动数据方法
        EqualStarCards_Angle();
        Debug.Log("完成平均分配");
        //进行整体移动[区分前面和最后新增的一张][新增的走直线协程，前面的卡走圆弧协程]
        for(int starCard_Number = 0 ; starCard_Number<current_StarCards.Count;starCard_Number++)
        {
            if(current_StarCards.Count - starCard_Number == 1)//最后一张[即新增的一张]
            {
                //进行直线移动
                //StartCoroutine(Add_StarCard_Movement(current_StarCards[starCard_Number],duration_Time));
                Add_Movement(current_StarCards[starCard_Number],duration_Time);
            }
            else if(current_StarCards.Count - starCard_Number > 1)
            {
                //进行圆弧移动
                StartCoroutine(ElseCardsMoveToTargetPos(current_StarCards[starCard_Number],duration_Time));
            }
        }
    }
    void EqualStarCards_Angle()//将所有的卡牌[处理后的]的位置移动数据计算好
    {
        float temp_Count = current_StarCards.Count;//访问当前星能之力卡组数量
        float temp_spacingAngle = starCardAngleRange / (temp_Count +1) ;//计算平均间隔角度
        Debug.Log(starCardAngleRange);
        Debug.Log(temp_spacingAngle);
        for(int starCard_Number = 0;starCard_Number < current_StarCards.Count;starCard_Number++)
        {
            //对每张卡进行移动到平均分的位置
            float targetAngle = maxLimitAngle - (starCard_Number+1) * temp_spacingAngle;//计算当前的卡要移动的位置
            Debug.Log(targetAngle);
            //告知每张卡要移动到的角度
            current_StarCards[starCard_Number].GetComponent<StarCard_UIManager>().targetAngle = targetAngle;
            //确定每张卡的最终位置
            targetAngle *=Mathf.Deg2Rad;//转成弧度制
            Vector2 final_Pos = new Vector2(Mathf.Cos(targetAngle)*radius + circle_Center.x, Mathf.Sin(targetAngle)* radius + circle_Center.y);
            current_StarCards[starCard_Number].GetComponent<StarCard_UIManager>().originalPos = final_Pos;
            Debug.Log(final_Pos);
        }
    }

    //实现添加卡牌移动的协程方法//[这个是直线的添加的模式]
    IEnumerator Add_StarCard_Movement(GameObject movementObject,float duration)//,float targetAngle)
    {
        float elapsedTime = 0;
        //先获取对象上的位置组件
        RectTransform movementObject_RectTransfrom = movementObject.GetComponent<RectTransform>();
        //获取当前对象的位置
        Vector2 startPoint = movementObject_RectTransfrom.localPosition;
        //拿到对象上的目标位置
        Vector2 targetPosition = movementObject.GetComponent<StarCard_UIManager>().originalPos;
        //拿到对象目标角度
        float targetAngle = movementObject.GetComponent<StarCard_UIManager>().targetAngle;
        //进行循环帧移动
        while (elapsedTime < duration)
        {
            elapsedTime += Time.deltaTime;
            float t = elapsedTime / duration;//计算比例
            //计算x的位置比例
            float current_X = Mathf.Lerp(startPoint.x,targetPosition.x,t);
            //计算y的位置比例
            float current_Y = Mathf.Lerp(startPoint.y,targetPosition.y,t);
            //调用旋转卡牌对准圆心方法
            StarCardsMoveRotate(targetAngle,movementObject);
            //更新卡牌当前位置
            movementObject_RectTransfrom.localPosition = new Vector2(current_X, current_Y);
            yield return null;
        }
    }
    private void Add_Movement(GameObject moveObj,float duration)
    {
        //先获取对象上的位置组件
        RectTransform moveObj_RectTransfrom = moveObj.GetComponent<RectTransform>();
        //拿到对象上的目标位置
        Vector2 targetPosition = moveObj.GetComponent<StarCard_UIManager>().originalPos;
        //拿到对象目标角度
        float targetAngle = moveObj.GetComponent<StarCard_UIManager>().targetAngle;
        //调用旋转卡牌对准圆心方法
        StarCardsMoveRotate(targetAngle,moveObj);
        //执行非线性直线移动
        moveObj_RectTransfrom.DOAnchorPos(targetPosition,duration).SetEase(Ease.OutSine);//调用局部坐标，默认是世界坐标
        Debug.Log(targetPosition);
    }

    //添加卡牌时其他卡牌移动的协程方法[弧度制]
    IEnumerator ElseCardsMoveToTargetPos(GameObject targetGameObject,float duration)//,float startAngle,float targetAngle)//需要对象和目标角度
    {
        float elapsedTime = 0;
        //拿到对象的位置组件
        RectTransform targetRectTransfrom = targetGameObject.GetComponent<RectTransform>();
        Vector2 start_Pos = targetRectTransfrom.localPosition;
        //计算当前位置的角度
        float startAngle = Mathf.Atan2(start_Pos.y-circle_Center.y,start_Pos.x-circle_Center.x); 
        //获取对象的目标移动角度
        float targetAngle = targetGameObject.GetComponent<StarCard_UIManager>().targetAngle;
        targetAngle *=Mathf.Deg2Rad;//转成弧度制
        //进行循环帧移动
        while (elapsedTime < duration)//[这个是圆弧移动的模式]
        {
            elapsedTime += Time.deltaTime;
            float t = elapsedTime / duration;//计算比例
            //计算角度的比例
            float currentAngle = Mathf.Lerp(startAngle,targetAngle,t);
            //计算当前角度下的位置
            float current_X = Mathf.Cos(currentAngle) * radius + circle_Center.x;
            float current_Y = Mathf.Sin(currentAngle) * radius + circle_Center.y;
            //更新卡牌当前位置
            targetRectTransfrom.localPosition = new Vector2(current_X, current_Y);
            //将此时移动角度变为角度制
            currentAngle *= Mathf.Rad2Deg;
            StarCardsMoveRotate(currentAngle,targetGameObject);//调用卡牌旋转方法
            yield return null;
        }
        // //拿到目标对象的方位组件
        // RectTransform targetRectTransfrom = targetGameObject.GetComponent<RectTransform>();
        // while (elapsedTime < duration)//[这个是圆弧移动的模式]
        // {
        //     elapsedTime += Time.deltaTime;
        //     float t = elapsedTime / duration;//计算比例
        //     //计算角度的比例
        //     float currentAngle = Mathf.Lerp(startAngle,targetAngle,t);

        //     //计算当前角度下的位置
        //     float current_X = Mathf.Cos(currentAngle) * radius + circle_Center.x;
        //     float current_Y = Mathf.Sin(currentAngle) * radius + circle_Center.y;
        //     //更新卡牌当前位置
        //     targetRectTransfrom.localPosition = new Vector2(current_X, current_Y);
        //     yield return null;
        // }
        // //更新最终位置
        // float finalAngle = targetAngle;//将目标角度转成弧度制
        // //配合三角函数进行确认
        // targetRectTransfrom.localPosition = new Vector2(Mathf.Cos(finalAngle)*radius+ circle_Center.x,Mathf.Sin(finalAngle) * radius+ circle_Center.y);
        // //记录最终的起始位置
        // targetGameObject.GetComponent<StarCard_UIManager>().originalPos = targetRectTransfrom.localPosition;
    }
    //使用卡牌后进行位置整理
    public void UsedStarCardToSort(GameObject usedStarCard)//对持有卡牌的列表进行重新排序
    {
        //重新排序[寻找需要逻辑删除对象]
        for(int i = 0; i<current_StarCards.Count;i++)
        {
            if(current_StarCards[i]==usedStarCard)
            {
                index = i;//找到对应列表位置[还没排序前的位置]
            }
        }
        //将逻辑对象后面的对象进行重新排序
        for(int j =index;j<current_StarCards.Count-1;j++)
        {
            current_StarCards[j] = current_StarCards[j+1];
        }
        if(current_StarCards[current_StarCards.Count-1] != null){
            current_StarCards.Remove(current_StarCards[current_StarCards.Count-1]);
        }
        //-------------最新的卡组数量处理完毕------------
        //调用均分角度方法
        EqualStarCards_Angle();
        //进行协程移动到对应角度[圆弧移动]
        for(int starCard_Number =0;starCard_Number < current_StarCards.Count;starCard_Number++)
        {
            StartCoroutine(ElseCardsMoveToTargetPos(current_StarCards[starCard_Number],duration_Time));
        }
    }
    //检测触碰输入事件形成UI移动-----------------------
    public void OnPointerDown(PointerEventData eventData)//点击按下事件
    {
        //点击后根据点击位置数据信息找到位置下所有层级的UI对象
        graphicRaycaster.Raycast(eventData,raycastResults);
        if(raycastResults.Count != 0)
        {
            //获取StarCard的UI对象
            for (int i = 0; i < raycastResults.Count; i++)
            {
                if(raycastResults[i].gameObject.GetComponent<StarCard_UIManager>() != null)
                {
                    clickUI_StarCard = raycastResults[i].gameObject;//找到第一个卡牌
                    break;
                }
            }
            if(clickUI_StarCard !=null)//避免为空
            {
                Debug.Log(clickUI_StarCard.name);
                //检测该对象是否含有StarCardUIManager脚本
                if (clickUI_StarCard.GetComponent<StarCard_UIManager>() != null)
                {
                    //修改该卡牌实例上的可拖动属性
                    clickUI_StarCard.GetComponent<StarCard_UIManager>().GetisDragging(true);
                    RectTransform clickUI_StarCard_Rect = clickUI_StarCard.GetComponent<RectTransform>();
                    //记录点击卡牌最初的显示层级
                    originalSiblingIndex = clickUI_StarCard_Rect.GetSiblingIndex();
                    //设置点击卡牌显示层级提高[Top？]
                    clickUI_StarCard_Rect.SetSiblingIndex(originalSiblingIndex + current_StarCards.Count);
                    // SD_ClickEvent.TriggerClickEvent(eventData);//给订阅了点击事件发送
                }
            }
        }
        raycastResults.Clear();//清空存储列表
        //记录起始坐标
        startTouchPosition = eventData.position;
        drag_StartTouchPosition = startTouchPosition;
    }
    public void OnDrag(PointerEventData eventData)//按住事件
    {
        // SD_ClickEvent.TriggerDragEvent(eventData);
        // //拖动并且在卡牌操控区里滑动才有效果
        // if (isDragging && RectTransformUtility.RectangleContainsScreenPoint(handCards_Zone.GetComponent<RectTransform>(), eventData.position, eventData.enterEventCamera))
        // {
        //     // 处理拖动事件//[计算旋转速度]
        //     Vector2 currentPosition = eventData.position;
        //     Vector2 touchDelta = currentPosition - startTouchPosition;
        //     startTouchPosition = currentPosition;
        //     float deltaX = touchDelta.x;//[获取水平方向向量]
        //     Debug.Log(deltaX);
            
        //     //根据拖动的水平距离更新速度
        //     currentSpeed = Mathf.Clamp(deltaX * baseSpeed * Time.deltaTime, -maxSpeed_Direct, maxSpeed_Direct);
        //     Debug.Log(currentSpeed);
        // }
        //根据逐帧刷新记录当前坐标进行计算
        //记录当前触控位置
        Vector2 currentPosition = eventData.position;
        //计算距离
        float distance = Vector2.Distance(startTouchPosition,currentPosition);
        //判断当前坐标与起始坐标距离是否超过防误触圈
        if(distance > screen_Width / 10 && selectMode)
        {
            //超过误触圈进行当前角度计算[准备进入分配]
            float currentAngle = Mathf.Atan2(currentPosition.y-startTouchPosition.y,currentPosition.x-startTouchPosition.x);//返回的是弧度制
            currentAngle = currentAngle * Mathf.Rad2Deg;//转成角度制
            //进行区域划分
            // if(currentAngle>-60&&currentAngle<60 || currentAngle>120 || currentAngle<-120)//向左右滑动的
            // {
            //     //Debug.Log("向左右滑动");
            //     //确保左右滑动的为ture
            //     isLeftORRight = true;
            //     isUp = false;
            // }else if(currentAngle>=30&&currentAngle<=150)//向上移动的
            // {
            //     //Debug.Log("向上滑动");
            // }
            //SD_ClickEvent.TriggerClickEvent(eventData);//保证只拖动一次卡
            isUp = true;
            isLeftORRight = false;
            //进入区域选择模式后跳出当前点击次选择模式操作
            selectMode = false;
        }
        //根据防误触检测后所选择的模式后进行所选模式的执行
        if(isUp)//向上滑动
        {
            //给订阅了的脚本发消息
            // SD_ClickEvent.TriggerDragEvent(eventData);
        }
        if(isLeftORRight)//左右滑动
        {
            // 处理拖动事件//[计算旋转速度]
            Vector2 drag_CurrentPosition = eventData.position;
            Vector2 touchDelta = drag_CurrentPosition - drag_StartTouchPosition;
            drag_StartTouchPosition = currentPosition;
            //Debug.Log(deltaX);
            //根据拖动的水平距离更新速度
            //currentSpeed = Mathf.Clamp(deltaX * baseSpeed * Time.deltaTime, -maxSpeed_Direct, maxSpeed_Direct);
            //Debug.Log(currentSpeed);
        }
    }
    public void OnPointerUp(PointerEventData eventData)//松开释放事件
    {
        Debug.Log("抬起了");
        // SD_ClickEvent.TriggerClickUpEvent(eventData);
        //恢复最初层级
        clickUI_StarCard.GetComponent<RectTransform>().SetSiblingIndex(originalSiblingIndex);
        //恢复卡牌自身旋转
        StarCardsMoveRotate(clickUI_StarCard.GetComponent<StarCard_UIManager>().targetAngle,clickUI_StarCard);
        //松开的时候将所有限制条件进行重置
        selectMode = true;
        isUp = false;
        isLeftORRight = false;
        //isDown = false;
    }
    //实现卡牌始终对着圆心
    void StarCardsMoveRotate(float currentAngle,GameObject targetObject)
    {
        RectTransform targetRectTransfrom = targetObject.GetComponent<RectTransform>();
        //与圆心0度情况
        if (currentAngle == 0)
        {
            targetRectTransfrom.rotation = Quaternion.Euler(0, 0, -90);
        }
        //与圆心[-180,0]
        if (currentAngle < 0)
        {
            float tempAngle = -90 + currentAngle;
            targetRectTransfrom.rotation = Quaternion.Euler(0, 0, tempAngle);
        }
        //与圆心[0,180]
        if (currentAngle > 0)
        {
            float tempAngle = currentAngle - 90;
            targetRectTransfrom.rotation = Quaternion.Euler(0, 0, tempAngle);
        }
    }
    public Vector2 Get_CircleCenter()//对外获得圆心的接口
    {
        return circle_Center;
    }
    public void OppositeIsDrag(bool state)//接收来自选择星能之力卡片的锁定
    {
        isDragging = state;
        isLeftORRight = state;
    }
}
