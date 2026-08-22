using DG.Tweening;
using TMPro;
using UnityEngine;
using UnityEngine.UI;
using System.Collections.Generic;

public class CC_Home : MonoBehaviour
{
    //====== 必要数据 ======//
    private GameData GameData => DBCC_DataBase.Instance != null ? DBCC_DataBase.Instance.GameData : null; // GameData别名[因为单例原因]
    private SaveData SaveData => DBCC_DataBase.Instance != null ? DBCC_DataBase.Instance.SaveData : null; // SaveData简写

    //====== 各个控制中心 ======//
    [Header("模块: 各个控制中心")]
    [Tooltip("模式")] public CC_Model CC_Model; // 模式
    [Tooltip("卡牌")] public CC_Card CC_Card; // 卡牌
    [Tooltip("背包")] public CC_Backpack CC_Backpack; // 背包
    [Tooltip("城镇")] public CC_Town CC_Town; // 城镇
    [Tooltip("藏品")] public CC_Collection CC_Collection; // 藏品
    [Tooltip("成就")] public CC_Achieve CC_Achieve; // 成就
    [Tooltip("商城")] public CC_Mall CC_Mall; // 商城
    [Tooltip("活动")] public CC_Activity CC_Activity; // 活动
    [Tooltip("社交")] public CC_Social CC_Social; // 社交
    [Tooltip("排行榜")] public CC_PlayerRank CC_PlayerRank; // 排行榜
    [Tooltip("账号")] public CC_Account CC_Account; // 账号
    [Tooltip("骰子")] public CC_Dice CC_Dice; // 骰子


    //====== 各个页面 ======//
    [Header("模块: 各个页面")]
    [Tooltip("模式页面")] public GameObject Page_Model; // 模式页面
    [Tooltip("背包页面")] public GameObject Page_Backpack; // 背包页面
    [Tooltip("卡牌页面")] public GameObject Page_Card; // 卡牌页面
    [Tooltip("卡牌-队伍页面")] public List<GameObject> Page_CardTeam; // 卡牌-队伍页面
    [Tooltip("城镇页面")] public GameObject Page_Town; // 城镇页面
    [Tooltip("藏品页面")] public GameObject Page_Collection; // 藏品页面
    [Tooltip("成就页面")] public GameObject Page_Achieve; // 成就页面
    [Tooltip("商城页面")] public GameObject Page_Mall; // 商城页面
    [Tooltip("商城-契约召唤页面")] public GameObject Page_Mall_ContractCall; // 商城-契约召唤页面
    [Tooltip("活动页面")] public GameObject Page_Activity; // 活动页面
    [Tooltip("活动-传说之路页面")] public GameObject Page_Activity_LegendRoad; // 活动-传说之路页面
    [Tooltip("活动-每日任务页面")] public GameObject Page_Activity_DaliyTask; // 活动-每日任务页面
    [Tooltip("活动-七日签到页面")] public GameObject Page_Activity_SevenSign; // 活动-七日签到页面
    [Tooltip("社交-社区页面")] public GameObject Page_Social_Community; // 社交-社区页面
    [Tooltip("社交-好友页面")] public GameObject Page_Social_Friend; // 社交-好友页面
    [Tooltip("社交-排行榜页面")] public GameObject Page_Social_Rank; // 社交-排行榜页面
    [Tooltip("账号页面")] public GameObject Page_Account; // 账号页面
    [Tooltip("通知页面")] public GameObject Page_Account_Notice; // 通知页面
    [Tooltip("设置页面")] public GameObject Page_Account_Settings; // 设置页面
    [Tooltip("更多页面")] public GameObject Page_NavMore; // 更多页面

    //====== 动态数据 ======//
    [Header("模块: 动态数据")]
    [Tooltip("玩家头像")] public Image playerHeadImage; // 玩家头像
    [Tooltip("玩家名称")] public TMP_Text playerIdText; // 玩家名称
    [Tooltip("金币")] public TMP_Text goldenCountText; // 金币
    [Tooltip("魔石")] public TMP_Text mstoneCountText; // 魔石
    [Tooltip("体力值")] public TMP_Text staminaCountText; // 体力值
    [Tooltip("下一点体力恢复时间")] public TMP_Text staminaNextRecoveryTimeText; // 下一点体力恢复时间
    [Tooltip("体力恢复满时间")] public TMP_Text staminaFullRecoveryTimeText; // 体力恢复满时间
    [Tooltip("主页背景")] public Image Home_BG; // 主页背景

