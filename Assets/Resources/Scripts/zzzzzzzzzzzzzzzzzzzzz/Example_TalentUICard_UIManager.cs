using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using TMPro;
using UnityEngine.UI;
using Unity.Mathematics;
//using UnityEngine.UI;

public class Example_TalentUICard_UIManager : MonoBehaviour
{
    //保存引用的Equip_DataManager
    public Example_Equip_DataManager example_Equip_DataManager;
    //保存从Talent_Loader传过来的对象 用于调UI
    private GameObject Talent_Loader;
    //public Image talentImage;
    public TMP_Text talentValue;//天赋数值

    public TMP_Text talentName;//天赋名字
    // Start is called before the first frame update
    public GameObject TipBox;//提示弹窗对象

    public float tipBoxDuration;//提示弹窗的持续时间

    public float tipBoxAppearTime;//弹窗出现时间
    public float tipBoxDisappearTime;//弹窗消失时间
    public float tipBoxWidth;//提示弹窗的宽度
    private bool isAppear = false;//是否在出现状态
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    public void OnStudyTalentButton()//学习该天赋后将外置的天赋UI设置为亮[现在先设置透明度表示一下]
    {
        //先拿到英雄的名字先
        string currentname = GameObject.FindWithTag("Player").name;//目前先是获取对象的名字，后期可以配合英雄的系统 因为已经找到了该对象，获取上面挂载有英雄系统的脚本即可获得英雄名称
        Example_SO_Talent currentTalent_SO = Talent_Loader.GetComponent<Example_Talent_Loader>().specificTalent_SO;

        //做判断，如果没学习就让该英雄学习，如果学习了就提示他学习过了后并没有任何反应
        if (Manager_Talent.IsOnlyTalentActivated(currentname, currentTalent_SO)) //-->这里可以是检测当前的英雄和其天赋仓库了
        {
            
            //ture的状态下是该天赋已经激活了那么进行弹窗提示已激活并结束
            //提示弹窗[用协程的方法]
            StartCoroutine(AppearTipBox());

        }
        else//相反false的状态下是该天赋没有激活，那么就进行激活
        {
            //调用天赋字典库将该目标加点天赋进行保存在该英雄目录下
            Manager_Talent.AddHeroTalent(currentname,currentTalent_SO);
            //调用数据层将该数据传输过去
            example_Equip_DataManager.AddTempData_Talent(currentTalent_SO);
            //演示是做透明度 实际可以用明暗//因为有_0/1 甚至SO上能挂载两个
            Color studiedColor = Talent_Loader.GetComponent<Image>().color;
            studiedColor.a = studiedColor.a * 2;
            Talent_Loader.GetComponent<Image>().color = studiedColor;
            //关闭TalentUICard窗口
            OnTalentUICardCloseButton();
        }

    }

    public void ReceiveTalentSOData(GameObject talentFrame)//接收天赋SO数据[对象]
    {
        
        //进行赋值[获取身上特定的天赋SO]
        // talentValue.text = example_SO_Talent.atk.ToString();
        // talentName.text = example_SO_Talent.talentName;
        talentValue.text = talentFrame.GetComponent<Example_Talent_Loader>().specificTalent_SO.atk.ToString();
        talentName.text = talentFrame.GetComponent<Example_Talent_Loader>().specificTalent_SO.talentName;

        //保存对象
        Talent_Loader = talentFrame;
    }

    public void OnTalentUICardCloseButton()
    {
        gameObject.SetActive(false);
    }

