using System.Collections.Generic;
using UnityEngine.UI;
using UnityEngine;
using TMPro;
using DG.Tweening;//动画API

public class SelectStarCards_UIManager : MonoBehaviour
{
    //保存星能之力卡片预制体
    public GameObject starCard_Prefab;
    //保存对圆盘脚本引用
    public StarCardWheel_UIManager starCardWheel_UIManager;
    //private Skill_Select fighting_StarmanaSelect;//保存对产生星能之力脚本的引用
    //保存传入星能之力SO组引用来传递给预制体挂载
    // private SO_Skill[] SO_Skills;
    //将子对象放入列表里
    List<Transform> Transforms;
    //子对象卡牌的名字name
    public TMP_Text[] starCardName;
    //子对象卡牌的介绍info
    public TMP_Text[] starCardInfo;
    //子对象卡牌的图片sprite
    public Image[] starCardSprite;
    //子对象卡牌的星能消耗use
    public TMP_Text[] starCardUse;
    //选择的判断
    public bool isSelected = false;
    private float test_time;
    private void Awake()
    {
        Transforms = new List<Transform>();//实例化
        // SO_Skills = new SO_Skill[3];//实例化3个大小的星能组
        foreach(Transform Transform in gameObject.transform)
        {
            Transforms.Add(Transform);
        }
        starCardWheel_UIManager = FindObjectOfType<StarCardWheel_UIManager>();//找到关卡场景下唯一的轮盘脚本对象
        //fighting_StarmanaSelect = FindObjectOfType<Skill_Select>();//在初始化的时候找到挂载该脚本下的唯一对象的脚本
    }
    // Update is called once per frame
    void Update()
    {
        //测试
        test_time += Time.deltaTime;
        if(test_time > 5)
        {
            Debug.Log(test_time);
            for (int starCard_Number = 0; starCard_Number < Transforms.Count; starCard_Number++)
            {
                Transforms[starCard_Number].gameObject.SetActive(true);
            }
            test_time = 0;
            Appear_StarCard();
        }
    }

    //接送随机星能之力方法--------------
    // public void ReceiveRandomData_StarCard(SO_Skill randomData)//刷怪掉落星能之力[接收掷骰子的方法]
    // {
    //     //拿到当前一个星能之力SO即可实例化出来
    //     //找到圆盘对象
    //     Transform circleCenter = GameObject.FindObjectOfType<StarCardWheel_UIManager>().transform;
    //     //new一个星能之力卡片预制体放在圆盘的子对象
    //     GameObject newStarCardUIPrefab = Instantiate(starCard_Prefab, circleCenter);//创建itemUICard预制体
    //     newStarCardUIPrefab.GetComponent<RectTransform>().localPosition = starCardWheel_UIManager.Get_CircleCenter();//初始化
    //     starCardWheel_UIManager.AddToHandCards(newStarCardUIPrefab);//通知圆盘来了新卡牌对象
    //     //将这上面的属性赋值过去
    //     // newStarCardUIPrefab.GetComponent<StarCard_UIManager>().ReceiveStarmana_SO(randomData);//传入单个
    //     //newStarCardUIPrefab.GetComponent<StarCard_UIManager>().GetFighting_StarmanaSelect(fighting_StarmanaSelect);//将挂载该脚本传入过去
    // }