    //====== 临时数据 ======//
    [Header("模块: 临时数据")]
    [Tooltip("关卡摄像机")] public Camera levelCamera; // 关卡摄像机

    /// <summary>
    /// 主页场景初始化入口。
    /// 这里负责: 1.校验当前账号数据是否已准备完成, 2.初始化主页运行时模块, 3.刷新基础显示。
    /// </summary>
    void Awake()
    {
        //获取参考分辨率
        // referenceResolution = GetComponent<CanvasScaler>().referenceResolution; //获取参考分辨率
        // Init_HomeUI();

        if (DBCC_DataBase.Instance == null || GameData == null || SaveData == null)
        {
            Debug.LogWarning("[CC_Home] 当前没有可用的账号存档数据。");
            // 数据缺失时主页无法继续初始化, 但加载页不能因此永久等待。
            Notify_SceneReady_Home();
            return;
        }

        //  需要判断是否加载过，加载过就不需要再初始化了
        if (GameData.isCC_HomeInit_GameData == false)
        {
            //这里初始化所有模块的GameData数据
            Init_LoadDice();
            //Init_LoadEquip();
            // CC_Model.Init_Model();

            // CC_Card.Init_Card();

            //（待改进）这里的部分推后开发
            // CC_Backpack.Init_Backpack();
            // CC_Town.Init_Town();
            // CC_Mall.Init_Mall();
            // CC_Activity.Init_Activity();
            // CC_Collection.Init_Collection();
            // CC_Achieve.Init_Achieve();
            // CC_Social.Init_Socialy();
            // CC_Account.Init_Account();

            GameData.isCC_HomeInit_GameData = true;
            Debug.Log("主界面初始化游戏数据完成");
        }
        //  初始化所有显示部门的开发残留数据(需要的)
        CC_Backpack.Init_PageBackPack();
        CC_Card.Init_PageCard();
        CC_Mall.Init_PageMall();
        CC_PlayerRank.Init_PagePlayerRank();

        // 主页进入后启动用户系统 tick, 体力计算仍由 Sys_User 负责.
        DBCC_DataBase.Instance.Start_UserRuntimeTick_DB();

        // 初始化玩家资源数据显示
        Refresh_PlayerIdUI(GameData.Sys_User.playerId);
        Refresh_GoldUI(GameData.Sys_User.gold);
        Refresh_StarStoneUI(GameData.Sys_User.starStone);
        Refresh_StaminaUI(GameData.Sys_User.stamina);
        Refresh_StaminaTimeUI(GameData.Sys_User.staminaNextRecoveryTimeText, GameData.Sys_User.staminaFullRecoveryTimeText);

        //  同步章节对应主页背景UI,可以合并
        Home_BG.sprite = GameData.Sys_Chapter.currentChapter.SO_Chapter.chapterBG_1;

        // Home 首屏数据和 UI 已经同步完成, 通知 Loading_UIManager 进入关闭流程。
        Notify_SceneReady_Home();
    }

    /// <summary>
    /// 绑定主页需要监听的玩家资源事件。
    /// </summary>
    void Start()
    {
        // 绑定跨场景数据刷新事件
        if (DBCC_DataBase.Instance != null && GameData != null && GameData.Sys_User != null)
        {
            // 主页只订阅用户系统事件, 不主动计算用户资源变化.
            GameData.Sys_User.OnPlayerIdChanged += Refresh_PlayerIdUI;
            GameData.Sys_User.OnGoldChanged += Refresh_GoldUI;
            GameData.Sys_User.OnStarStoneChanged += Refresh_StarStoneUI;
            GameData.Sys_User.OnStaminaChanged += Refresh_StaminaUI;
            GameData.Sys_User.OnStaminaTimeChanged += Refresh_StaminaTimeUI;
        }
    }

