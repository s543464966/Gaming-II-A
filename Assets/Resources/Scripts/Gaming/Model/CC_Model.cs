using System.Collections;
using System.Collections.Generic;
using DG.Tweening;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class CC_Model : MonoBehaviour
{
    //获取数据中心
    private GameData GameData => DBCC_DataBase.Instance.GameData;   //GameData别名[因为单例原因]
    [Header("模块: 主界面引用")]
    [Tooltip("主页背景")] public Image Home_BG; // 主页背景
    [Tooltip("章节页面")] public GameObject Page_Chapter; // 章节页面

    [Header("模块: 章节界面展现")]
    [Tooltip("章节存放容器")] public GameObject chapterContainer; // 章节存放容器
    [Tooltip("章节视窗UI预制体")] public GameObject chapterObj_prefab; // 章节视窗UI预制体
    [Tooltip("章节水平分布管理组件")] public HorizontalLayoutGroup horizontalLayoutGroup; // 章节水平分布管理组件
    [Tooltip("章节名字")] public TMP_Text Text_ChapterName; // 章节名字
    [Tooltip("章节序号")] public TMP_Text Text_ChapterIndex; // 章节序号
    [Tooltip("确认选择章节按钮文本")] public TMP_Text Text_ConfirmChapter; // 确认选择章节按钮文本
    [Tooltip("章节奖励")] public List<Image> chapterRewardsImageList; // 章节奖励
    [Tooltip("上一章节视窗")] public Image Img_BeforeChapter; // 上一章节视窗
    [Tooltip("当前章节视窗")] public Image Img_CurrentChapter; // 当前章节视窗
    [Tooltip("下一章节视窗")] public Image Img_AfterChapter; // 下一章节视窗

    [Header("模块: 章节操作按钮")]
    [Tooltip("确认选择章节按钮")] public Button Btn_ConfirmChapter; // 确认选择章节按钮
    [Tooltip("切换上一章按钮")] public Button Btn_BeforeChapter; // 切换上一章按钮
    [Tooltip("切换下一章按钮")] public Button Btn_AfterChapter; // 切换下一章按钮

    [Header("模块: 随机生成")]
    [Tooltip("随机路线生成脚本")] public Chapter_RandomGenerateLevelMaps Chapter_RandomGenerateLevelMaps; // 随机路线生成脚本

    [Header("模块: 主菜单页签配置")]
    [Tooltip("页签文字激活色")] public Color Btn_Light; // 页签文字激活色
    [Tooltip("页签文字未激活色")] public Color Btn_Dark; // 页签文字未激活色
    [Tooltip("冒险按钮文字")] public TMP_Text Btn_Adventure_Text; // 冒险按钮文字
    [Tooltip("PK按钮文字")] public TMP_Text Btn_PK_Text; // PK按钮文字
    [Tooltip("战棋按钮文字")] public TMP_Text Btn_Chess_Text; // 战棋按钮文字
    [Tooltip("娱乐按钮文字")] public TMP_Text Btn_Entertainment_Text; // 娱乐按钮文字

    // --- 内部状态 --- (UI动画控制缓存)
    private float minLimit; // 滑动区间限制
    private float spacing; // 对象间隔缓存
    private const float MOVE_DURATION = 0.3f; // 动画时长常量
    private Sequence moveSeq_ChangeChapter; // 章节切换移动补间序列表
    // ==========================================
    // 1. 初始化预处理
    // ==========================================

    /// <summary>
    /// 激活自更新
    /// 负责: 默认初始化激活冒险模式栏目
    /// </summary>
    public void OnEnable()
    {
        // 绑定数据层监听
        if (GameData.Sys_Chapter != null)
        {
            GameData.Sys_Chapter.OnChapterChangedEvent += Update_ChapterPageUI;
        }

        // 默认是冒险模式界面
        Init_ModelPage();
    }

    private void OnDisable()
    {
        // 解绑数据层监听
        if (GameData.Sys_Chapter != null)
        {
            GameData.Sys_Chapter.OnChapterChangedEvent -= Update_ChapterPageUI;
        }
    }

    /// <summary>
    /// 【核心】全模式界面装填分发
    /// 负责: 切换为预设第一冒险模式并激活UI
    /// </summary>
    private void Init_ModelPage()
    {
        OnBtn_Model_Adventure();
        Debug.Log("完成模式选择模块初始化");
    }

    /// <summary>
    /// 【核心】章节模块初级初始化渲染
    /// 负责: 1.排布所有章节预制体卡片, 2.推算总宽实现滚动边界限制, 3.处理解锁视觉封印并配置起始锚
    /// </summary>
    private void Init_ChapterPageUI()
    {
        //  计算存放章节容器前后移动的最大值和最小值
        spacing = horizontalLayoutGroup.spacing;
        minLimit = GameData.Sys_Chapter.Get_CurrentChapterDict().Count * chapterObj_prefab.GetComponent<RectTransform>().rect.width + (GameData.Sys_Chapter.Get_CurrentChapterDict().Count - 1) * spacing;
        Debug.Log(-minLimit);
        //清空子对象
        foreach (Transform child in chapterContainer.transform)
        {
            Destroy(child.gameObject);
        }
        //  初始化生成全部章节UI
        foreach (Chapter chapter in GameData.Sys_Chapter.Get_CurrentChapterDict().Values)
        {
            GameObject newChapterUI = Instantiate(chapterObj_prefab, chapterContainer.transform);
            //  判断章节是否解锁并设置对应章节图片
            if (chapter.isUnlocked == true) newChapterUI.GetComponent<Image>().sprite = chapter.SO_Chapter.chapterBG_1;
            else newChapterUI.GetComponent<Image>().sprite = chapter.SO_Chapter.chapterBG_0;
        }
        //  设置存放窗口的位置
        float anchoredX = (GameData.Sys_Chapter.currentChapterIndex - 1) * (chapterObj_prefab.GetComponent<RectTransform>().rect.width + spacing);
        Vector2 currentAnchored = chapterContainer.GetComponent<RectTransform>().anchoredPosition;  //获取原来的相对锚点位置
        currentAnchored.x = Mathf.Clamp(-anchoredX, -minLimit, 0); //保证在整个章节区间访问内
        chapterContainer.GetComponent<RectTransform>().anchoredPosition = currentAnchored;
        //  更新相关章节UI
        if (GameData.Sys_Chapter.currentChapterIndex == 1)  //第一章的情况
        {
            Btn_BeforeChapter.gameObject.SetActive(false);  //切换上一章按钮隐藏
            Btn_AfterChapter.gameObject.SetActive(true);
        }
        else if (GameData.Sys_Chapter.currentChapterIndex == GameData.Sys_Chapter.Get_CurrentChapterDict().Count)
        {
            Btn_BeforeChapter.gameObject.SetActive(true);
            Btn_AfterChapter.gameObject.SetActive(false);   //切换下一章按钮隐藏
        }
        else
        {
            Btn_BeforeChapter.gameObject.SetActive(true);
            Btn_AfterChapter.gameObject.SetActive(true);
        }
        //  章节名称
        Text_ChapterName.text = GameData.Sys_Chapter.currentChapter.SO_Chapter.chapterName;
        Text_ChapterIndex.text = "Lv." + GameData.Sys_Chapter.currentChapter.SO_Chapter.chapterIndex.ToString();
        //  更新章节页面下的确认按钮UI
        if (GameData.Sys_Chapter.currentChapter.isUnlocked == true)
        {
            Btn_ConfirmChapter.interactable = true;
            Text_ConfirmChapter.text = "选择章节";
        }
        else
        {
            Btn_ConfirmChapter.interactable = false;
            Text_ConfirmChapter.text = "未解锁";
        }
        //  章节奖励->根据章节来设置
    }

    // ==========================================
    // 2. 状态刷新重绘
    // ==========================================

    /// <summary>
    /// 翻页等局部操作的状态校准刷新
    /// 负责: 1.左右按钮边界禁灰处理, 2.触发动画平移至对应位置, 3.重写下方文案与按钮授权
    /// </summary>
    void Update_ChapterPageUI(Chapter _currentChapter)
    {
        Debug.Log("当前检视章节：" + GameData.Sys_Chapter.currentChapterIndex + " 最终选择的章节：" + GameData.Sys_Chapter.selectedChapterIndex);
        //  判断当前章节，第一章隐藏上一章按钮，最后一章隐藏下一章按钮
        if (GameData.Sys_Chapter.currentChapterIndex == 1)
        {
            Btn_BeforeChapter.gameObject.SetActive(false);
            Btn_AfterChapter.gameObject.SetActive(true);
        }
        else if (GameData.Sys_Chapter.currentChapterIndex == GameData.Sys_Chapter.Get_CurrentChapterDict().Count)
        {
            Btn_BeforeChapter.gameObject.SetActive(true);
            Btn_AfterChapter.gameObject.SetActive(false);
        }
        else
        {
            Btn_BeforeChapter.gameObject.SetActive(true);
            Btn_AfterChapter.gameObject.SetActive(true);
        }
        //  如果当前章节的索引数据变更，那么相当于位置需要变换，所以计算相对应的位置移动过去即可
        float anchoredX_TargetChapter = (GameData.Sys_Chapter.currentChapterIndex - 1) * (chapterObj_prefab.GetComponent<RectTransform>().rect.width + spacing);
        anchoredX_TargetChapter = Mathf.Clamp(-anchoredX_TargetChapter, -minLimit, 0); //保证在整个章节区间访问内
        //  更新相关章节UI
        Text_ChapterName.text = _currentChapter.SO_Chapter.chapterName;
        Text_ChapterIndex.text = "Lv." + _currentChapter.SO_Chapter.chapterIndex.ToString();
        //  更新章节页面下的确认按钮UI
        if (_currentChapter.isUnlocked == true)
        {
            Btn_ConfirmChapter.interactable = true;
            Text_ConfirmChapter.text = "选择章节";
        }
        else
        {
            Btn_ConfirmChapter.interactable = false;
            Text_ConfirmChapter.text = "未解锁";
        }
        //  打断动画
        KillSeq(moveSeq_ChangeChapter);
        //  执行动画
        Move_ChangeChapter_Seq(anchoredX_TargetChapter);
    }
    // ==========================================
    // 3. UI层动画预配组 (Animations)
    // ==========================================

    /// <summary>
    /// 移动播放执行管线
    /// 负责: DOAnchorPosX补间计算并赋予缓动曲线
    /// </summary>
    /// <param name="targetAnchoredX">目标锁定落点偏移X</param>
    private void Move_ChangeChapter_Seq(float targetAnchoredX)
    {
        moveSeq_ChangeChapter = DOTween.Sequence();
        //  移动到相对于锚点的位置
        Tween moveTween = chapterContainer.GetComponent<RectTransform>().DOAnchorPosX(targetAnchoredX, MOVE_DURATION).SetEase(Ease.OutQuad);
        moveSeq_ChangeChapter.Append(moveTween);
    }
    /// <summary>
    /// 强制中断重定向补间序列
    /// 负责: 快速拦截频繁点击的穿梭卡顿与重叠堆帧
    /// </summary>
    /// <param name="_seq">目标序列实例</param>
    private void KillSeq(Sequence _seq)
    {
        if (_seq != null && _seq.IsActive())
        {
            _seq.Kill();
        }
    }
    // ==========================================
    // 4. 用户交互接口层操作区 (Interactions)
    // ==========================================

    /// <summary>
    /// 玩家操控：确认章节
    /// 负责: 将当前检视焦点转作强制记录并更换底部背景完成跳转
    /// </summary>
    public void OnBtn_ConfirmChapter()
    {
        // 传递指令给系统执行记录
        GameData.Sys_Chapter.Confirm_ChapterSelection();

        // 修改背景图
        Home_BG.sprite = GameData.Sys_Chapter.currentChapter.SO_Chapter.chapterBG_1;
        //  关闭页面
        gameObject.SetActive(false);
        // if (GameData.currentChapter.isUnlocked == false)   //所选章节未解锁 或当前正在章节战斗状态中禁止访问
        // {
        //     //弹出提示
        //     Debug.Log("章节："+GameData.currentChapter.SO_Chapter.chapterIndex+"未解锁");
        //     return;
        // }
        // else if (GameData.currentChapter.isUnlocked == true)   //所选章节已解锁
        // {

        //     if (GameData.currentChapter.level_List.Count == 0)   //判断如果是新章节，则创建关卡路线并生成
        //     {
        //         Create_ChapterMaps(GameData.currentChapter);//创建新章节随机路线数据
        //         //  (待改进)取消章节UI在home下后与levelfighting场景融合后，这里需要去调用切换场景的方法，同时还需要把当前的chapter所挑战的章节要记录到gamedata上，让他带过去(已修改)在左右切换的时候就已经记录好当前挑战的章节
        //         //Chapter_UI.Instance.Restore_ChapterMaps(GameData.currentChapter);

        //         // Home场景切换到LevelFighting场景
        //         Loading_UIManager.Instance.OnLoadScene("LevelFighting");
        //     }
        //     else 
        //     {
        //         //(待改进) 可能需要在gamedata里新增当前挑战章节的id
        //         if (GameData.currentChapter.SO_Chapter.chapterIndex != Chapter_UI.Instance.chapterId)   //判断为关卡路线未复原则复原路线
        //         {
        //             //Chapter_UI.Instance.Restore_ChapterMaps(GameData.currentChapter);
        //             // Home场景切换到LevelFighting场景
        //             Loading_UIManager.Instance.OnLoadScene("LevelFighting");
        //         }
        //     }
        //     //Chapter_UI.Instance.OnChapterEnter();
        // }
    }
    /// <summary>
    /// 调出难度选型(预备)
    /// 负责: 扩展并抛出额外难度层级选取弹窗
    /// </summary>
    public void OnBtn_SelectDifficulty()
    {
        //  点击后弹出变更难度的UI

        //  同时再新增并实现不同难度的按钮确认点击，并把当前章节难度表变更为对应的
    }

    /// <summary>
    /// 玩家操控：向左划页(降序)
    /// 负责: 投递指令给 Sys_Chapter
    /// </summary>
    public void OnBtn_BeforeChapter()
    {
        GameData.Sys_Chapter.Turn_BeforeChapter();
    }

    /// <summary>
    /// 玩家操控：向右划页(升序)
    /// 负责: 投递指令给 Sys_Chapter
    /// </summary>
    public void OnBtn_AfterChapter()
    {
        GameData.Sys_Chapter.Turn_AfterChapter();
    }
    // ==========================================
    // 5. 跨模关联调度集成 (Cross Interactions)
    // ==========================================

    /// <summary>
    /// 关联创造新章节图扑
    /// 负责: 将随机生成委托传入 Sys_Chapter，封装对 MonoBehaviour 的依赖
    /// </summary>
    /// <param name="_chapter">操作涉及的目标章节宿主包</param>
    public void Create_ChapterMaps(Chapter _chapter)
    {
        GameData.Sys_Chapter.Create_ChapterMaps(_chapter,
            chapter => Chapter_RandomGenerateLevelMaps.Generate_RandomMaps(chapter));
    }

    // ==========================================
    // 6. 底栏切页回调 (Tab Interactions)
    // ==========================================

    /// <summary>
    /// 切入【冒险模式】页
    /// 负责: 颜色管理翻转与对应页的激活动作
    /// </summary>
    public void OnBtn_Model_Adventure()
    {
        // 更新底部栏UI-->因为其原因不好自动处理哪些按钮亮或暗，所以不能用通用的方法
        Btn_Adventure_Text.color = Btn_Light;
        Btn_PK_Text.color = Btn_Dark;
        Btn_Chess_Text.color = Btn_Dark;
        Btn_Entertainment_Text.color = Btn_Dark;
        // 激活冒险模式页面,其他页面隐藏
        Page_Chapter.SetActive(true);
        // 调用冒险模式页面的更新UI方法
        Init_ChapterPageUI();
    }
    /// <summary>
    /// 切入【PK对决】页
    /// 负责: 颜色管理翻转与对应页的激活动作
    /// </summary>
    public void OnBtn_Model_PK()
    {
        // 更新底部栏UI-->因为其原因不好自动处理哪些按钮亮或暗，所以不能用通用的方法
        Btn_Adventure_Text.color = Btn_Dark;
        Btn_PK_Text.color = Btn_Light;
        Btn_Chess_Text.color = Btn_Dark;
        Btn_Entertainment_Text.color = Btn_Dark;
        // 激活冒险模式页面
        Page_Chapter.SetActive(false);
        // 调用冒险模式页面的初始化方法
    }
    /// <summary>
    /// 切入【战棋推演】页
    /// 负责: 颜色管理翻转与对应页的激活动作
    /// </summary>
    public void OnBtn_Model_Chess()
    {
        // 更新底部栏UI-->因为其原因不好自动处理哪些按钮亮或暗，所以不能用通用的方法
        Btn_Adventure_Text.color = Btn_Dark;
        Btn_PK_Text.color = Btn_Dark;
        Btn_Chess_Text.color = Btn_Light;
        Btn_Entertainment_Text.color = Btn_Dark;
        // 激活冒险模式页面
        Page_Chapter.SetActive(false);
        // 调用冒险模式页面的初始化方法
    }
    /// <summary>
    /// 切入【娱乐派对】页
    /// 负责: 颜色管理翻转与对应页的激活动作
    /// </summary>
    public void OnBtn_Model_Entertainment()
    {
        // 更新底部栏UI-->因为其原因不好自动处理哪些按钮亮或暗，所以不能用通用的方法
        Btn_Adventure_Text.color = Btn_Dark;
        Btn_PK_Text.color = Btn_Dark;
        Btn_Chess_Text.color = Btn_Dark;
        Btn_Entertainment_Text.color = Btn_Light;
        // 激活冒险模式页面
        Page_Chapter.SetActive(false);
        // 调用冒险模式页面的初始化方法
    }
}
