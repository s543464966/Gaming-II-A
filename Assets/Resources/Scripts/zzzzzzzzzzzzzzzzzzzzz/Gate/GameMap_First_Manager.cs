using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.UI;

public class GameMap_First_Manager : MonoBehaviour
{
    //public GameObject[] levelUIGameObjects;//UI对象数组
    private GameObject[] levelUIObjects;
    private Dictionary<int, List<LevelNode>> gameMap;//保存随机关卡路线的引用
    // Start is called before the first frame update
    public GameMap_UIManager gameMap_UIManager;//关卡地图路线连接脚本
    private void Awake() 
    {
        AutoCreateAdaptArrayToInstance();//调用生成方法
        //DontDestroyOnLoad(gameObject);//将该对象放入不销毁区，避免重复创建[只在开启该大关的时候才创建] 需要根游戏对象而不是子对象 
        //levelButtons = new Dictionary<int, List<LevelButton>>();//new一个对象
    }
    void Start()
    {

        //创建预定义的关卡节点[维护]
        Dictionary<int, List<LevelNode>> predefinedLevelNodes = new Dictionary<int, List<LevelNode>>
        {
            { 0, new List<LevelNode> { new LevelNode { Level = 0, Index = 0 }, new LevelNode { Level = 0, Index = 1 }, new LevelNode { Level = 0, Index = 2 } } },
            { 1, new List<LevelNode> { new LevelNode { Level = 1, Index = 0 }, new LevelNode { Level = 1, Index = 1 }, new LevelNode { Level = 1, Index = 2 } } },
            { 2, new List<LevelNode> { new LevelNode { Level = 2, Index = 0 }, new LevelNode { Level = 2, Index = 1 }, new LevelNode { Level = 2, Index = 2 } } },
            { 3, new List<LevelNode> { new LevelNode { Level = 3, Index = 0 }, new LevelNode { Level = 3, Index = 1 }, new LevelNode { Level = 3, Index = 2 } } },
            { 4, new List<LevelNode> { new LevelNode { Level = 4, Index = 0 }, new LevelNode { Level = 4, Index = 1 }, new LevelNode { Level = 4, Index = 2 } } },
            { 5, new List<LevelNode> { new LevelNode { Level = 5, Index = 0 }, new LevelNode { Level = 5, Index = 1 }, new LevelNode { Level = 5, Index = 2 } } },
            { 6, new List<LevelNode> { new LevelNode { Level = 6, Index = 0 }, new LevelNode { Level = 6, Index = 1 }, new LevelNode { Level = 6, Index = 2 } } },
            { 7, new List<LevelNode> { new LevelNode { Level = 7, Index = 0 }, new LevelNode { Level = 7, Index = 1 }, new LevelNode { Level = 7, Index = 2 } } },
            { 8, new List<LevelNode> { new LevelNode { Level = 8, Index = 0 }, new LevelNode { Level = 8, Index = 1 }, new LevelNode { Level = 8, Index = 2 } } },
            { 9, new List<LevelNode> { new LevelNode { Level = 9, Index = 0 }, new LevelNode { Level = 9, Index = 1 }, new LevelNode { Level = 9, Index = 2 } } },
            { 10, new List<LevelNode> { new LevelNode { Level = 10, Index = 0 } } }
        };

        //将预定义好的数据给随机算法生成图纸
        gameMap = Manager_Random_LevelRoutes.RandomAlgorithm_LevelRoutes(predefinedLevelNodes);

        Debug.Log("随机路线算法分配完毕 " + gameMap.Count);
        //debug出来随机分配的连接路线
        for(int i = 0 ; i <gameMap.Count - 1;i++)
        {
            for(int j = 0; j<gameMap[i].Count;j++)
            {
                LevelNode textNode = gameMap[i][j];
                int textindex = textNode.Index;
                List<LevelNode> textNodes = textNode.ConnectNextNodes;
                if(textNodes.Count == 0)
                {
                    Debug.Log("这是第"+i+"级,第"+textindex+"个Node,"+"该Node没有要连接的");
                }
                else
                {
                    for (int k = 0; k < textNodes.Count; k++)
                    {
                        int textNextLevel = textNodes[k].Level;
                        int textNextIndex = textNodes[k].Index;
                        Debug.Log("这是第" + i + "级,第" + textindex + "个Node," + "该Node要连接第" + textNextLevel + "级的第" + textNextIndex + "个Node");
                    }
                }
                
            }
        }
        
        SaveToInstance();
        //至此把UI对象以及关卡Node类信息放入了LevelButton类里
        
        //调用MapUI管理器进行生成路线
        gameMap_UIManager.ShiftFinalLevelRouteDrawing(gameMap);//这里面包括了关卡Node本体以及关卡Node类变量 类变量里又记录了从随机路线算法里分配的下一级要连接的关卡Node
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    public void AutoCreateAdaptArrayToInstance()//自动将子对象实例转换成数组
    {
        //获取UI子对象数目
        int childCount = gameObject.transform.childCount;
        //new一个临时列表来动态存储子对象
        List<GameObject> tempChildObjects = new List<GameObject>();
        //将子对象提纯放入临时列表里
        for (int childUINumber = 0; childUINumber < childCount; childUINumber++)
        {
            Transform childTransfrom = gameObject.transform.GetChild(childUINumber);
            if (childTransfrom.name != "Btn_Return")//避开返回UI对象
            {
                tempChildObjects.Add(childTransfrom.gameObject);//将子对象放入临时列表里
            }
        }
        //提纯完毕后将动态列表转化成数组
        levelUIObjects = tempChildObjects.ToArray();
    }
    public void SaveToInstance()//将UI实例保存进图纸里
    {
        int currentLevelButtonUI =0;//UI对象数组的序号索引

        for (int level = 0; level < gameMap.Count; level++)//关卡的等级
        {
            for (int node_Index = 0; node_Index < gameMap[level].Count; node_Index++)//关卡Node
            {
                gameMap[level][node_Index].UI_Instance = levelUIObjects[currentLevelButtonUI];//把UI对象实例保存进去

                Debug.Log(levelUIObjects[currentLevelButtonUI].name);
                //将关卡LevelButton放进new出的List里
                Debug.Log(gameMap[level][node_Index].UI_Instance.name);
                
                currentLevelButtonUI++;
            }
        }
    }
}