    private IEnumerator AppearTipBox()
    {
        //设置局部弹窗目标Y值
        float TipBoxFinalY = 600f;
        //弹窗出现阶段
        isAppear = true;//修改阶段
        //设置弹窗位置在[TalentUICard]的中心
        RectTransform tipBoxRect = TipBox.GetComponent<RectTransform>();//得到弹窗对象的Rect组件
        tipBoxRect.anchoredPosition = GameObject.Find("Btn_GetTalent").GetComponent<RectTransform>().anchoredPosition;

        //设置弹窗的宽度为0
        //TipBox.GetComponent<RectTransform>().sizeDelta = new Vector2(0f,TipBox.GetComponent<RectTransform>().sizeDelta.y);
        tipBoxRect.sizeDelta = new Vector2(0f, tipBoxRect.sizeDelta.y);

        //设置弹窗的透明度为0
        //TipBox.GetComponent<CanvasGroup>().alpha = 0f;
        CanvasGroup tipBoxCanvasGroup = TipBox.GetComponent<CanvasGroup>();//得到弹窗对象的CanvasGroup组件
        tipBoxCanvasGroup.alpha = 0f;

        float pastTime = 0f; // 已过时间
        //设置弹窗的显示状态
        TipBox.SetActive(isAppear);
        //实现弹窗出现的效果
        //while(TipBox.GetComponent<CanvasGroup>().alpha < 1f || Mathf.Abs(TipBox.GetComponent<RectTransform>().sizeDelta.x - TipBoxWidth) > 0.01)
        while(pastTime < tipBoxAppearTime)
        {
            float currentAlpha = Mathf.Lerp(0f ,1f , pastTime/tipBoxAppearTime);//计算出现时的时刻透明度[按时间的比例进行插值]
            tipBoxCanvasGroup.alpha = currentAlpha;//将计算此时的透明度赋值

            float currentWidth = Mathf.Lerp(0f,tipBoxWidth,pastTime/tipBoxAppearTime);//计算出现时的时刻宽度
            float currentY = Mathf.Lerp(0f ,TipBoxFinalY , pastTime/tipBoxAppearTime);//计算出现时的时刻Y轴位置
            tipBoxRect.sizeDelta = new Vector2(currentWidth,TipBox.GetComponent<RectTransform>().sizeDelta.y);
            tipBoxRect.anchoredPosition = new Vector2(0f,currentY);

            //更新已过时间
            pastTime += Time.deltaTime;
            yield return null;//等待一帧
        }
        //确认最终值
        tipBoxCanvasGroup.alpha = 1f;
        tipBoxRect.sizeDelta = new Vector2(tipBoxWidth,tipBoxRect.sizeDelta.y);
        tipBoxRect.anchoredPosition = new Vector2(0f,TipBoxFinalY);

        yield return new WaitForSeconds(tipBoxDuration);//弹窗持续时间
        //进入弹窗淡出消失的协程
        StartCoroutine(DisappearTipBox());
    }

    private IEnumerator DisappearTipBox()//弹窗持续时间结束后进入淡出消失阶段
    {
        //获取弹窗的CanvasGroup组件控制透明度
        CanvasGroup tipBoxCanvasGroup = TipBox.GetComponent<CanvasGroup>();
        //获取弹窗的Rect组件控制宽度
        RectTransform tipBoxRect = TipBox.GetComponent<RectTransform>();

        float pastTime = 0f;
        while(pastTime < tipBoxDisappearTime)
        {
            //计算消失时的时刻透明度
            float currentAlpha = Mathf.Lerp(1f , 0f , pastTime/ tipBoxDisappearTime);
            tipBoxCanvasGroup.alpha = currentAlpha;

            //计算消失时的时刻宽度
            float currentWidth = Mathf.Lerp(tipBoxWidth,0f , pastTime/ tipBoxDisappearTime);
            tipBoxRect.sizeDelta = new Vector2(currentWidth,tipBoxRect.sizeDelta.y);

            //更新过去时间
            pastTime += Time.deltaTime;
            //等待一帧
            yield return null;
        }
        //确认最终值
        tipBoxCanvasGroup.alpha = 0f;
        tipBoxRect.sizeDelta = new Vector2(0f, tipBoxRect.sizeDelta.y);

        //最终隐藏窗口
        TipBox.SetActive(false);
    }
}