    /// <summary>
    /// 注销主页绑定的玩家资源事件。
    /// </summary>
    void OnDestroy()
    {
        // 切场景/销毁界面时务必注销事件，防止游离指针报错
        if (DBCC_DataBase.Instance != null && GameData != null && GameData.Sys_User != null)
        {
            GameData.Sys_User.OnPlayerIdChanged -= Refresh_PlayerIdUI;
            GameData.Sys_User.OnGoldChanged -= Refresh_GoldUI;
            GameData.Sys_User.OnStarStoneChanged -= Refresh_StarStoneUI;
            GameData.Sys_User.OnStaminaChanged -= Refresh_StaminaUI;
            GameData.Sys_User.OnStaminaTimeChanged -= Refresh_StaminaTimeUI;
        }
    }
    // ==========================================
    // 1. 数据核心 (Data Core)
    // ==========================================

    /// <summary>
    /// 刷新玩家名称显示
    /// 负责: 更新顶部栏玩家名称文本
    /// </summary>
    /// <param name="playerId">玩家名称</param>
    void Refresh_PlayerIdUI(string playerId)
    {
        // 文本引用未绑定时直接跳过, 避免影响主页基础流程.
        if (playerIdText != null) playerIdText.text = playerId;
    }
    /// <summary>
    /// 刷新金币UI数量显示
    /// 负责: 更新顶部栏金币文本
    /// </summary>
    /// <param name="amount">更新后的金币数量</param>
    void Refresh_GoldUI(int amount)
    {
        if (goldenCountText != null) goldenCountText.text = amount.ToString();
    }
    /// <summary>
    /// 刷新魔石UI数量显示
    /// 负责: 更新顶部栏魔石文本
    /// </summary>
    /// <param name="amount">更新后的魔石数量</param>
    void Refresh_StarStoneUI(int amount)
    {
        if (mstoneCountText != null) mstoneCountText.text = amount.ToString();
    }
    /// <summary>
    /// 刷新体力UI数量显示
    /// 负责: 更新顶部栏体力文本, 并拼接最大值
    /// </summary>
    /// <param name="amount">更新后的体力数量</param>
    void Refresh_StaminaUI(int amount)
    {
        int staminaMax = GameData != null && GameData.Sys_User != null ? GameData.Sys_User.staminaMax : 100;
        if (staminaCountText != null) staminaCountText.text = amount.ToString() + " / " + staminaMax;
    }

    /// <summary>
    /// 刷新体力恢复时间显示
    /// 负责: 更新下一点体力与回满体力倒计时
    /// </summary>
    /// <param name="nextRecoveryTimeText">下一点体力恢复时间文本</param>
    /// <param name="fullRecoveryTimeText">恢复满体力时间文本</param>
    void Refresh_StaminaTimeUI(string nextRecoveryTimeText, string fullRecoveryTimeText)
    {
        // Sys_User 已处理好 HH:MM:SS 文本, 主页只负责显示.
        if (staminaNextRecoveryTimeText != null) staminaNextRecoveryTimeText.text = nextRecoveryTimeText;
        if (staminaFullRecoveryTimeText != null) staminaFullRecoveryTimeText.text = fullRecoveryTimeText;
    }

    // ==========================================
    // 2. 业务方法 (Business Logic)
    // ==========================================

