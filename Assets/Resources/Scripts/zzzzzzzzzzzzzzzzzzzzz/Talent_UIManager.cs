using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class Talent_UIManager : MonoBehaviour
{
    //保留对装备数据层的引用
    public Example_Equip_DataManager example_Equip_DataManager;
    public RectTransform talentPageOriginPosition;
    private Vector2 temp;
    public float movingLimit;
    void Start()
    {
        temp = talentPageOriginPosition.anchoredPosition;//记录初始值
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    public void LimitPageMoving()
    {
        
        Vector2 talentPageCurrentPosition = gameObject.GetComponent<RectTransform>().anchoredPosition;//先获取当前的位置
        
        Debug.Log("获取当前位置");
        Debug.Log(talentPageCurrentPosition);
        float newY = Mathf.Clamp(talentPageCurrentPosition.y, temp.y , temp.y + movingLimit );//设置页面移动限制
        
        Vector2 newPosition = new Vector2(talentPageOriginPosition.anchoredPosition.x, newY);//新的位置
        talentPageOriginPosition.anchoredPosition = newPosition;//更新位置//不能修改RectTransfrom的y位置，只能用向量进行修改
        Debug.Log(talentPageOriginPosition.anchoredPosition);
    }

    public void OnResetTalentButton()//重置天赋的方法
    {
        //先获取当前英雄
        string currentname = GameObject.FindWithTag("Player").name;
        //调用数据层将当前英雄所拥有的天赋全部清空并显示到最终的UI层上
        example_Equip_DataManager.ResetHeroActivatedData_Talent(currentname);
        //将天赋子物体与当前英雄最新的天赋库里激活的全部置零_0
        ResetTalentImage(currentname);
        //将当前英雄的天赋仓库置零
        Manager_Talent.ClearTalentList(currentname);
    }

    public void ResetTalentImage(string targetname)//置零天赋激活的图片
    {
        //获取当前英雄最新的天赋库
        Dictionary<string, List<Example_SO_Talent>> hero_Talent = Manager_Talent.GetAllHeroTalents();
        //获取全部子对象进行遍历
        foreach(Transform childTransfrom in gameObject.transform)//子对象遍历循环和目标英雄所对应激活的天赋库嵌套循环
        {
            foreach(Example_SO_Talent activatedTalent in hero_Talent[targetname])
            {
                if(childTransfrom.GetComponent<Example_Talent_Loader>() != null)//避免空对象报错
                {
                    //筛选出激活的天赋进行置零
                    if (childTransfrom.GetComponent<Example_Talent_Loader>().specificTalent_SO == activatedTalent)
                    {
                        //如果相同相当于子对象上的SO为仓库里对应的激活的SO天赋
                        //当前是将透明度改回去[有0和1后可以标准化修改]
                        Image childImage = childTransfrom.GetComponent<Image>();
                        childImage.color = new Color(childImage.color.r, childImage.color.g, childImage.color.b, 0.5f);
                    }
                }
            }
        }
    }

}
