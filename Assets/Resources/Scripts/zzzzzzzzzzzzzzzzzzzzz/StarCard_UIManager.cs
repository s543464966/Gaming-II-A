using System.Collections;
using TMPro;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;
using DG.Tweening;

public class StarCard_UIManager : MonoBehaviour//,IDragHandler,IPointerUpHandler
{
    //引用
    RectTransform selfTransfrom;//自身位置
    public Vector2 originalPos;//最终起始位置[在手牌里的]
    
    public float targetScale;//放大倍数
    private RectTransform handCards_Zone;//手牌区域
    private GameObject arrow_Obj;//箭头UI
    private GameObject straightLine_Obj;//直线提示线UI
    //每个卡牌自身的角度限制
    public Vector2 initPos;//初始位置[给角度限制]
    public float targetAngle;//目标移动角度
    public float minLimitAngle;//最小角度限制
    public float maxLimitAngle;//最大角度限制
    private bool isDragging = false;//是否此时是拖拽状态
    //--------保存要调用的脚本------------------
    private StarCardWheel_UIManager starCardWheel_UIManager;//引用轮盘的脚本
    //private Fighting_StarmanaSelect fighting_StarmanaSelect;//引用星能之力产生脚本
    //--------保存其属性----------------------
    // private SO_Skill starmana_SO;//保存引用
    private int CurrentStarmana;//当前星能之力
    private Vector2 currentStarCard_Pos;//当前位置
    private float currentStarCard_Angle;//当前角度
    //--------更新属性UI----------------------
    public TMP_Text starCardName;//子对象卡牌的名字name
    public TMP_Text starCardInfo;//子对象卡牌的介绍info
    public Image starCardSprite;//子对象卡牌的图片sprite
    public TMP_Text starCardUse;//子对象卡牌的星能消耗use
    //--------动画API----------
    private Tween currentTween;//当前正在执行的动画
    public float moveDuration;//移动时间
    float fadeDuration = 0.9f;
    float scaleDuration = 0.9f;
    private void Start() {
        arrow_Obj = FindAnyObjectByType<Arrow_UIManager>().gameObject;
        straightLine_Obj = FindAnyObjectByType<StraightLine_UIManager>().gameObject;
        minLimitAngle = 0;
        maxLimitAngle = 0;
        selfTransfrom = gameObject.GetComponent<RectTransform>();
        starCardWheel_UIManager = FindAnyObjectByType<StarCardWheel_UIManager>();//找到轮盘脚本
        //handCards_Zone = GameObject.Find("HandCards_Zone").GetComponent<RectTransform>();//实例化的卡牌不能这样找[都要改]
        handCards_Zone = GameObject.FindAnyObjectByType<StarCardWheel_UIManager>().GetComponent<RectTransform>();//找到当前场景下挂载该脚本的第一个对象
        //订阅点击 拖动事件
        // SD_ClickEvent.OnCurrentSceneClickEvent += HandPointerDown;
        // SD_ClickEvent.OnCurrentSceneDrag +=HandPointerDrag;
        // SD_ClickEvent.OnCurrentSceneClickUpEvent +=HandPointerUp;
    }

    private void Update() 
    {
        
    }