    /// <summary>
    /// 【核心】加载骰子数据
    /// 负责: 1.读取配置表和存档数据, 2.生成动态骰子对象, 3.保存回全局数据中心
    /// </summary>
    public void Init_LoadDice() // 加载骰子数据
    {

        SO_Dice[] all_SO_Dices;
        Dictionary<string, Dice> heroDiceDict = new Dictionary<string, Dice>(); //玩家拥有的卡牌字典
        List<Dice> heroDiceFightList = new List<Dice>();   //玩家拥有的卡牌中，出战的卡牌列表
        Dictionary<string, Dice> lockDiceDict = new Dictionary<string, Dice>();   //玩家未拥有的卡牌字典

        //加载所有英雄和随从卡牌的固定SO数据 和 DBCC中玩家的Dice数据:
        all_SO_Dices = Resources.LoadAll<SO_Dice>("Item/Dice");  //Assets/Resources/Item/Dice
        if (all_SO_Dices == null) { Debug.LogError("未找到章节SO_Dice: 请检查文件路径: Dice"); }
        Dictionary<string, SaveData_Dices> SD_Dices = SaveData.SD_Dices; //获取SaveData中保存的所有骰子数据;

        //初始化所有Dice并为其赋予SD和SO数据
        foreach (SO_Dice _all_SO_Dice in all_SO_Dices)
        {
            Dice dice = null;

            //根据UserSaveData数据，设定Dice的基础信息。
            if (SD_Dices.TryGetValue(_all_SO_Dice.diceId, out SaveData_Dices saveData_Dices))
            {
                // 已解锁
                dice = new Dice(_all_SO_Dice);  //给与必要的基础SO数据
                dice.Init_HeroCard(saveData_Dices.getNum, saveData_Dices.isDiceFight); //初始化所有非SO的动态数据
                heroDiceDict[dice.SO_Dice.diceId] = dice;   //将已解锁的heroCard添加进入卡牌字典 
                if (dice.isDiceFight == true)
                {
                    heroDiceFightList.Add(dice);
                }
            }
            else
            {
                // 未解锁
                dice = new Dice(_all_SO_Dice);  //给与必要的基础SO数据
                lockDiceDict[dice.SO_Dice.diceId] = dice; //将未解锁的heroCard添加进入卡牌字典      
            }
        }
        //将生成好的heroDice数据，存回到GameData中。
        GameData.heroDiceDict = heroDiceDict;
        GameData.heroDiceFightList = heroDiceFightList;
        GameData.lockDiceDict = lockDiceDict;
        //  骰子最大数
        //GameData.heroDiceCount = ;
        Debug.Log("完成骰子模块数据初始化加载");
    }

    /// <summary>
    /// 【核心】加载装备数据
    /// 负责: 1.读取配置表和存档数据, 2.生成动态装备对象, 3.保存回全局数据中心
    /// </summary>
    public void Init_LoadEquip() // 加载装备数据
    {

        SO_Equip[] all_SO_Equips;
        Dictionary<string, Equip> heroEquipDict = new Dictionary<string, Equip>(); //玩家拥有的装备字典
        Dictionary<string, Equip> lockEquipDict = new Dictionary<string, Equip>(); //玩家未拥有的装备字典

        //加载所有英雄和随从卡牌的固定SO数据 和 DBCC中玩家的Dice数据:
        all_SO_Equips = Resources.LoadAll<SO_Equip>("Equip");
        if (all_SO_Equips == null) { Debug.LogError("未找到章节SO_Equip: 请检查文件路径: Equip"); }
        Dictionary<string, SaveData_Equips> SD_Equips = DBCC_DataBase.Instance.SaveData.SD_Equips; //章节1~N;

        //初始化所有Dice并为其赋予SD和SO数据
        foreach (SO_Equip _all_SO_Equip in all_SO_Equips)
        {
            Equip equip = null;

            //根据UserSaveData数据，设定Equip的基础信息。
            if (SD_Equips.TryGetValue(_all_SO_Equip.equipId, out SaveData_Equips saveData_Equips))
            {
                //已解锁
                equip = new Equip(_all_SO_Equip);  //给与必要的基础SO数据
                heroEquipDict[equip.SO_Equip.equipId] = equip;   //将已解锁的heroCard添加进入卡牌字典  
            }
            else
            {
                //未解锁
                equip = new Equip(_all_SO_Equip);  //给与必要的基础SO数据
                lockEquipDict[equip.SO_Equip.equipId] = equip; //将未解锁的heroCard添加进入卡牌字典      
            }
        }
        //将生成好的heroCard数据，存回到GameData中。
        GameData.heroEquipDict = heroEquipDict;
        GameData.lockEquipDict = lockEquipDict;
        Debug.Log("完成装备模块数据初始化加载");
    }

    //（待改进）需要新增PlayerContainer需要通过点击玩家头像的按钮，来打开玩家设置页面，玩家设置页面关闭后返回主页，玩家设置展示内容包括：玩家ID、客户、公告、兑换码等相关东西，可以参考MasterGO的参考图

