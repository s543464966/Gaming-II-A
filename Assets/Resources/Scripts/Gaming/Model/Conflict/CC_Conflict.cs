using System.Collections.Generic;
using DG.Tweening;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class CC_Conflict : MonoBehaviour
{
    // --- 内部状态 --- (全局索引与换算缓存)
    private GameData GameData => DBCC_DataBase.Instance.GameData; // GameData别名单例提取
    private Level currentLevel; // 当前关卡数据类
    public Sprite levelbg; // 例子->(待改进)关卡背景图，应该是放在level身上的
    private List<Card> heroUnlockedCardList; // Gamedata中存储的玩家卡牌总数
    private Conflict_RuntimeBoard conflict_RuntimeBoard; // 章节运行时对象管理器
    private float halfScreenHeight; // 屏幕一半高度
    private Vector2 topContainer_OriginPos; // top栏初始位置
    private List<SO_Card> card_3in1 = new List<SO_Card>(); // 3选1的添加随从表
    private bool hasLevelResultSettled; // 当前战斗结果是否已结算
    private const float MOVE_DURATION = 0.25f; // 动画参数

    [Header("模块: 对战对象引用")]
    [Tooltip("对战卡牌预制体")] public GameObject fightingCard_prefab;
    [Tooltip("回合对战中心")] public CC_Fight CC_Fight;
    [Tooltip("骰子管理器")] public Fight_Dice Fight_Dice;
    [Tooltip("战斗词条处理器")] public Fight_Entry Fight_Entry;
    [Tooltip("能力目标获取器")] public Fight_Effect Fight_Effect;
    [Tooltip("章节UI管理中心")] public LevelRoute_UI LevelRoute_UI;

    [Header("模块: 备战UI引用")]
    [Tooltip("关卡路线背景UI")] public Image levelBG;
    [Tooltip("海克斯强化三选一")] public GameObject threeToOneUI;
    [Tooltip("获胜UI")] public GameObject victoryUI;
    [Tooltip("失败UI")] public GameObject defeatUI;
    [Tooltip("顶部Top栏")] public RectTransform topContainer;
    [Tooltip("章节信息")] public TMP_Text chapterInfo;
    [Tooltip("卡牌容器对象")] public GameObject CardContainer;
    [Tooltip("备战席管理中心")] public Conflict_Prepare Conflict_Prepare;
    [Tooltip("卡牌属性管理中心")] public Card_Attribute Card_Attribute;

    [Header("模块: 卡牌占位符")]
    [Tooltip("怪物占位符")] public List<GameObject> monsterCardBlankList;//编辑器挂好
    [Tooltip("玩家卡牌占位符")] public List<GameObject> heroCardBlankList;//编辑器挂好

    [Header("模块: 通用交互按钮")]
    [Tooltip("返回按钮")] public Button Btn_GoBack;
    [Tooltip("设置按钮")] public Button Btn_Setting;
    [Tooltip("查看路线按钮")] public Button Btn_ViewChapterRoute;

    [Header("模块: 海克斯三选一界面")]
    [Tooltip("卡牌形象主图")] public Image[] ThreeToOne_CardMain_Img;
    [Tooltip("卡牌名字")] public TMP_Text[] ThreeToOne_CardName_TMP;
    [Tooltip("三选一按钮")] public Button[] ThreeToOne_Button;

    /// <summary>
    /// 章节运行时对象管理器
    /// </summary>
    public Conflict_RuntimeBoard Conflict_RuntimeBoard => conflict_RuntimeBoard;

    // ==========================================
    // 1. 初始化预处理 (Initial)
    // ==========================================

    /// <summary>
    /// 【核心】初始化关卡场景
    /// 负责: 1.分配组件引用, 2.初始化卡牌站位位置, 3.生成章节路线和关卡环境
    /// </summary>
    private void Awake()
    {
        //骰子管理器
        // manager_PlayerDice.manager_ActionQueue = Fight_Fighting;
        //  位置坐标记录
        topContainer_OriginPos = topContainer.anchoredPosition;
        //  骰子管理器赋值引用
        Fight_Dice.CC_Fight = CC_Fight;
        CC_Fight.Fight_Dice = Fight_Dice;
        //分配属性表
        Conflict_Prepare.Card_Attribute = Card_Attribute;
        conflict_RuntimeBoard = new Conflict_RuntimeBoard(
            CC_Fight,
            Fight_Entry,
            Fight_Effect,
            fightingCard_prefab,
            CardContainer,
            monsterCardBlankList,
            heroCardBlankList,
            Card_Attribute);

        heroUnlockedCardList = GameData.Sys_Card.Get_DisplayCardList(true);;
        //  将所有怪物白卡占位符设定规定位置
        Init_MonsterCardBlank();

        //  初始化创建章节路线
        LevelRoute_UI.Create_ChapterLevelRoute(GameData.Sys_Chapter.currentChapter);
    }

    private void Start()
    {
        // 通知提前生成Prepare界面
        Conflict_Prepare.Init_Prepare(heroUnlockedCardList);
        Bind_RewardSelectionButtons();
        Init_ConflictEntry();
    }

    /// <summary>
    /// 【核心】初始化章节场景入口
    /// </summary>
    void Init_ConflictEntry()
    {
        // 章节基础数据缺失时, 保底回到路线展示状态, 避免直接创建战斗内容。
        if (GameData == null || GameData.Sys_Chapter == null || GameData.Sys_Chapter.currentChapter == null)
        {
            Debug.LogWarning("[CC_Conflict] 章节数据为空，默认进入路线页。");
            Enter_RoutePage();
            return;
        }

        // 当前章节没有路线数据时, 场景层不能继续进入节点内容。
        if (GameData.Sys_Chapter.currentChapter.level_List.Count == 0)
        {
            Debug.LogWarning("[CC_Conflict] 当前章节没有关卡数据，默认进入路线页。");
            Enter_RoutePage();
            return;
        }

        // 复用章节系统的当前关卡兜底逻辑, 避免入口层重复维护第一关初始化细节。
        if (GameData.Sys_Chapter.CurrentLevel == null)
        {
            if (!GameData.Sys_Chapter.Ensure_CurrentLevelReady())
            {
                Debug.LogWarning("[CC_Conflict] 当前章节无法定位有效关卡，默认进入路线页。");
                Enter_RoutePage();
                return;
            }
        }

        // 根据章节入口恢复状态决定显示路线页或当前节点内容页。
        switch (GameData.Sys_Chapter.currentEntryState)
        {
            case ChapterEntryState.RouteSelection:
                Enter_RoutePage();
                break;
            case ChapterEntryState.NodeContent:
                Enter_NodeContentPage(GameData.Sys_Chapter.CurrentLevel);
                break;
            default:
                Enter_RoutePage();
                break;
        }
    }

    /// <summary>
    /// 进入章节路线选择页面
    /// </summary>
    void Enter_RoutePage()
    {
        // 路线页作为章节选择态, 不展示战斗准备按钮和出战对象。
        GameData.Sys_Chapter.currentEntryState = ChapterEntryState.RouteSelection;
        Com_HideBtn();
        Hide_HeroCard_Prepare();
        LevelRoute_UI.Show_ChapterLevelRoute();
    }

    /// <summary>
    /// 【核心】处理路线节点点击后的页面切换
    /// </summary>
    /// <param name="_level">被点击的目标关卡</param>
    public void Handle_LevelNodeSelected(Level _level)
    {
        if (_level == null)
        {
            Debug.LogWarning("[CC_Conflict] 收到空的关卡节点，忽略处理。");
            return;
        }

        GameData.Sys_Chapter.Process_LevelSelected(_level);
        Enter_NodeContentPage(_level);
    }

    /// <summary>
    /// 进入当前节点内容页面
    /// </summary>
    /// <param name="_level">当前目标关卡</param>
    void Enter_NodeContentPage(Level _level)
    {
        // 无有效节点时退回路线页, 防止后续战斗节点初始化访问空关卡。
        if (_level == null)
        {
            Debug.LogWarning("[CC_Conflict] 当前关卡为空，回退到路线页。");
            Enter_RoutePage();
            return;
        }

        GameData.Sys_Chapter.CurrentLevel = _level;
        GameData.Sys_Chapter.currentEntryState = ChapterEntryState.NodeContent;
        currentLevel = _level;
        LevelRoute_UI.Hide_ChapterLevelRoute();
        hasLevelResultSettled = false;

        // 战斗类节点进入关卡准备, 非战斗节点进入扩展占位。
        if (Check_IsBattleLevel(_level.levelType))
        {
            Enter_BattleNode();
            return;
        }

        Enter_ExtensionNodePlaceholder(_level);
    }

    /// <summary>
    /// 进入战斗类节点内容
    /// </summary>
    void Enter_BattleNode()
    {
        Create_Level();
        Show_LevelContent();
    }

    /// <summary>
    /// 进入非战斗类节点占位流程
    /// </summary>
    /// <param name="_level">当前非战斗节点</param>
    void Enter_ExtensionNodePlaceholder(Level _level)
    {
        // 非战斗节点只刷新通用章节信息, 不生成战斗对象。
        Update_LevelInfo();
        levelBG.sprite = levelbg;
        Com_ShowBtn();
        Hide_HeroCard_Prepare();

        // 未来 Rest, BlackMarket, Relic, Advanture 等节点在这里接入独立处理器。
        Debug.Log($"[CC_Conflict] 当前节点 {_level.levelType} 暂未实现具体内容，已进入扩展占位流程。");
    }

    /// <summary>
    /// 判断是否为战斗类节点
    /// </summary>
    /// <param name="levelType">关卡类型</param>
    /// <returns>是否为战斗类节点</returns>
    bool Check_IsBattleLevel(LevelType levelType)
    {
        return levelType == LevelType.Start ||
               levelType == LevelType.M ||
               levelType == LevelType.Me ||
               levelType == LevelType.Mb;
    }

    /// <summary>
    /// 初始化卡牌占位符
    /// 负责: 获取并记录所有占位符的世界坐标，并将怪物占位符移至上半屏
    /// </summary>
    private void Init_MonsterCardBlank()
    {
        //获取一半屏幕固定高度
        halfScreenHeight = GetComponent<RectTransform>().rect.height / 2;
        conflict_RuntimeBoard.Init_BlankCache(halfScreenHeight);
    }

    /// <summary>
    /// 【核心】创建并初始化关卡
    /// 负责: 1.读取关卡类型配置怪物, 2.生成怪物卡牌实体, 3.实例化玩家出战卡牌
    /// </summary>
    public void Create_Level() //进入每关时重新分配当前场景的相关参数-> 因为在段内挑战时，场景不变需要重新分配数据
    {
        //初始化关卡数据
        currentLevel = GameData.Sys_Chapter.CurrentLevel;
        //更新当前关卡UI信息
        Update_LevelInfo();
        Debug.Log("此时关卡类型为:" + currentLevel.levelType);

        conflict_RuntimeBoard.Create_LevelRuntimeObjects(currentLevel, GameData.Sys_Card.Get_FightCardList());
    }

    // ==========================================
    // 2. 通用关卡UI视图管理 (View Control)
    // ==========================================

    /// <summary>
    /// 更新关卡界面信息
    /// 负责: 拼接当前关卡的章节信息并刷新顶部UI显示
    /// </summary>
    private void Update_LevelInfo()
    {
        // 通过Level提供的信息来展现对应的UI
        chapterInfo.text = $"{GameData.Sys_Chapter.currentChapter.SO_Chapter.chapterName}·章节Lv.{GameData.Sys_Chapter.currentChapter.SO_Chapter.chapterIndex}";
        //背景图
        // if (_chapter.isUnlocked == true)
        // {
        //     //已解锁
        //     chapter_Text_Name.GetComponent<TMP_Text>().text = _chapter.SO_Chapter.chapterName;  //章节名称
        //     chapter_Text_Level.GetComponent<TMP_Text>().text = $"Lv.{_chapter.SO_Chapter.chapterIndex}";  //章节序列
        //     // chapter_Btn_Play.GetComponent<TMP_Text>().text = $"Lv.{_chapter.chapterIndex}";
        //     chapter_Text_Play.GetComponent<TMP_Text>().text = $"进入禁地";
        //     chapter_Btn_Play.sprite = Btn_BigBox_1; //章节确认按钮
        //     chapter_BG.sprite = _chapter.SO_Chapter.chapterBG_1;   //背景图
        // }
        // else
        // {
        //     //未解锁
        //     chapter_Text_Name.GetComponent<TMP_Text>().text = _chapter.SO_Chapter.chapterName;  //章节名称
        //     chapter_Text_Level.GetComponent<TMP_Text>().text = $"Lv.{_chapter.SO_Chapter.chapterIndex}";  //章节序列
        //     // chapter_Btn_Play.GetComponent<TMP_Text>().text = $"Lv.{_chapter.chapterIndex}";
        //     chapter_Text_Play.GetComponent<TMP_Text>().text = $"未解锁";
        //     chapter_Btn_Play.sprite = Btn_BigBox_0; //章节确认按钮
        //     chapter_BG.sprite = _chapter.SO_Chapter.chapterBG_0;
        // }
    }

    /// <summary>
    /// 隐藏玩家参战卡牌和相关占位符
    /// 负责: 将所有玩家出战相关UI表现设为不可见
    /// </summary>
    public void Hide_HeroCard()
    {
        conflict_RuntimeBoard.Set_HeroCardBlankVisible(false);
        conflict_RuntimeBoard.Set_HeroCardVisible_Runtime(false);
    }

    /// <summary>
    /// 显示玩家参战卡牌和相关占位符
    /// 负责: 重新开启所有玩家出战相关UI的可见性
    /// </summary>
    public void Show_HeroCard()
    {
        conflict_RuntimeBoard.Set_HeroCardVisible_Runtime(true);
        conflict_RuntimeBoard.Set_HeroCardBlankVisible(true);
    }

    /// <summary>
    /// 备战界面隐藏参战成员
    /// 负责: 隐藏备战席的玩家卡牌及其占位符
    /// </summary>
    public void Hide_HeroCard_Prepare()
    {
        conflict_RuntimeBoard.Set_HeroCardBlankVisible(false);
        conflict_RuntimeBoard.Set_HeroCardVisible_Runtime(false);
    }

    /// <summary>
    /// 备战界面显示参战成员
    /// 负责: 重新显示备战席的玩家卡牌及其占位符
    /// </summary>
    public void Show_HeroCard_Prepare()
    {
        conflict_RuntimeBoard.Set_HeroCardVisible_Runtime(true);
        conflict_RuntimeBoard.Set_HeroCardBlankVisible(true);
    }

    /// <summary>
    /// 刷新并显示战斗主界面
    /// 负责: 重置战斗环境，显示所有按钮和玩家卡牌
    /// </summary>
    public void Show_LevelContent()
    {
        currentLevel = GameData.Sys_Chapter.CurrentLevel;
        // 更新关卡相关UI
        levelBG.sprite = levelbg; // 更换背景
        // 展示按钮
        Com_ShowBtn();
        // 展示玩家卡牌
        Show_HeroCard();
    }

    // ==========================================
    // 4. 用户交互接口层操作区 (Interactions)
    // ==========================================

    /// <summary>
    /// 玩家操作：确认阵容并发起战斗
    /// 负责: 1.校验是否全部上阵, 2.隐藏相关交互按钮与占位符, 3.移交战斗统筹方调度骰子与特效, 4.播放切场移动动画
    /// </summary>
    public void OnBtn_PlayTheGame()
    {
        // 开战前只做当前流程必要的安全校验, 不额外做阵容完整性限制。
        if (currentLevel == null)
        {
            Debug.LogWarning("[CC_Conflict] 当前关卡为空，无法开始战斗。");
            return;
        }

        if (!Check_IsBattleLevel(currentLevel.levelType))
        {
            Debug.LogWarning($"[CC_Conflict] 当前节点 {currentLevel.levelType} 不是战斗类节点，无法开始战斗。");
            return;
        }

        if (!conflict_RuntimeBoard.Try_StartRuntimeFight(this, currentLevel))
        {
            return;
        }

        // 战斗接入成功后再切换 UI 和交互状态, 避免失败接入导致准备态丢失。
        hasLevelResultSettled = false;
        //玩家的白卡隐身
        conflict_RuntimeBoard.Set_HeroCardBlankVisible(false);
        conflict_RuntimeBoard.Set_HeroCardInteraction(false);
        //隐藏按钮和怪物占位符
        Com_HideBtn();
        conflict_RuntimeBoard.Set_MonsterCardBlankVisible(false);

        //Top栏UI移动上去
        MoveUp_TopContainer();
        //怪物卡牌移动下来
        conflict_RuntimeBoard.Move_MonsterRuntimeEntry(-halfScreenHeight, MOVE_DURATION);

        //初始化骰子模块，并通知对战模块执行    
        Fight_Dice.Init_Dice(GameData.heroDiceFightList, GameData.heroDiceFightList.Count, currentLevel.monsterDiceList, currentLevel.monsterDiceList.Count); //(待修改)玩家骰子数量要修改

    }

    // ==========================================
    // 5. 动画序列调控专区 (Animations)
    // ==========================================

    private Sequence Move_TopContainer(float _endPosition)  //移动top栏动画
    {
        //制作动画
        Sequence sequence = DOTween.Sequence();
        Tween prepare_Move = topContainer.DOAnchorPosY(_endPosition, MOVE_DURATION).SetEase(Ease.OutQuad);
        sequence.Append(prepare_Move);
        return sequence;
    }

    /// <summary>
    /// 将顶部导航栏UI移出当前屏幕可见区域
    /// </summary>
    public void MoveUp_TopContainer()
    {
        Move_TopContainer(topContainer_OriginPos.y + topContainer.rect.height * 2);
    }

    /// <summary>
    /// 恢复顶部导航栏UI至初始占位点
    /// </summary>
    public void MoveDown_TopContainer()
    {
        Move_TopContainer(topContainer_OriginPos.y);
    }

    // public void OnBtn_OpenPrepareArea() //备战席打开按钮--> 如果出战席满了还有位置可以打开备战席
    // {
    //     //隐藏按钮
    //     Com_HideBtn();
    //     //通知备战席模块打开页面    
    //     Conflict_Prepare.Show_PrepareArea();
    // }

    // ----------------------------------------------------------------------------------------------------------
    //模块：Fighting - 对战阶段

    public void OnBtn_GameringControlOrAuto() //玩家操控：切换玩家操控或自动对战
    {
        //一键切换自动化和玩家操控，false为玩家操控，true为自动化
        if (GameData.Sys_User.isAutoPlay)
        {
            CC_Fight.isAutoPlay = false;
            GameData.Sys_User.Set_AutoPlayState(false);
            Debug.Log("玩家操控骰子，等待玩家操控骰子对战！");
        }
        else
        {
            CC_Fight.isAutoPlay = true;
            GameData.Sys_User.Set_AutoPlayState(true);
            Debug.Log("自动化操控骰子");
        }
    }
    // ----------------------------------------------------------------------------------------------------------
    //模块：Result - 结果阶段

    public void OnBtn_ReturnHome() //玩家操控：返回主页
    {
        Return_Home();
    }
    public void OnBtn_ViewChapterRoute() //玩家操控：查看章节路线
    {
        if (currentLevel == null || GameData.Sys_Chapter.currentEntryState != ChapterEntryState.NodeContent)
        {
            Debug.LogWarning("[CC_Conflict] 当前不在节点内容页，无法查看章节路线。");
            return;
        }

        // 查看路线只是当前节点内容上的视图切换, 不改变章节入口状态。
        Com_HideBtn();
        Hide_HeroCard();
        LevelRoute_UI.Show_ChapterLevelRoute();
    }

    /// <summary>
    /// 【核心】从路线查看视图回到当前节点内容
    /// </summary>
    public void Return_NodeContentFromRouteView()
    {
        if (GameData.Sys_Chapter.currentEntryState != ChapterEntryState.NodeContent)
        {
            Debug.LogWarning("[CC_Conflict] 当前不在节点内容状态，不能从路线查看返回节点内容。");
            return;
        }

        Level targetLevel = GameData.Sys_Chapter.CurrentLevel ?? currentLevel;
        if (targetLevel == null)
        {
            Debug.LogWarning("[CC_Conflict] 当前节点为空，无法从路线预览返回节点内容。");
            Enter_RoutePage();
            return;
        }

        currentLevel = targetLevel;
        GameData.Sys_Chapter.CurrentLevel = targetLevel;
        LevelRoute_UI.Hide_ChapterLevelRoute();

        // 从路线预览返回时只恢复视图, 不重新创建关卡运行时对象。
        if (Check_IsBattleLevel(targetLevel.levelType))
        {
            Show_LevelContent();
            return;
        }

        Enter_ExtensionNodePlaceholder(targetLevel);
    }

    // ----------------------------------------------------------------------------------------------------------
    //模块：Common for Fight

    public void Com_ShowBtn()
    {
        if (currentLevel == null || GameData.Sys_Chapter == null || GameData.Sys_Chapter.currentChapter == null)
        {
            Btn_GoBack.gameObject.SetActive(false);
            Btn_ViewChapterRoute.gameObject.SetActive(false);
            return;
        }

        Btn_GoBack.gameObject.SetActive(false);
        //  玩家此时关卡为第一关或者rest关卡才能允许返回Home主页场景
        if (Check_CanReturnHome()) Btn_GoBack.gameObject.SetActive(true);
        Btn_ViewChapterRoute.gameObject.SetActive(true);
    }
    public void Com_HideBtn()
    {
        Btn_GoBack.gameObject.SetActive(false);
        Btn_ViewChapterRoute.gameObject.SetActive(false);
    }

    //关卡获胜
    public void Result_Level_Victory()
    {
        // 防止同一场战斗内多个死亡对象连续触发重复结算。
        if (!Try_EnterResultSettlement())
        {
            return;
        }

        // 胜利结算必须绑定当前关卡, 否则无法推进章节路线数据。
        if (GameData.Sys_Chapter.CurrentLevel == null)
        {
            Debug.LogWarning("[CC_Conflict] 胜利结算时当前关卡为空。");
            return;
        }

        // 先同步存活英雄数据, 再写入章节通关数据并进入奖励占位流程。
        conflict_RuntimeBoard.Update_AliveHeroCardData();
        GameData.Sys_Chapter.Process_CompletedLevel(LevelCompletionResult.Victory);
        Debug.Log("关卡胜利！");
        // 先不做 三选一 界面展示
        Set_ResultUIVisible(false, true, false);
        //StartHextechSelection();
    }

    //模块：三选一
    // 三选一的数据
    private List<T> GetRandomUniqueCards<T>(List<T> source, int count)
    {
        // 创建一个索引列表 [0, 1, 2, ... Count-1]
        List<int> indexes = new List<int>();
        for (int i = 0; i < source.Count; i++) indexes.Add(i);

        List<T> results = new List<T>();

        // 抽取 count 次
        for (int i = 0; i < count; i++)
        {
            if (indexes.Count == 0) break;

            // 随机选一个索引位置
            int randomPick = Fight_Dice.shareRng.Next(0, indexes.Count);
            int realIndex = indexes[randomPick];

            // 添加到结果
            results.Add(source[realIndex]);

            // 【关键】：从索引池中移除这个索引，确保下次不会再选到它
            indexes.RemoveAt(randomPick);
        }

        return results;
    }
    //  三选一的UI
    private void StartHextechSelection()
    {
        // 奖励数据不足时跳过占位流程, 直接进入胜利结算 UI。
        // sourceDataList = GameData.currentChapter.SO_Monsters_List; // 如果需要动态获取请取消注释
        if (GameData.Sys_Chapter.currentChapter == null ||
            GameData.Sys_Chapter.currentChapter.SO_Monsters_List == null ||
            GameData.Sys_Chapter.currentChapter.SO_Monsters_List.Count < 3)
        {
            Debug.LogWarning("数据源数量不足3个，跳过三选一奖励占位。");
            Set_ResultUIVisible(false, true, false);
            return;
        }

        // 三选一界面配置不足时同样不能阻塞胜利闭环。
        if (ThreeToOne_CardMain_Img == null ||
            ThreeToOne_CardName_TMP == null ||
            ThreeToOne_Button == null ||
            ThreeToOne_CardMain_Img.Length < 3 ||
            ThreeToOne_CardName_TMP.Length < 3 ||
            ThreeToOne_Button.Length < 3)
        {
            Debug.LogWarning("[CC_Conflict] 三选一 UI 配置不足，跳过奖励选择占位。");
            Set_ResultUIVisible(false, true, false);
            return;
        }

        // 抽取 3 个不重复的占位奖励数据。
        List<SO_Card> selectedCards = GetRandomUniqueCards(GameData.Sys_Chapter.currentChapter.SO_Monsters_List, 3);
        card_3in1 = selectedCards;

        // 将占位奖励数据写入三选一界面。
        for (int i = 0; i < selectedCards.Count; i++)
        {
            // 把数据给 UI, 按钮事件由初始化时统一绑定。
            ThreeToOne_CardMain_Img[i].sprite = selectedCards[i].cardImage;
            ThreeToOne_CardName_TMP[i].text = selectedCards[i].cardName;
        }

        // 打开奖励选择面板, 确保胜利和失败结算面板关闭。
        Set_ResultUIVisible(true, false, false);
    }
    // 三选一的按钮
    public void OnButton_3In1_Left()
    {
        Handle_RewardSelected(0);
    }
    public void OnButton_3In1_Mid()
    {
        Handle_RewardSelected(1);
    }
    public void OnButton_3In1_Right()
    {
        Handle_RewardSelected(2);
    }

    //关卡失败
    public void Result_Level_Defeat()
    {
        // 失败结算同样需要防重复, 避免多个英雄死亡连续触发 UI。
        if (!Try_EnterResultSettlement())
        {
            return;
        }

        // 卡牌系统处理失败后的卡牌数据, 章节系统保留当前未完成节点入口。
        GameData.Sys_Card.Process_LevelDefeat(0.15f);
        GameData.Sys_Chapter.Process_CompletedLevel(LevelCompletionResult.Defeat);
        Set_ResultUIVisible(false, false, true);
    }

    //关卡胜利UI页面，及按钮实现
    public void OnBtn_VictoryConfirm()
    {
        Reset_AfterFightToRoute();
    }

    //关卡失败UI页面，及按钮实现
    public void OnBtn_DefeatConfirm()
    {
        conflict_RuntimeBoard.Clear_MonsterRuntimeObjects();
        Set_ResultUIVisible(false, false, false);
        Return_Home();
    }

    /// <summary>
    /// 绑定三选一奖励按钮
    /// </summary>
    void Bind_RewardSelectionButtons()
    {
        // 三选一按钮缺失时, 奖励流程会在显示时自动跳过。
        if (ThreeToOne_Button == null || ThreeToOne_Button.Length < 3)
        {
            Debug.LogWarning("[CC_Conflict] 三选一按钮配置不足，奖励选择将只保留流程占位。");
            return;
        }

        if (ThreeToOne_Button[0] == null || ThreeToOne_Button[1] == null || ThreeToOne_Button[2] == null)
        {
            Debug.LogWarning("[CC_Conflict] 三选一按钮存在空引用，奖励选择将只保留流程占位。");
            return;
        }

        // 运行时统一绑定按钮, 避免依赖场景手动绑定导致旧监听残留。
        ThreeToOne_Button[0].onClick.RemoveAllListeners();
        ThreeToOne_Button[0].onClick.AddListener(OnButton_3In1_Left);
        ThreeToOne_Button[1].onClick.RemoveAllListeners();
        ThreeToOne_Button[1].onClick.AddListener(OnButton_3In1_Mid);
        ThreeToOne_Button[2].onClick.RemoveAllListeners();
        ThreeToOne_Button[2].onClick.AddListener(OnButton_3In1_Right);
    }

    /// <summary>
    /// 判断是否允许直接返回 Home
    /// </summary>
    /// <returns>是否显示返回 Home 按钮</returns>
    bool Check_CanReturnHome()
    {
        return currentLevel.levelType == LevelType.Rest ||
               GameData.Sys_Chapter.CurrentLevel == GameData.Sys_Chapter.currentChapter.level_List[0];
    }

    /// <summary>
    /// 尝试进入战斗结果结算
    /// </summary>
    /// <returns>是否允许本次结果结算</returns>
    bool Try_EnterResultSettlement()
    {
        // 同一场战斗只能允许一次结果结算。
        if (hasLevelResultSettled)
        {
            Debug.LogWarning("[CC_Conflict] 当前战斗结果已经结算，忽略重复回调。");
            return false;
        }

        // 进入结算后隐藏通用按钮, 防止玩家在结果 UI 外继续操作章节。
        hasLevelResultSettled = true;
        Com_HideBtn();
        return true;
    }

    /// <summary>
    /// 处理奖励选择结果
    /// </summary>
    /// <param name="rewardIndex">奖励按钮索引</param>
    void Handle_RewardSelected(int rewardIndex)
    {
        Debug.Log($"玩家选择了第 {rewardIndex + 1} 个奖励占位。");
        Set_ResultUIVisible(false, true, false);
    }

    /// <summary>
    /// 设置结算 UI 显隐
    /// </summary>
    /// <param name="showReward">是否显示奖励选择</param>
    /// <param name="showVictory">是否显示胜利结算</param>
    /// <param name="showDefeat">是否显示失败结算</param>
    void Set_ResultUIVisible(bool showReward, bool showVictory, bool showDefeat)
    {
        if (threeToOneUI != null) threeToOneUI.SetActive(showReward);
        if (victoryUI != null) victoryUI.SetActive(showVictory);
        if (defeatUI != null) defeatUI.SetActive(showDefeat);
    }

    /// <summary>
    /// 战斗胜利后重置运行时并返回章节路线
    /// </summary>
    void Reset_AfterFightToRoute()
    {
        // 重置单场战斗模块和怪物运行时对象。
        Fight_Dice.Reset_FightDice();
        CC_Fight.Reset_CC_Fight();
        conflict_RuntimeBoard.Clear_MonsterRuntimeObjects();

        // 恢复英雄准备态与章节顶部栏, 再回到路线页继续爬塔。
        conflict_RuntimeBoard.Reset_HeroCardRuntimeState_Prepare();
        conflict_RuntimeBoard.Set_HeroCardInteraction(true);
        MoveDown_TopContainer();
        Set_ResultUIVisible(false, false, false);
        Enter_RoutePage();
    }

    /// <summary>
    /// 返回 Home 场景
    /// </summary>
    void Return_Home()
    {
        if (Loading_UIManager.Instance != null) Loading_UIManager.Instance.OnLoadScene("Home");
    }
}

