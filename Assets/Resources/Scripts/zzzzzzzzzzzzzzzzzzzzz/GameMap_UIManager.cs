using System.Collections;
using System.Collections.Generic;
using Unity.Burst.Intrinsics;
using UnityEngine;
using UnityEngine.UI;


public class GameMap_UIManager : MonoBehaviour
{
    private Vector2 temp;//记录起始值
    public RectTransform gameMapFirst_OriginPosition;//自身Rect组件
    public float movingLimit;//限制移动距离
    //预留的直线和向右的线路Sprite
    public Sprite mapLine_UP;//直线
    public Sprite mapLine_Right;//右边
    //预留的关卡种类的图片组[小怪 精英 Boss 黑市 遗迹 补给]
    public Sprite[] sprite_LevelTypes;

    // Start is called before the first frame update
    void Awake()
    {

    }
    void Start()
    {
        temp = gameMapFirst_OriginPosition.anchoredPosition;//记录初始值
        
    }

    // Update is called once per frame
    void Update()
    {

    }
    //将接收到的最终关卡路线图纸实例化出来
    public void ShiftFinalLevelRouteDrawing(Dictionary<int, List<LevelNode>> final_Drawing)
    {
        //将关卡种类的图片UI全部进行替换
        for(int level = 0;level <final_Drawing.Count;level++)
        {
            List<LevelNode> currentLevelNodes = final_Drawing[level];//拿到本级
            for(int index = 0;index<final_Drawing[level].Count;index++)//单个关卡
            {
                //找到该关卡Node上的实例获得UI组件 再找到上面保存的种类进行替换
                GameObject currentLevelNode_Instance = currentLevelNodes[index].UI_Instance;
                Image levelNode_ui = currentLevelNode_Instance.GetComponent<Image>();
                string currentLevelNode_Type = currentLevelNodes[index].levelType;
                if(currentLevelNode_Type == "XG")//小怪
                {
                    levelNode_ui.sprite = sprite_LevelTypes[0];
                }else if(currentLevelNode_Type == "JY")
                {
                    levelNode_ui.sprite = sprite_LevelTypes[1];
                }else if(currentLevelNode_Type == "Boss")
                {
                    levelNode_ui.sprite = sprite_LevelTypes[2];
                }else if(currentLevelNode_Type == "BlackMarket")
                {
                    levelNode_ui.sprite = sprite_LevelTypes[3];
                }else if(currentLevelNode_Type == "Ruin")
                {
                    levelNode_ui.sprite = sprite_LevelTypes[4];
                }else if(currentLevelNode_Type == "Supply")
                {
                    levelNode_ui.sprite = sprite_LevelTypes[5];
                }
                //拿到实例上所挂载的指定脚本
                Manager_JumpTargetLevel manager_JumpTargetLevel = currentLevelNode_Instance.GetComponent<Manager_JumpTargetLevel>();
                //将关卡图纸对应的关卡类型保存进去
                manager_JumpTargetLevel.SaveToLevel(currentLevelNode_Type);
            }
        }
        for(int level= 0; level<final_Drawing.Count-1;level++)//数量只要到BOSS关卡前一级
        {
            Debug.Log("进入UI化第一层");
            List<LevelNode> currentLevelNodes = final_Drawing[level];//拿到本级
            for(int index = 0; index<final_Drawing[level].Count;index++)//对当前级里的每一个关卡Node操作
            {
                //拿到当前关卡Node的本体对象
                GameObject currentNodeUI_Insatance = currentLevelNodes[index].UI_Instance;
                Debug.Log(currentNodeUI_Insatance.transform.position);
                //再拿到要连接下一级关卡的对象
                List<LevelNode> need_ConnectNextNodes = currentLevelNodes[index].ConnectNextNodes;
                for(int targetLevelNode = 0;targetLevelNode<need_ConnectNextNodes.Count;targetLevelNode++)
                {
                    //拿到对象本体
                    GameObject targetConnectUI_Instance = need_ConnectNextNodes[targetLevelNode].UI_Instance;
                    //将当前与要连接的放入连接方法里
                    CurrentLevelNodeLink_To_NextLevelNode(currentNodeUI_Insatance.transform,targetConnectUI_Instance.transform);
                }

                //检测该关卡的激活状态
                if(currentLevelNodes[index].IsActivated == false)//如果是不激活的就不显示
                {
                    currentNodeUI_Insatance.SetActive(false);//[重复刷]
                }
            }
        }
    }

    public void CurrentLevelNodeLink_To_NextLevelNode(Transform currentTransfrom,Transform linkedTransfrom)
    {
        //计算要连接对象之间的中间位置new出新的对象
        Vector2 link_Object_Pos = new Vector2((currentTransfrom.localPosition.x+linkedTransfrom.localPosition.x)/2.0f,(currentTransfrom.localPosition.y+linkedTransfrom.localPosition.y)/2.0f);
        //新建一个空对象
        GameObject line_Instance = new GameObject();
        //设置该对象的位置参数
        line_Instance.transform.parent = gameObject.transform;
        line_Instance.transform.localPosition = link_Object_Pos;
        line_Instance.transform.localScale = new Vector3(1,1,1);//自适应时标准化
        //根据情况修改该对象的大小来符合视觉
        RectTransform line_Instance_Rect = line_Instance.AddComponent<RectTransform>();
        line_Instance_Rect.sizeDelta = new Vector2(240,200);//修改大小
        //给对象添加Image组件
        Image line_Image = line_Instance.AddComponent<Image>();
        //根据两个对象X的相对位置来决定修改是哪张图
        if(currentTransfrom.localPosition.x == linkedTransfrom.localPosition.x)//如果与连接的关卡位置x值相等即直线连接
        {
            line_Image.sprite = mapLine_UP;
        }
        else if(currentTransfrom.localPosition.x > linkedTransfrom.localPosition.x)//连接左边的需要翻转
        {
            line_Image.sprite = mapLine_Right;
            //将该线对象进行Y轴翻转
            line_Instance_Rect.rotation = Quaternion.Euler(0,180,0);
        }
        else if(currentTransfrom.localPosition.x < linkedTransfrom.localPosition.x)//连接右边
        {
            line_Image.sprite = mapLine_Right;
        }
    }

    //限制关卡页面的移动范围
    public void LimitPageMoving()
    {   
        //限制页面的滑动
        Vector2 gameMapFirst_CurrentPosition = gameObject.GetComponent<RectTransform>().anchoredPosition;//先获取当前的位置

        Debug.Log("获取当前位置");
        Debug.Log(gameMapFirst_CurrentPosition);
        float newY = Mathf.Clamp(gameMapFirst_CurrentPosition.y, temp.y - movingLimit , temp.y);//设置页面移动限制
        
        Vector2 newPosition = new Vector2(gameMapFirst_OriginPosition.anchoredPosition.x, newY);//新的位置
        gameMapFirst_OriginPosition.anchoredPosition = newPosition;//更新位置//不能修改RectTransfrom的y位置，只能用向量进行修改
        Debug.Log(gameMapFirst_OriginPosition.anchoredPosition);
    }
}