    // ==========================================
    // 3. 导航栏 (Navigation)
    // ==========================================
    // (待改进) 备忘: 每个页面, 都需要一个独立的页面, 通过返回按钮来关闭自己->分为通用页
    // 通用模块页面按钮方法->适用于单一的打开和关闭, 不适用于打开后需要定位到某个页面的情况

    /// <summary>
    /// 点击进入章节按钮
    /// 负责: 根据当前章节是否有路线数据, 来决定是生成新路线还是直接进入关卡场景
    /// </summary>
    public void OnBtn_EnterChapter()
    {
        Debug.Log(GameData.Sys_Chapter.currentChapter.SO_Chapter.name);
        if (GameData.Sys_Chapter.currentChapter.level_List.Count == 0)   //判断如果是新章节，则创建关卡路线并生成
        {
            Debug.Log("开始生成路线!");
            CC_Model.Create_ChapterMaps(GameData.Sys_Chapter.currentChapter); //创建新章节随机路线数据

            // 新章节生成路线后, 统一由章节系统定位第一关入口。
            GameData.Sys_Chapter.Ensure_CurrentLevelReady();

            // Home场景切换到LevelFighting场景
            Loading_UIManager.Instance.OnLoadScene("LevelFighting");
        }
        else
        {
            //(待改进) 可能需要在gamedata里新增当前挑战章节的id
            // if (GameData.currentChapter.SO_Chapter.chapterIndex != Chapter_UI.Instance.chapterId)   //判断为关卡路线未复原则复原路线
            // {
            //     //Chapter_UI.Instance.Restore_ChapterMaps(GameData.currentChapter);
            //     // Home场景切换到LevelFighting场景
            //     Loading_UIManager.Instance.OnLoadScene("LevelFighting");
            // }
            Debug.Log(GameData.Sys_Chapter.CurrentLevel.levelType);
            // Home场景切换到LevelFighting场景
            Loading_UIManager.Instance.OnLoadScene("LevelFighting");
        }
    }
    /// <summary>
    /// 通用模式页面开关
    /// 负责: 切换目标页面的显示与隐藏状态
    /// </summary>
    /// <param name="_page">要操作的UI页面对象</param>
    public void OnBtn_GeneralModulePage(GameObject _page)
    {
        if (_page.activeSelf == true)
            _page.SetActive(false);
        else
            _page.SetActive(true);
    }

    /// <summary>
    /// 保存当前账号数据并返回登录入口场景。
    /// </summary>
    public void OnBtn_ReturnLoadScene()
    {
        // 返回登录入口场景前，务必保存当前账号数据，防止玩家数据丢失。
        if (DBCC_DataBase.Instance != null)
        {
            DBCC_DataBase.Instance.Save_CurrentUserData_DB();
        }

        if (Loading_UIManager.Instance == null)
        {
            Debug.LogWarning("[CC_Home] Loading_UIManager instance is missing.");
            return;
        }

        if (DBCC_DataBase.Instance != null)
        {
            // 返回登录入口视为当前账号离线, 保存后停止在线 tick.
            DBCC_DataBase.Instance.Stop_UserRuntimeTick_DB();
        }

        // 返回登录入口需要等待 CC_Account 自动登录检查完成, 避免登录 UI 状态跳变。
        Loading_UIManager.Instance.OnLoadScene("LoadScene", true);
    }

    /// <summary>
    /// 通知加载控制器当前主页场景已经完成初始化。
    /// 这个方法只表达 Home 首屏可展示, 不负责保存或切换场景。
    /// </summary>
    void Notify_SceneReady_Home()
    {
        if (Loading_UIManager.Instance != null)
        {
            Loading_UIManager.Instance.Notify_SceneReady_Loading();
        }
    }

    public void OnBtn_ModelPage() //章节页面按钮
    {
        //切换页面显示与隐藏
        if (Page_Model.activeSelf == true)
            Page_Model.SetActive(false);
        else
            Page_Model.SetActive(true);

    }
    public void OnBtn_BackpackPage() //背包页面按钮
    {
        //切换页面显示与隐藏
        if (Page_Backpack.activeSelf == true)
            Page_Backpack.SetActive(false);
        else
            Page_Backpack.SetActive(true);
    }
    public void OnBtn_CardPage() //卡牌页面按钮
    {
        //切换页面显示与隐藏
        if (Page_Card.activeSelf == true)
            Page_Card.SetActive(false);
        else
            Page_Card.SetActive(true);
    }
    public void OnBtn_TownPage() //城镇页面按钮
    {
        //切换页面显示与隐藏
        if (Page_Town.activeSelf == true)
            Page_Town.SetActive(false);
        else
            Page_Town.SetActive(true);
    }