    // public void ReceiveRandomData_StarCard_Group(SO_Skill[] randomDatas)//星能之力值够了一次产生3张卡牌选1张
    // {
    //     SO_Skills = randomDatas;//更新最新的星能之力
    //     //将组数据循环放入要选择的卡牌上
    //     for(int starCard_Number = 0;starCard_Number<randomDatas.Length;starCard_Number++)
    //     {
    //         //拿到数据放入对应卡牌中
    //         // Transforms[starCard_Number].GetComponent<Image>().sprite = randomDatas[starCard_Number].starmanaSpriteBG;//星能卡片背景
    //         // starCardName[starCard_Number].text = randomDatas[starCard_Number].starmanName;//名字需要字体支持中文
    //         // starCardInfo[starCard_Number].text = randomDatas[starCard_Number].info;//介绍
    //         // starCardUse[starCard_Number].text = randomDatas[starCard_Number].skillUse.ToString();//消耗[将int转成string]
    //         // starCardSprite[starCard_Number].sprite = randomDatas[starCard_Number].starmanaSprite;//星能卡片
    //         Transforms[starCard_Number].gameObject.SetActive(true);//激活卡片
    //     }
    //     //执行非线性显现卡牌选择
    //     Appear_StarCard();
    // }
    //------------------------------------------------
    public void Left_StarCard()//左边的星能之力卡片
    {
        if(isSelected == false)
        {
            //执行反馈动画方法
            Selected_ToJump(Transforms[0]);
            //找到圆盘对象
            Transform circleCenter = GameObject.FindObjectOfType<StarCardWheel_UIManager>().transform;
            //new一个星能之力卡片预制体放在圆盘的子对象
            GameObject newStarCardUIPrefab = Instantiate(starCard_Prefab, circleCenter);//创建itemUICard预制体
            newStarCardUIPrefab.GetComponent<RectTransform>().localPosition = starCardWheel_UIManager.Get_CircleCenter();//初始化
            //通知圆盘来了新卡牌对象
            starCardWheel_UIManager.AddToHandCards(newStarCardUIPrefab);
            //将这上面的属性赋值过去
            // newStarCardUIPrefab.GetComponent<StarCard_UIManager>().ReceiveStarmana_SO(SO_Skills[0]);//传第一个
            //newStarCardUIPrefab.GetComponent<StarCard_UIManager>().GetFighting_StarmanaSelect(fighting_StarmanaSelect);//将挂载该脚本传入过去
        }

    }
    public void Middle_StarCard()//中间的星能之力卡片
    {
        if(isSelected == false)
        {
            //找到圆盘对象
            Transform circleCenter = GameObject.FindObjectOfType<StarCardWheel_UIManager>().transform;
            //Debug.Log(circleCenter.position);
            //new一个星能之力卡片预制体放在圆盘的子对象
            GameObject newStarCardUIPrefab = Instantiate(starCard_Prefab, circleCenter);//创建itemUICard预制体
            newStarCardUIPrefab.GetComponent<RectTransform>().localPosition = starCardWheel_UIManager.Get_CircleCenter();//初始化
            //通知圆盘来了新卡牌对象
            starCardWheel_UIManager.AddToHandCards(newStarCardUIPrefab);
            //将这上面的属性赋值过去
            // newStarCardUIPrefab.GetComponent<StarCard_UIManager>().ReceiveStarmana_SO(SO_Skills[1]);//传第二个
            //newStarCardUIPrefab.GetComponent<StarCard_UIManager>().GetFighting_StarmanaSelect(fighting_StarmanaSelect);//将挂载该脚本传入过去
        }
        //执行消失方法
        Disappear_StarCard();
    }
    public void Right_StarCard()//右边的星能之力卡片
    {
        if(isSelected == false)
        {
            //找到圆盘对象
            Transform circleCenter = GameObject.FindObjectOfType<StarCardWheel_UIManager>().transform;
            //Debug.Log(circleCenter.position);
            //new一个星能之力卡片预制体放在圆盘的子对象
            GameObject newStarCardUIPrefab = Instantiate(starCard_Prefab, circleCenter);//创建itemUICard预制体
            newStarCardUIPrefab.GetComponent<RectTransform>().localPosition = starCardWheel_UIManager.Get_CircleCenter();//初始化
            //通知圆盘来了新卡牌对象
            starCardWheel_UIManager.AddToHandCards(newStarCardUIPrefab);
            //将这上面的属性赋值过去
            // newStarCardUIPrefab.GetComponent<StarCard_UIManager>().ReceiveStarmana_SO(SO_Skills[2]);//传第三个
            //newStarCardUIPrefab.GetComponent<StarCard_UIManager>().GetFighting_StarmanaSelect(fighting_StarmanaSelect);//将挂载该脚本传入过去
        }
        //执行消失方法
        Disappear_StarCard();
    }
    //------------------------------------------------
    //点击卡牌后弹跳一段给玩家反馈
    private void Selected_ToJump(Transform selected)
    {
        //点击后弹跳效果
        selected.DOJump(selected.position,40,1,0.5f).SetEase(Ease.OutQuad);//[对象位置，跳动高度，跳跃类型，持续时间，非线性]
        // .OnComplete(() =>
        // {
        //     Disappear_StarCard();
        // });
        Disappear_StarCard();
    }
    //将所有给选择的星能之力卡片消失//要区分只能点击一次
    private void Disappear_StarCard()
    {
        //设置选择逻辑
        isSelected = true;
        //将所有的星能之力卡片消失[先简单设置不激活，可以设置协程减少透明度最后不激活][要记得启动激活]
        for(int number = 0;number < Transforms.Count;number++)
        {
            int index = number;//避免闭包问题
            Transforms[number].GetComponent<CanvasGroup>().DOFade(0f,0.7f).SetEase(Ease.InExpo)//[最终值，持续时间，非线性]
            .OnComplete(()=>
            {
                Transforms[index].gameObject.SetActive(false);//完成后取消激活状态
            });
        }
    }
    private void Appear_StarCard()//选择卡牌界面非线性显现
    {
        //将所有的星能之力卡片消失[先简单设置不激活，可以设置协程减少透明度最后不激活][要记得启动激活]
        for (int number = 0; number < Transforms.Count; number++)
        {
            int index = number;//避免闭包问题
            Transforms[number].GetComponent<CanvasGroup>().DOFade(1f, 0.7f).SetEase(Ease.InExpo)//[最终值，持续时间，非线性]
            .OnComplete(() =>
            {
                if(index == Transforms.Count-1)//当循坏到最后一个才执行
                {
                    //设置选择逻辑
                    isSelected = false;//等显现动画执行完后再给玩家点击
                }
            });
        }
    }
}
