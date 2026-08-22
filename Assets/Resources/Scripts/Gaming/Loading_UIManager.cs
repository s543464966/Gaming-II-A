using System.Collections;
using TMPro;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public class Loading_UIManager : MonoBehaviour
{
    // 三段式加载进度: 0-80% 给 Unity 场景加载, 80-95% 给目标场景初始化, 95-100% 给关闭前收尾。
    const float SceneLoadProgressMax = 0.8f; // 场景异步加载阶段最大进度
    const float WaitSceneReadyProgressMax = 0.95f; // 等待目标场景初始化阶段最大进度
    const float CompleteProgress = 1f; // 加载完成进度
    const float ProgressSmoothSpeed = 2.5f; // 进度条平滑速度
    const float MinDisplayTime = 0.6f; // 加载页最短显示时间
    const float MaxWaitSceneReadyTime = 10f; // 等待目标场景通知的最大时长
    const int LoadingTopSortingOrder = 100; // 加载页顶层排序值

    //====== 异步加载 ======//
    [Header("模块: 异步加载")]
    [Tooltip("加载进度文本")] public TMP_Text currentLoading_Text; // 加载进度文本
    [Tooltip("加载进度条")] public Slider slider; // 加载进度条
    [Tooltip("加载背景节点")] public GameObject loadingBG; // 加载背景节点

    // --- 内部状态 ---
    Canvas selfCanvas; // 自身画布
    Canvas loadingBgCanvas; // 背景画布
    int initLoadUISortingOrder; // 初始排序层级
    bool isLoading; // 是否正在加载场景
    bool waitForSceneReady; // 是否等待目标场景主动通知
    bool isSceneLoaded; // 目标场景是否已加载完成
    bool isSceneReady; // 目标场景业务初始化是否已完成
    float loadingStartTime; // 加载开始时间
    float sceneLoadedTime; // 场景加载完成时间
    float currentDisplayProgress; // 当前显示进度
    float targetDisplayProgress; // 目标显示进度

    [Tooltip("单例实例")] public static Loading_UIManager Instance { get; private set; } // 单例实例

    // ==========================================
    // 1. Lifecycle
    // ==========================================

    /// <summary>
    /// 初始化跨场景加载控制器单例与画布引用。
    /// </summary>
    void Awake()
    {
        if (Instance == null)
        {
            // 首个加载控制器实例负责缓存画布层级, 并跨场景保留。
            selfCanvas = GetComponent<Canvas>();
            if (currentLoading_Text != null)
            {
                // 清理编辑器或上一次运行残留文本, 避免进入游戏时显示旧进度。
                currentLoading_Text.text = null;
            }

            // 加载开始时会临时抬高层级, 这里记录原始层级用于加载结束后恢复。
            initLoadUISortingOrder = selfCanvas != null ? selfCanvas.sortingOrder : 0;
            // loadingBG 可能是独立背景节点, 需要单独缓存 Canvas 才能同步提高层级。
            loadingBgCanvas = loadingBG != null ? loadingBG.GetComponent<Canvas>() : null;
            Instance = this;

            // 加载页必须跨场景存在, 否则切场景时自身会被卸载导致加载动画中断。
            if (loadingBG != null)
            {
                // 背景节点如果独立在层级中, 也需要一起跨场景保留。
                DontDestroyOnLoad(loadingBG);
            }
            DontDestroyOnLoad(gameObject);
        }
        else
        {
            // 场景中重复出现加载控制器时销毁新实例, 保留最早创建的全局实例。
            Destroy(gameObject);
            if (loadingBG != null)
            {
                // 重复实例自带的背景也要销毁, 防止场景中残留多份 loading 背景。
                Destroy(loadingBG);
            }
        }
    }

    // ==========================================
    // 2. Loading Flow
    // ==========================================

    /// <summary>
    /// 加载指定场景并显示统一加载页, 默认只等待 Unity 场景加载完成。
    /// </summary>
    /// <param name="_sceneName">目标场景名。</param>
    public void OnLoadScene(string _sceneName)
    {
        // 普通场景不需要额外等待业务初始化, 例如战斗场景或轻量场景。
        OnLoadScene(_sceneName, false);
    }

    /// <summary>
    /// 【核心】加载指定场景并按需等待目标场景完成业务初始化后回调。
    /// 流程: 1.校验请求, 2.初始化加载状态, 3.显示加载页, 4.启动异步加载协程。
    /// </summary>
    /// <param name="_sceneName">目标场景名。</param>
    /// <param name="_waitForSceneReady">是否等待目标场景主动通知初始化完成。</param>
    public void OnLoadScene(string _sceneName, bool _waitForSceneReady)
    {
        if (string.IsNullOrWhiteSpace(_sceneName))
        {
            Debug.LogWarning("[Loading_UIManager] 目标场景名为空。");
            return;
        }

        if (isLoading)
        {
            // 加载流程必须单线执行, 避免多个 LoadSceneAsync 同时切换导致状态错乱。
            Debug.LogWarning($"[Loading_UIManager] 正在加载场景, 已忽略新的加载请求: {_sceneName}");
            return;
        }

        // 初始化加载页状态数据。
        Init_LoadingState(_waitForSceneReady);
        // 展示加载页UI并启动加载协程。
        Show_LoadingUI();
        StartCoroutine(AsyncOnLoadScene(_sceneName));
    }

    /// <summary>
    /// 目标场景入口脚本通知加载器: 当前场景已经完成可展示前的初始化。
    /// </summary>
    public void Notify_SceneReady_Loading()
    {
        // 普通加载模式不等待 ready, 因此外部误调用时直接忽略即可。
        if (!isLoading || !waitForSceneReady)
        {
            return;
        }

        //  场景入口脚本已经完成初始化
        isSceneReady = true;
    }

    /// <summary>
    /// 【核心】轮询异步加载进度, 并在满足关闭条件后恢复加载页状态。
    /// </summary>
    /// <param name="_sceneName">目标场景名。</param>
    /// <returns>协程枚举器。</returns>
    IEnumerator AsyncOnLoadScene(string _sceneName)
    {
        var operation = SceneManager.LoadSceneAsync(_sceneName);
        if (operation == null)
        {
            Debug.LogWarning($"[Loading_UIManager] 无法加载场景: {_sceneName}");
            Hide_LoadingUI();
            yield break;
        }
        
        // 第一阶段: Unity 场景异步加载真实进度只映射到前80%。
        while (!operation.isDone)
        {
            // 更新当前进度数据。
            targetDisplayProgress = Mathf.Clamp01(operation.progress / 0.9f) * SceneLoadProgressMax;
            Update_DisplayProgress();
            yield return null;
        }

        // 场景加载完成后, Awake/OnEnable 已经进入执行链路, 但业务初始化是否完成由目标场景入口脚本决定。
        isSceneLoaded = true;
        sceneLoadedTime = Time.unscaledTime;    //记录场景加载完成时间。
        if (!waitForSceneReady)
        {
            // 普通模式不等待业务 ready, 直接允许进入收尾阶段。
            isSceneReady = true;
        }

        // 第二阶段等待 ready, 第三阶段 ready 后推进到100%, 直到满足关闭条件。
        while (!Check_CanCloseLoading())
        {
            Check_WaitSceneReadyState();
            Update_TargetProgress();
            Update_DisplayProgress();
            yield return null;
        }

        Hide_LoadingUI();
    }

    /// <summary>
    /// 初始化本次加载状态。
    /// </summary>
    /// <param name="isWaitForSceneReady">是否等待目标场景通知。</param>
    void Init_LoadingState(bool isWaitForSceneReady)
    {
        // 每次加载都重置状态, 避免上一次场景切换残留进度或 ready 标记。
        isLoading = true;
        waitForSceneReady = isWaitForSceneReady;
        isSceneLoaded = false;
        isSceneReady = false;
        loadingStartTime = Time.unscaledTime;   //记录加载开始时间。
        sceneLoadedTime = 0f;
        currentDisplayProgress = 0f;
        targetDisplayProgress = 0f;
    }

    /// <summary>
    /// 显示加载页并重置 UI。
    /// </summary>
    void Show_LoadingUI()
    {
        if (loadingBG != null)
        {
            loadingBG.SetActive(true);
        }
        gameObject.SetActive(true);

        // 背景和加载页的 UI 确保在顶层。
        if (selfCanvas != null)
        {
            selfCanvas.sortingOrder = LoadingTopSortingOrder;
        }

        if (loadingBgCanvas != null)
        {
            loadingBgCanvas.sortingOrder = LoadingTopSortingOrder - 1; // 背景层级比加载页低, 避免遮挡进度文本。
        }

        Update_LoadingUI(0f);
    }

    /// <summary>
    /// 按当前加载状态更新目标进度。
    /// </summary>
    void Update_TargetProgress()
    {
        if (!isSceneLoaded)
        {
            return;
        }

        // 等待 ready 时最多推进到95%, 让玩家知道场景已加载但还在做入口初始化。
        targetDisplayProgress = waitForSceneReady && !isSceneReady
            ? WaitSceneReadyProgressMax
            : CompleteProgress;
    }

    /// <summary>
    /// 检查等待目标场景通知是否超时。
    /// </summary>
    void Check_WaitSceneReadyState()
    {
        // 是否需要等待场景 ready。
        if (!waitForSceneReady || isSceneReady)
        {
            return;
        }

        // 兜底保护: 目标场景忘记通知 ready 时也不能让加载页永久停住。
        if (sceneLoadedTime > 0f && Time.unscaledTime - sceneLoadedTime >= MaxWaitSceneReadyTime)
        {
            Debug.LogWarning("[Loading_UIManager] 等待场景初始化超时, 自动关闭加载页。");
            isSceneReady = true;
        }
    }

    /// <summary>
    /// 根据当前进度数据平滑推进当前显示进度。
    /// </summary>
    void Update_DisplayProgress()
    {
        currentDisplayProgress = Mathf.MoveTowards(
            currentDisplayProgress,
            targetDisplayProgress,
            ProgressSmoothSpeed * Time.unscaledDeltaTime);

        Update_LoadingUI(currentDisplayProgress);
    }

    /// <summary>
    /// 刷新加载 UI 进度显示。
    /// </summary>
    /// <param name="progress">当前进度。</param>
    void Update_LoadingUI(float progress)
    {
        var normalizedProgress = Mathf.Clamp01(progress);
        if (slider != null)
        {
            slider.value = normalizedProgress;
        }

        if (currentLoading_Text != null)
        {
            currentLoading_Text.text = Mathf.FloorToInt(normalizedProgress * 100f) + "%";
        }
    }

    /// <summary>
    /// 判断当前加载页是否可以关闭。
    /// </summary>
    /// <returns>返回是否可以关闭加载页。</returns>
    bool Check_CanCloseLoading()
    {
        // 关闭前同时满足: 场景加载完成, 业务 ready, 最短显示时间完成, 视觉进度接近100%。
        return isSceneLoaded &&
               isSceneReady &&
               Time.unscaledTime - loadingStartTime >= MinDisplayTime &&
               currentDisplayProgress >= 0.99f;
    }

    /// <summary>
    /// 隐藏加载页并恢复 UI 状态。
    /// </summary>
    void Hide_LoadingUI()
    {
        // 关闭时清空进度, 下次显示从0开始。
        Update_LoadingUI(0f);

        if (loadingBgCanvas != null)
        {
            loadingBgCanvas.sortingOrder = initLoadUISortingOrder;
        }

        if (selfCanvas != null)
        {
            selfCanvas.sortingOrder = initLoadUISortingOrder;
        }

        if (currentLoading_Text != null)
        {
            currentLoading_Text.text = null;
        }

        // 加载器本体和背景都进入隐藏状态, 但对象仍通过 DontDestroyOnLoad 保留。
        if (loadingBG != null)
        {
            loadingBG.SetActive(false);
        }
        gameObject.SetActive(false);

        // 重置运行时标记, 允许下一次场景切换。
        isLoading = false;
        waitForSceneReady = false;
        isSceneLoaded = false;
        isSceneReady = false;
    }
}