    public void OnBtn_CollectionPage() //藏品页面按钮
    {
        //切换页面显示与隐藏
        if (Page_Collection.activeSelf == true)
            Page_Collection.SetActive(false);
        else
            Page_Collection.SetActive(true);
    }

    public void OnBtn_AchievePage() //成就页面按钮
    {
        //切换页面显示与隐藏
        if (Page_Achieve.activeSelf == true)
            Page_Achieve.SetActive(false);
        else
            Page_Achieve.SetActive(true);
    }

    public void OnBtn_MallPage() //商城页面按钮
    {
        //切换页面显示与隐藏
        if (Page_Mall.activeSelf == true)
            Page_Mall.SetActive(false);
        else
            Page_Mall.SetActive(true);
    }

    public void OnBtn_Mall_ContractCallPage() //商城-契约召唤页面按钮
    {
        //切换页面显示与隐藏
        if (Page_Mall.activeSelf == true)
            Page_Mall.SetActive(false);
        else
            Page_Mall.SetActive(true);
        //（待改进）这里还需要定位到契约召唤子页面

    }

    public void OnBtn_ActivityPage() //活动页面按钮
    {
        //切换页面显示与隐藏
        if (Page_Activity.activeSelf == true)
            Page_Activity.SetActive(false);
        else
            Page_Activity.SetActive(true);
    }

    public void OnBtn_ActivityLegendRoadPage() //活动-传说之路页面按钮
    {
        //切换页面显示与隐藏
        if (Page_Activity.activeSelf == true)
            Page_Activity.SetActive(false);
        else
            Page_Activity.SetActive(true);
    }

    public void OnBtn_ActivityDaliyTaskPage() //活动-日常任务页面按钮
    {
        //切换页面显示与隐藏
        if (Page_Activity.activeSelf == true)
            Page_Activity.SetActive(false);
        else
            Page_Activity.SetActive(true);
    }

    public void OnBtn_ActivitySevenSignPage() //活动-七日签到页面按钮
    {
        //切换页面显示与隐藏
        if (Page_Activity.activeSelf == true)
            Page_Activity.SetActive(false);
        else
            Page_Activity.SetActive(true);
    }

    public void OnBtn_SocialCommunityPage() //社交-社区页面按钮
    {
        //切换页面显示与隐藏
        if (Page_Social_Community.activeSelf == true)
            Page_Social_Community.SetActive(false);
        else
            Page_Social_Community.SetActive(true);
    }

    public void OnBtn_SocialFriendPage() //社交-好友页面按钮
    {
        //切换页面显示与隐藏
        if (Page_Social_Friend.activeSelf == true)
            Page_Social_Friend.SetActive(false);
        else
            Page_Social_Friend.SetActive(true);
    }

    public void OnBtn_SocialRankPage() //社交-排行榜页面按钮
    {
        //切换页面显示与隐藏
        if (Page_Social_Rank.activeSelf == true)
            Page_Social_Rank.SetActive(false);
        else
            Page_Social_Rank.SetActive(true);
    }

    public void OnBtn_AccountPage() //账号页面按钮
    {
        //切换页面显示与隐藏
        if (Page_Account.activeSelf == true)
            Page_Account.SetActive(false);
        else
            Page_Account.SetActive(true);
    }
    public void OnBtn_AccountNoticePage() //通知页面按钮
    {
        //切换页面显示与隐藏
        if (Page_Account_Notice.activeSelf == true)
            Page_Account_Notice.SetActive(false);
        else
            Page_Account_Notice.SetActive(true);
    }
    public void OnBtn_AccountSettingsPage() //设置页面按钮
    {
        //切换页面显示与隐藏
        if (Page_Account_Settings.activeSelf == true)
            Page_Account_Settings.SetActive(false);
        else
            Page_Account_Settings.SetActive(true);
    }
}