    //接收SO然后更新自身UI
    // public void ReceiveStarmana_SO(SO_Skill target_SO_Skill)
    // {
    //     //保存星能之力SO实例
    //     starmana_SO = target_SO_Skill;
    //     //更新UI数据
    //     // gameObject.GetComponent<Image>().sprite = target_SO_Skill.starmanaSpriteBG;
    //     // starCardName.text = target_SO_Skill.starmanName;
    //     // starCardInfo.text = target_SO_Skill.info;
    //     // starCardUse.text = target_SO_Skill.skillUse.ToString();
    //     // starCardSprite.sprite = target_SO_Skill.starmanaSprite;
    // }
    //点击后协程进行平滑放大
    IEnumerator MoveToUseStarCard(RectTransform targetRect,System.Action isComplete)
    {
        Vector2 startPos = targetRect.localPosition;//拿到起始移动位置
        float startRot_Z = targetRect.localEulerAngles.z;//本地旋转角度
        float elapsedTime = 0;
        while(elapsedTime < moveDuration)
        {
            elapsedTime += Time.deltaTime;
            float t = elapsedTime / moveDuration;
            //进行平滑移动
            float current_X = Mathf.Lerp(startPos.x,Vector2.zero.x,t);
            float current_Y = Mathf.Lerp(startPos.y,Vector2.zero.y,t);
            float current_Rotate_Z = Mathf.Lerp(startRot_Z,0,t);
            //将计算的值赋值给该对象
            targetRect.localPosition = new Vector2(current_X,current_Y);
            targetRect.localEulerAngles = new Vector3(0,0,current_Rotate_Z);//保证使用卡牌后是与屏幕同框的
            //进行平滑放大
            selfTransfrom.localScale = Vector2.Lerp(targetRect.localScale,new Vector2(targetScale,targetScale),t);
            yield return null;
        }
        //协程结束最后体现卡牌的效果,最终要破坏掉
        // 协程结束时调用回调函数
        if (isComplete != null)
        {
            isComplete();
        }
        
    }
    void MoveToUseStarCard()
    {
        // 移动到目标位置
        selfTransfrom.DOMove(arrow_Obj.transform.position, moveDuration)
            .SetEase(Ease.InQuad)  // 使用非线性缓动
            .OnComplete(()=>
            {
                //StarCardToEffect();//完成后执行卡牌实际效果
                //测试
                Debug.Log("执行产生卡牌效果");
                //通知轮盘脚本对剩下卡牌进行排序和位置整理
                starCardWheel_UIManager.UsedStarCardToSort(gameObject);
                //清理前需要将该实例取消订阅
                // SD_ClickEvent.OnCurrentSceneClickEvent -= HandPointerDown;
                // SD_ClickEvent.OnCurrentSceneDrag -= HandPointerDrag;
                // SD_ClickEvent.OnCurrentSceneClickUpEvent -= HandPointerUp;
                //产生效果后清除该卡牌
                Destroy(gameObject);
            });
        // 透明度渐变到 0
        selfTransfrom.GetComponent<CanvasGroup>().DOFade(0f, fadeDuration)
            .SetEase(Ease.InQuad);  // 非线性透明度变化
        // 缩放到 0
        selfTransfrom.DOScale(Vector3.zero, scaleDuration)
            .SetEase(Ease.InQuad);  // 非线性缩放变化
    }
    void RecoverOriginalPos(Vector2 originalPos)//回到最初位置的方法
    {
        // float elapsedTime = 0;
        // while(elapsedTime< moveDuration)
        // {
        //     elapsedTime += Time.deltaTime;
        //     float t = elapsedTime / moveDuration;
        //     //进行平滑移动
        //     selfTransfrom.localPosition = Vector2.Lerp(currentPos,originalPos,t);
        // }
        // //确保最终位置
        // selfTransfrom.localPosition = originalPos;
        selfTransfrom.DOAnchorPos(originalPos,moveDuration).SetEase(Ease.InOutQuad);
    }

    void StarCardToEffect()//调用使用星能之力接口传入使用的星能之力
    {
        Debug.Log("调用删除");
        //需要产生的效果//[调用接口然后将自身保存的SO传入]
        //fighting_StarmanaSelect.StarmanaPick(starmana_SO);
        //通知轮盘脚本对剩下卡牌进行排序和位置整理
        starCardWheel_UIManager.UsedStarCardToSort(gameObject);
        //清理前需要将该实例取消订阅
        // SD_ClickEvent.OnCurrentSceneClickEvent -= HandPointerDown;
        // SD_ClickEvent.OnCurrentSceneDrag -=HandPointerDrag;
        // SD_ClickEvent.OnCurrentSceneClickUpEvent -=HandPointerUp;
        //产生效果后清除该卡牌
        Destroy(gameObject);
    }

    public void HandPointerDown(PointerEventData currentPointerData)//该对象按下事件的实现
    {
        //arrow_Obj.SetActive(true);
        if(isDragging)
        {
            //先检测鼠标数据是否在自己的范围内
            if (RectTransformUtility.RectangleContainsScreenPoint(selfTransfrom, currentPointerData.position, currentPointerData.enterEventCamera))
            {
                if (currentTween != null && currentTween.IsActive())
                {
                    currentTween.Kill();//如果当前的执行动画不为空并为积极的就杀死[打断动画]
                }
                currentTween = gameObject.transform.DOScale(new Vector3(1.2f, 1.2f), 0.8f).SetEase(Ease.OutBack);//调用API实现特殊回弹动画[缩放比例，持续时间，非线性]
                straightLine_Obj.GetComponent<StraightLine_UIManager>().StartFading();//调用提示线的闪烁
                //starCardWheel_UIManager.OppositeIsDrag(false);
            }
        }
    }

