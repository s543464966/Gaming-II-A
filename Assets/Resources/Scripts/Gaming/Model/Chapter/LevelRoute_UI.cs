using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class LevelRoute_UI : MonoBehaviour
{
    [Header("模块: 核心配置引用")]
    [Tooltip("关卡初始化核心中心")] public CC_Conflict CC_Conflict; // 关卡初始化核心中心
    [Tooltip("关卡路线背景通用图")] public Sprite levelroutebg; // 例子->(待改进)到时资源是由chapter带入的

    [Header("模块: 章节预留显示及挂载")]
    [Tooltip("章节大图背景展区")] public Image chapter_BG; // 章节大图背景展区
    [Tooltip("章节名称")] public GameObject chapter_Text_Name; // 章节名称
    [Tooltip("章节层级序列数")] public GameObject chapter_Text_Level; // 章节层级序列数
    [Tooltip("章节确认执行按钮")] public Image chapter_Btn_Play; // 章节确认执行按钮
    [Tooltip("已解锁确认图")] public Sprite Btn_BigBox_1; // 章节确认按钮-已解锁
    [Tooltip("未解锁禁用图")] public Sprite Btn_BigBox_0; // 章节确认按钮-未解锁
    [Tooltip("章节确认操作文案节点")] public GameObject chapter_Text_Play; // 章节确认按钮文案
    [Tooltip("强记录章节ID流")] public int chapterId; // 章节ID

    [Header("模块: 随机地图排列与生成")]
    [Tooltip("Level自身预制体资源")] public GameObject levelPrefab; // Level自带预制体资源
    [Tooltip("顶部安全边距")] public int margin_Height; // 边距高度
    [Tooltip("路线纵深的距离与折算规则")] public Vector2 routeUI_Straight_Size; // 路线UI的尺寸
    [Tooltip("可视的关卡路线渲染Content根节点")] public RectTransform levelRouteContent; // 显示关卡路线的Content
    [Tooltip("起点占位符根结点,定底")] public GameObject blankOriginObj; // 起始占位符对象
    [Tooltip("关卡路线背景图实体")] public Image levelRouteBG; // 关卡路线背景UI
    
    // --- 内部状态 --- (全局索引与换算缓存)
    private GameData GameData => DBCC_DataBase.Instance.GameData; // GameData别名单例提取
    private Chapter currentChapter; // 当前推拿进入的章节目标
    private Vector2 blankOriginPlace; // 转换后的基础对齐锚位置

    // ----------------------------------------------------------------------------------------------------------

    // ==========================================
    // 1. 初始化预处理与绑定 (Initial)
    // ==========================================

    /// <summary>
    /// 【核心】章节场景生命周期开启
    /// </summary>
    private void Awake()
    {
    }
    
    private void Start()
    {
    }

    /// <summary>
    /// 测控占位符原点
    /// 负责: 获取预置位定底高度给全路线作生成推演的起点
    /// </summary>
    private void GetBlankOriginPos()
    {
        //  第一关的位置(提前预制好的)
        blankOriginPlace = blankOriginObj.GetComponent<RectTransform>().anchoredPosition;
        Debug.Log(blankOriginPlace);
    }

    // ==========================================
    // 2. 关卡路线图生成与渲染 (Generate & Display)
    // ==========================================

    /// <summary>
    /// 可视化展示推演大图
    /// 负责: 更换底层并激活本体遮罩显示全貌
    /// </summary>
    public void Show_ChapterLevelRoute()
    {
        //  更新显示关卡路线相关UI
        levelRouteBG.sprite = levelroutebg;     //更换背景
        //  激活自身
        gameObject.SetActive(true);
        //GetBlankOriginPos();    //获取占位符初始位置
        //  更新章节路线并复现
        //Update_RamdonMapsPageSize(_chapter);
    }

    /// <summary>
    /// 隐藏章节路线页面
    /// </summary>
    public void Hide_ChapterLevelRoute()
    {
        gameObject.SetActive(false);
    }
    
    /// <summary>
    /// 触发关卡路线流排布构造
    /// 负责: 1.获取基点锚, 2.拉伸Content总宽底, 3.执行节点UI实体投射并预先隐藏该组件
    /// </summary>
    /// <param name="_chapter">需要重铸展示图扑的章节模型</param>
    public void Create_ChapterLevelRoute(Chapter _chapter)
    {
        //  更新显示关卡路线相关UI
        //levelRouteBG.sprite = levelroutebg;     //更换背景
        //  激活自身
        gameObject.SetActive(true);
        GetBlankOriginPos();    //获取占位符初始位置
        //  更新章节路线并复现
        Update_RamdonMapsPageSize(_chapter);
        //  生成完后隐藏自身
        gameObject.SetActive(false);
    }


    /// <summary>
    /// 计算推演Content承载纵深(层高)
    /// 负责: 通过测算层数预铺高适配防越界穿模, 并调用实质还原
    /// </summary>
    /// <param name="_chapter">用于统计核心数的章节实例</param>
    private void Update_RamdonMapsPageSize(Chapter _chapter)
    {
        int sum = 0;
        //层数 = 1(起始关卡)  + 关卡中间层数+ 1(Boss关)
        if (_chapter.SO_Chapter != null)
        {   
            sum = (_chapter.level_List.Count - 2) / 3;  //去掉起始和boss关，算中间层
            Debug.Log($"chapterSection 总层数为: {sum}");
        }
        else
        {
            Debug.LogWarning("chapterSection 列表为空！");
        }
        int layers = sum + 2;
        // 计算总高度 = 层数 x 直线高度 + 预制体高度 + top栏的高度
        float totalHeight = (layers - 1) * levelPrefab.GetComponent<C_Level>().LevelRoad[1].rectTransform.rect.width + levelPrefab.GetComponent<RectTransform>().rect.height + CC_Conflict.topContainer.GetComponent<RectTransform>().rect.height;
        // 设置关卡页面区域高度
        levelRouteContent.GetComponent<RectTransform>().sizeDelta = new Vector2(levelRouteContent.GetComponent<RectTransform>().sizeDelta.x, totalHeight);
        // // 增加最小高度限制
        // float contentHeight = Mathf.Max(minHeight, totalHeight);
        // //---改动
        // float childHeight = minHeight;
        // // 计算需要的边距
        // float requiredHeight = contentHeight - childHeight;
        //---

        //调整完该章节内关卡高度后可视化关卡路线
        Restore_ChapterMaps(_chapter);
    }
    /// <summary>
    /// 【核心】推演及还原路向物理对象层展现
    /// 负责: 根据配标与层级数据实例化图标, 组装连线交互网道流并预发绑定事件与结构
    /// </summary>
    /// <param name="_chapter">进行网道恢复关联的核心数据结构源</param>
    private void Restore_ChapterMaps(Chapter _chapter)
    {
        //  处理第一关（起始关）
        Level startLevel = _chapter.level_List[0];//  获得Level数据类
        //  初始化关卡按钮UI
        blankOriginObj.GetComponent<C_Level>().Init_LevelBtnUI(startLevel,CC_Conflict.LevelRoute_UI);

        int x = 1;
        Vector2 tempPos = new Vector2();
        Vector2 anchoerBottom = new Vector2(0.5f,0);
        //  这里处理中间层
        for (int i = 1; i < _chapter.level_List.Count - 1; i++)
        {
            //  获得Level数据类
            Level level = _chapter.level_List[i];
            if (x == 1)
            {
                //正常设置位置，左；
                blankOriginPlace += new Vector2(0, 300);
                tempPos = blankOriginPlace;
                tempPos += new Vector2(-300, 0);
                x++;
                Debug.Log(tempPos);
                if (level == null) continue;    //挖空位置需要跳过
                GameObject AddLevelPrefab = Instantiate(levelPrefab, levelRouteContent);
                //  初始化关卡按钮UI
                AddLevelPrefab.GetComponent<C_Level>().Init_LevelBtnUI(level,CC_Conflict.LevelRoute_UI);
                //  设置锚点
                AddLevelPrefab.GetComponent<RectTransform>().anchorMin = anchoerBottom;
                AddLevelPrefab.GetComponent<RectTransform>().anchorMax = anchoerBottom;
                //  根据锚点设置锚点位置
                AddLevelPrefab.GetComponent<RectTransform>().anchoredPosition = tempPos;
                continue;
            }
            if (x == 2)
            {
                //正常设置位置，中；
                tempPos += new Vector2(300, 0);
                Debug.Log(tempPos);
                x++;
                if (level == null) continue;    //挖空位置需要跳过
                GameObject AddLevelPrefab = Instantiate(levelPrefab, levelRouteContent);
                //  初始化关卡按钮UI
                AddLevelPrefab.GetComponent<C_Level>().Init_LevelBtnUI(level,CC_Conflict.LevelRoute_UI);
                //  设置锚点
                AddLevelPrefab.GetComponent<RectTransform>().anchorMin = anchoerBottom;
                AddLevelPrefab.GetComponent<RectTransform>().anchorMax = anchoerBottom;
                //  根据锚点设置锚点位置
                AddLevelPrefab.GetComponent<RectTransform>().anchoredPosition = blankOriginPlace;
                continue;
            }
            if (x == 3)
            {
                //正常设置位置，右；
                tempPos += new Vector2(300, 0);
                Debug.Log(tempPos);
                x = 1;
                if (level == null) continue;    //挖空位置需要跳过
                GameObject AddLevelPrefab = Instantiate(levelPrefab, levelRouteContent);
                //  初始化关卡按钮UI
                AddLevelPrefab.GetComponent<C_Level>().Init_LevelBtnUI(level,CC_Conflict.LevelRoute_UI);
                //  设置锚点
                AddLevelPrefab.GetComponent<RectTransform>().anchorMin = anchoerBottom;
                AddLevelPrefab.GetComponent<RectTransform>().anchorMax = anchoerBottom;
                //  根据锚点设置锚点位置
                AddLevelPrefab.GetComponent<RectTransform>().anchoredPosition = tempPos;
                continue;
            }
        }
        //  处理最后一层的Boss关
        Level bossLevel = _chapter.level_List[_chapter.level_List.Count - 1];//  获得Level数据类
        //正常设置位置，中；
        blankOriginPlace += new Vector2(0, 300);    //只需要改变Y值
        GameObject AddBossLevelPrefab = Instantiate(levelPrefab, levelRouteContent);
        //  初始化关卡按钮UI
        AddBossLevelPrefab.GetComponent<C_Level>().Init_LevelBtnUI(bossLevel,CC_Conflict.LevelRoute_UI);
        //  设置锚点
        AddBossLevelPrefab.GetComponent<RectTransform>().anchorMin = anchoerBottom;
        AddBossLevelPrefab.GetComponent<RectTransform>().anchorMax = anchoerBottom;
        //  根据锚点设置锚点位置
        AddBossLevelPrefab.GetComponent<RectTransform>().anchoredPosition = blankOriginPlace;

        // 获取章节数据
        // CC_Chapter.Instance.SetCurrentChapter(_SO_Chapter, _chapterIndex, _isUnlocked);
        // //获取章节关卡路线数据
        // levels_Route = CC_Chapter.Instance.currentChapter.levels_Route;
        // //动态调整关卡页面高度
        // UpdateLevelPageSize(CC_Chapter.Instance.currentChapter);
    }
    // public void OnChapterEnter() //展示被隐藏的随机地图页面
    // {
    //     //AddCanvasOrder();
    //     //isChapterState = true;
    // }



    // ==========================================
    // 4. 用户交互接口区 (Interactions)
    // ==========================================

    /// <summary>
    /// 玩家操控：退出挂起返回主页(预留)
    /// </summary>
    public void OnChapterReturnButton()
    {
        //  处理章节页面的UI
        //SubCanvasOrder();
        //isChapterState = false;
        //（待改进)寻找主页的HomeUI激活
        // FindObjectOfType<CC_Home>().OnHomeUItoEnter();
    }
    /// <summary>
    /// 玩家操控：战备展示
    /// 负责: 将界面下潜并告知系统中心调回战场视界
    /// </summary>
    public void OnBtn_ViewServant()
    {
        if (CC_Conflict == null)
        {
            Debug.LogError("LevelRoute_UI 缺少 CC_Conflict 引用, 无法返回当前节点内容。");
            return;
        }

        CC_Conflict.Return_NodeContentFromRouteView();
    }

    /// <summary>
    /// 路线节点点击后的统一转发入口
    /// </summary>
    /// <param name="_level">被点击的关卡节点</param>
    public void On_LevelNodeClicked(Level _level)
    {
        if (CC_Conflict == null)
        {
            Debug.LogError("LevelRoute_UI 缺少 CC_Conflict 引用, 无法处理关卡节点点击。");
            return;
        }

        CC_Conflict.Handle_LevelNodeSelected(_level);
    }
    
    // ----------------------------------------------------------------------------------------------------------

    //模块：Common for RandomMaps and Chapter
    // public void AddCanvasOrder()
    // {
    //     //chapterCanvas.sortingOrder++;
    //     gameObject.SetActive(true);
    // }
    // public void SubCanvasOrder()
    // {
    //     //chapterCanvas.sortingOrder--;
    //     gameObject.SetActive(false);
    // }
}
    //======分配关卡路线UI======//
    // private void LevelRouteVisionUI()
    // {
    //     //  将所有子对象清空
    //     foreach (Transform child in levelPanelTrans)
    //     {
    //         Destroy(child.gameObject);
    //     }
    //     //根据章节读取所分配好的关卡路线图进行实例化
    //     for (int layer = 0; layer < layers; layer++)    //对每层
    //     {
    //         //每层的高度(第一层占位符 + 层数 * 直线高度)
    //         float yPos = blankOriginPlace.y + routeUI_Straight_Size.x * layer;
    //         List<Level> currentLayer = levels_Route[layer];
    //         //生成当前层的实例
    //         for (int levelIndex = 0; levelIndex < levels_Route[layer].Count; levelIndex++)
    //         {
    //             Level level = levels_Route[layer][levelIndex];
    //             if (level == null) continue;
    //             //X的位置从第一个开始往右边算
    //             float xPos = (levelIndex - 1) * routeUI_Left_Size.x;
    //             if (layer == levels_Route.Count - 1) xPos = 0;  //Boss关
    //             //实例化对象
    //             GameObject levelInstance = Instantiate(levelPrefab, levelPanelTrans);
    //             level.instance = levelInstance;   //将实例赋值给关卡类
    //             levelInstance.GetComponent<RectTransform>().anchorMax = new Vector2(0.5f, 0);
    //             levelInstance.GetComponent<RectTransform>().anchorMin = new Vector2(0.5f, 0);//设置自身锚点
    //             //设置位置
    //             levelInstance.GetComponent<RectTransform>().anchoredPosition = new Vector2(xPos, yPos);
    //             //给实例按钮上的交互脚本赋予关卡类
    //             levelInstance.GetComponent<C_Level>().thisLevelData = level;

    //             //根据关卡数据状态设置UI对象的参数
    //             if (level.isUnlocked == false)    //未解锁
    //             {
    //                 levelInstance.GetComponent<C_Level>().Update_Level(level);
    //             }
    //             else if (level.isUnlocked == true && level.isCompleted == false)    //解锁但没完成
    //             {
    //                 if (level.isUnSelected == true)   //通过关卡同层的其他关卡
    //                 {
    //                     levelInstance.GetComponent<C_Level>().Update_Level(level);
    //                     continue;
    //                 }
    //                 //判断关卡类型
    //                 if (level.levelType == LevelType.Rest)   //修整点关卡
    //                 {
    //                     levelInstance.GetComponent<C_Level>().Update_Level(level);
    //                 }
    //                 else// 其余对战关卡[还未制作精英 boss 普通的Icon]
    //                 {
    //                     levelInstance.GetComponent<C_Level>().Update_Level(level);
    //                 }
    //             }
    //             else if (level.isUnlocked == true && level.isCompleted == true)     //解锁并完成
    //             {
    //                 levelInstance.GetComponent<C_Level>().Update_Level(level);
    //             }
    //         }
    //     }
    //     // 实例路线[可以在生成的时候把自己顺序调到最后面]
    //     for (int layer = 0; layer < levels_Route.Count; layer++)
    //     {
    //         for (int levelIndex = 0; levelIndex < levels_Route[layer].Count; levelIndex++)
    //         {
    //             if (levels_Route[layer][levelIndex] == null) continue;
    //             //拿到两个对象实例
    //             GameObject currentLevelOBJ = levels_Route[layer][levelIndex].instance;
    //             List<Level> linkLevelOBJ_List = levels_Route[layer][levelIndex].ConnectNextLevel;
    //             foreach (Level level in linkLevelOBJ_List)
    //             {
    //                 GameObject linkLevelOBJ = level.instance;
    //                 //  计算两个实例的坐标折中然后
    //                 float xPos = (currentLevelOBJ.transform.position.x + linkLevelOBJ.transform.position.x) / 2;
    //                 float yPos = (currentLevelOBJ.transform.position.y + linkLevelOBJ.transform.position.y) / 2;
    //                 GameObject routeUI = Instantiate(routePrefab, levelPanelTrans);
    //                 routeUI.GetComponent<RectTransform>().anchorMax = new Vector2(0.5f, 0);
    //                 routeUI.GetComponent<RectTransform>().anchorMin = new Vector2(0.5f, 0);//设置自身锚点与关卡实例一致
    //                 //  设置路线UI实例的参数
    //                 routeUI.transform.position = new Vector2(xPos, yPos);
    //                 routeUI.transform.SetAsFirstSibling();  //放置在最前面
    //                 //  根据两个对象的相对位置来决定是哪个UI
    //                 if (currentLevelOBJ.transform.position.x == linkLevelOBJ.transform.position.x)//x值相等即直线连接
    //                 {
    //                     routeUI.GetComponent<Image>().sprite = routeUI_Straight;
    //                     routeUI.GetComponent<RectTransform>().sizeDelta = routeUI_Straight_Size;
    //                     routeUI.GetComponent<RectTransform>().rotation = Quaternion.Euler(0, 0, 90);
    //                 }
    //                 else if (currentLevelOBJ.transform.position.x > linkLevelOBJ.transform.position.x)//连接左边
    //                 {
    //                     routeUI.GetComponent<Image>().sprite = routeUI_Left;
    //                     routeUI.GetComponent<RectTransform>().sizeDelta = routeUI_Left_Size;
    //                 }
    //                 else if (currentLevelOBJ.transform.position.x < linkLevelOBJ.transform.position.x)//连接右边
    //                 {
    //                     routeUI.GetComponent<Image>().sprite = routeUI_Left;
    //                     routeUI.GetComponent<RectTransform>().sizeDelta = routeUI_Left_Size;
    //                     //  需要翻转
    //                     routeUI.GetComponent<RectTransform>().rotation = Quaternion.Euler(0, 180, 0);
    //                 }
    //             }
    //         }
    //     }
    // }
    // //======关卡完成时调整关卡UI======//
    // public void UpdateLevelStateUI(Level _Level)
    // {
    //     //根据数据层发来更改后状态的关卡调整其附属实例的UI表现
    //     if (_Level.isUnlocked == true && _Level.isCompleted == false)    //解锁但没完成
    //     {
    //         if (_Level.isUnSelected == true)   //解锁的关卡未被选择
    //         {
    //             _Level.instance.GetComponent<C_Level>().InBattleChangeLevelBtnUI(completed_Level_UnSelected_Icon);
    //             return;
    //         }
    //         //判断关卡类型
    //         if (_Level.levelType == LevelType.Rest)   //修整点关卡
    //         {
    //             _Level.instance.GetComponent<C_Level>().InBattleChangeLevelBtnUI(unlocked_Level_Rest_Icon);
    //         }
    //         else// 其余对战关卡[还未制作精英 boss 普通的Icon]
    //         {
    //             _Level.instance.GetComponent<C_Level>().InBattleChangeLevelBtnUI(unlocked_Level_Icon);
    //         }
    //     }
    //     else if (_Level.isUnlocked == true && _Level.isCompleted == true)     //解锁并完成
    //     {
    //         _Level.instance.GetComponent<C_Level>().InBattleChangeLevelBtnUI(completed_Level_Icon);
    //     }
    // }

    //======章节UI模块的激活方法======//
    