    public void HandPointerDrag(PointerEventData eventData)//卡牌自身的拖动
    {
        if(isDragging)
        {
            if (RectTransformUtility.RectangleContainsScreenPoint(selfTransfrom, eventData.position, eventData.enterEventCamera))
            {
                starCardWheel_UIManager.OppositeIsDrag(false);
                //Debug.Log("在滑动进来了");
                //拖拽卡牌物体移动
                Vector2 localPoint;
                RectTransformUtility.ScreenPointToLocalPointInRectangle(selfTransfrom, eventData.position, eventData.pressEventCamera, out localPoint);
                //Debug.Log(localPoint);
                selfTransfrom.rotation = Quaternion.Euler(0, 0, 0);//恢复垂直状态
                selfTransfrom.localPosition = (Vector3)localPoint + selfTransfrom.localPosition;//更新自身位置
                RectTransform temp_rectTransform = gameObject.GetComponent<RectTransform>();
                //调用箭头UI脚本
                //arrow_Obj.GetComponent<Arrow_UIManager>().FollowFinger(temp_rectTransform.position);
                straightLine_Obj.GetComponent<StraightLine_UIManager>().FollowFinger_X(temp_rectTransform.position);
            }
        }
    }

    public void HandPointerUp(PointerEventData eventData)
    {
        // 如果有正在进行的动画，终止它并执行缩小
        if (currentTween != null && currentTween.IsActive())
        {
            currentTween.Kill();  // 停止当前动画
        }
        currentTween = gameObject.transform.DOScale(Vector2.one,0.5f).SetEase(Ease.InOutQuad);//执行释放非线性变小
        straightLine_Obj.GetComponent<StraightLine_UIManager>().StopFading();//直线结束渐变
        //arrow_Obj.SetActive(false);
        //获取更新当前星能之力值
        //CurrentStarmana = fighting_StarmanaSelect.ReadStarmanaValue();//记得解注释
        //如果大于顶部的话且够使用的星能之力
        if (selfTransfrom.localPosition.y > handCards_Zone.localPosition.y + handCards_Zone.rect.height / 2 && CurrentStarmana >= 3)
        {
            //打断不能拖动并且自动放大
            isDragging = false;
            //SaveStarCardData();//保存数据
            //执行使用移动方法
            MoveToUseStarCard();
            //启动协程平滑
            //StartCoroutine(MoveToUseStarCard(selfTransfrom, StarCardToEffect));
        }
        //检测卡牌当前的Y值是否超过区域的顶部或当前星能之力不够该卡使用不能用
        if (selfTransfrom.localPosition.y < handCards_Zone.localPosition.y + handCards_Zone.rect.height / 2 || CurrentStarmana < 3)
        {

            Debug.Log("在里面");
            //如果没超过应该回到原来的位置
            RecoverOriginalPos(originalPos);
        }
        isDragging = false;
        starCardWheel_UIManager.OppositeIsDrag(true);
    }
    
    void SaveStarCardData()//记录当前卡牌的信息[传递给Starmana进行卡牌种类操作]
    {
        RectTransform temp_rectTransform = gameObject.GetComponent<RectTransform>();
        //第一种保存角度[与中心角度]
        currentStarCard_Angle = Mathf.Atan2(temp_rectTransform.localPosition.y-Vector2.zero.y,temp_rectTransform.localPosition.x-Vector2.zero.x);//需要修改
        if(currentStarCard_Angle<0)//保证是正的
        {
            currentStarCard_Angle = Mathf.Atan2(Vector2.zero.y-temp_rectTransform.localPosition.y,temp_rectTransform.localPosition.x-Vector2.zero.x);
        }
        //是否要转成角度制？
    
        //第二种保存位置
        currentStarCard_Pos = temp_rectTransform.localPosition;
    }
    // public void GetFighting_StarmanaSelect(Fighting_StarmanaSelect targetScript)//接收外部传递的星能之力产生脚本
    // {
    //     fighting_StarmanaSelect = targetScript;
    // }

    public void GetisDragging(bool targetDrag)//外部调用修改该卡片的拖拽状态
    {
        isDragging = targetDrag;
    }
}
