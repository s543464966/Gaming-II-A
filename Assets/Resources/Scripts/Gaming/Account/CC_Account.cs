using System.Threading.Tasks;
using TMPro;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.Serialization;
using UnityEngine.UI;

public class CC_Account : MonoBehaviour
{
    //====== 账号输入 ======//
    [Header("模块: 账号输入")]
    [FormerlySerializedAs("phoneInput")]
    [Tooltip("账号输入框")] public TMP_InputField accountIdInput; // 账号输入框
    [Tooltip("密码输入框")] public TMP_InputField passwordInput; // 密码输入框
    [Tooltip("验证码输入框")] public TMP_InputField verifyCodeInput; // 验证码输入框
    [Tooltip("状态提示文本")] public TMP_Text statusText; // 状态提示文本
    [Tooltip("当前账号文本")] public TMP_Text currentUserText; // 当前账号文本
    [Tooltip("账号窗口标题文本")] public TMP_Text authModeText; // 账号窗口标题文本

    //====== 账号页面 ======//
    [Header("模块: 账号页面")]
    [Tooltip("账号窗口")] public GameObject authWindowPanel; // 登录,注册,重置密码共用窗口
    [Tooltip("登录场景主界面")] public GameObject mainPanel; // 登录场景主界面

    //====== 账号按钮 ======//
    [Header("模块: 账号按钮")]
    [Tooltip("发送验证码按钮")] public Button sendVerifyCodeButton; // 发送验证码按钮
    [Tooltip("账号确认按钮")] public Button confirmAuthButton; // 当前账号动作确认按钮
    [Tooltip("登录注册切换按钮")] public Button switchAuthModeButton; // 登录注册模式切换按钮
    [Tooltip("打开重置密码按钮")] public Button openResetPasswordButton; // 打开重置密码按钮
    [Tooltip("进入游戏按钮")] public Button enterGameButton; // 进入游戏按钮
    [FormerlySerializedAs("logoutButton")]
    [Tooltip("注销登录按钮")] public Button signOutButton; // 注销登录按钮
    [Tooltip("删除账号按钮")] public Button deleteAccountButton; // 删除当前账号按钮
    [Tooltip("关闭账号窗口按钮")] public Button closeAuthWindowButton; // 关闭账号窗口按钮

    // --- 内部状态 --- //
    DBCC_DataBase dataBase; // 数据库单例引用
    Sys_Auth sysAuth; // 本地认证系统引用
    AccountWindowMode_Auth currentWindowMode = AccountWindowMode_Auth.Login; // 当前账号窗口模式
    bool isInitialized; // 是否已完成初始化
    bool isAuthWindowOpen; // 账号窗口是否打开

    // ==========================================
    // 1. 初始化
    // ==========================================

    /// <summary>
    /// 在所有场景单例完成 Awake 后再初始化账号界面。
    /// </summary>
    void Start()
    {
        Init_Account();
    }

    /// <summary>
    /// 初始化账号页面控制器, 并绑定认证系统事件。
    /// </summary>
    public void Init_Account()
    {
        if (isInitialized)
        {
            // 已初始化时仅刷新界面, 避免重复绑定事件。
            Refresh_View_Account();
            Set_Interactable_Account(true);
            Refresh_StatusText_Account();
            // LoadScene 被重复加载或对象复用时, 刷新完成即可通知加载页关闭。
            Notify_SceneReady_Account();
            return;
        }

        // 先获取全局数据库与认证系统引用。
        dataBase = DBCC_DataBase.Instance;
        if (dataBase == null)
        {
            Debug.LogWarning("[CC_Account] DBCC_DataBase instance is missing.");
            // 即使关键单例缺失也要通知 ready, 避免 Loading_UIManager 一直等待。
            Notify_SceneReady_Account();
            return;
        }

        sysAuth = dataBase.Sys_Auth;
        if (sysAuth == null)
        {
            Debug.LogWarning("[CC_Account] Sys_Auth is missing.");
            // 认证系统缺失时界面无法继续初始化, 但加载页仍需要安全退出。
            Notify_SceneReady_Account();
            return;
        }

        // 先绑定认证事件, 让界面能跟随认证状态变化自动刷新。
        sysAuth.OnAuthStateChanged += Handle_AuthStateChanged_Account;
        sysAuth.OnAuthMessageChanged += Handle_AuthMessageChanged_Account;
        isInitialized = true;

        // 初始化时清理编辑器残留输入, 并让验证码控件由当前模式统一控制显隐。
        Clear_InputFields_Account();
        Refresh_View_Account();
        Set_Interactable_Account(true);
        Refresh_StatusText_Account();

        // 登录入口场景每次显示时都检查自动登录, 成功后只展示主界面按钮, 不自动进入主页。
        if (SceneManager.GetActiveScene().name != "Home")
        {
            // LoadScene 的 ready 标记放在自动登录检查之后, 避免玩家看到 UI 状态跳变。
            _ = Try_AutoLogin_Account();
        }
    }

    /// <summary>
    /// 销毁时解绑认证事件。
    /// </summary>
    void OnDestroy()
    {
        if (sysAuth != null)
        {
            sysAuth.OnAuthStateChanged -= Handle_AuthStateChanged_Account;
            sysAuth.OnAuthMessageChanged -= Handle_AuthMessageChanged_Account;
        }
    }

    // ==========================================
    // 2. 界面事件
    // ==========================================

    /// <summary>
    /// 按当前账号窗口模式执行登录, 注册或重置密码。
    /// </summary>
    public async void OnBtn_ConfirmAuth_Account()
    {
        switch (currentWindowMode)
        {
            case AccountWindowMode_Auth.Register:
                await Request_Register_Account();
                break;
            case AccountWindowMode_Auth.ResetPassword:
                await Request_ResetPassword_Account();
                break;
            default:
                await Request_Login_Account();
                break;
        }
    }

    /// <summary>
    /// 在账号窗口模式之间切换。
    /// </summary>
    public void OnBtn_SwitchAuthMode_Account()
    {
        // 切换模式前清理输入, 避免登录,注册,重置密码之间复用旧输入内容。
        Clear_InputFields_Account();
        var nextWindowMode = currentWindowMode == AccountWindowMode_Auth.Login
            ? AccountWindowMode_Auth.Register
            : AccountWindowMode_Auth.Login;
        Set_AuthWindowMode_Account(nextWindowMode);
    }

    /// <summary>
    /// 打开重置密码窗口模式。
    /// </summary>
    public void OnBtn_OpenResetPassword_Account()
    {
        Clear_InputFields_Account();
        Set_AuthWindowMode_Account(AccountWindowMode_Auth.ResetPassword);
    }

    /// <summary>
    /// 【核心】按当前账号窗口模式发送验证码。
    /// </summary>
    public async void OnBtn_SendVerifyCode_Account()
    {
        if (sysAuth == null)
        {
            return;
        }

        if (currentWindowMode != AccountWindowMode_Auth.Register &&
            currentWindowMode != AccountWindowMode_Auth.ResetPassword)
        {
            return;
        }

        // 验证码发送会模拟1-5秒时延, 期间先锁定按钮防止重复发送。
        Set_Interactable_Account(false);
        // 如果当前窗口状态是注册, 就发送注册验证码; 如果是重置密码, 就发送重置验证码。
        var result = currentWindowMode == AccountWindowMode_Auth.Register
            ? await sysAuth.Send_RegisterCode_Auth(GetAccountId_Account())
            : await sysAuth.Send_ResetPasswordCode_Auth(GetAccountId_Account());
        Set_Interactable_Account(true);
        Refresh_View_Account();
        Refresh_StatusText_Account(result?.Message);
    }

    /// <summary>
    /// 关闭当前账号窗口。
    /// </summary>
    public void OnBtn_CloseAuthWindow_Account()
    {
        Clear_InputFields_Account();
        isAuthWindowOpen = false;
        currentWindowMode = AccountWindowMode_Auth.Login;
        Refresh_View_Account();
        Set_Interactable_Account(true);
    }

    /// <summary>
    /// 请求注销当前登录态。
    /// </summary>
    public async void OnBtn_SignOut_Account()
    {
        if (sysAuth == null || dataBase == null)
        {
            return;
        }

        // 注销只清理登录态和登录框残留数据以及当前账号数据, 不重新加载登录场景。
        Set_Interactable_Account(false);
        dataBase.Close_CurrentUserData_DB();
        await sysAuth.Logout_Account_Auth();
        Clear_InputFields_Account();
        isAuthWindowOpen = false;
        currentWindowMode = AccountWindowMode_Auth.Login;
        Set_Interactable_Account(true);
        Refresh_View_Account();
        Refresh_StatusText_Account();
    }

    /// <summary>
    /// 【核心】删除当前已登录账号与它对应的本地存档。
    /// </summary>
    public async void OnBtn_DeleteAccount_Account()
    {
        if (sysAuth == null || dataBase == null)
        {
            return;
        }

        // 删除账号不会保存当前账号数据, 防止即将删除的存档被重新写回。
        Set_Interactable_Account(false);
        var result = await sysAuth.Delete_CurrentAccount_Auth();
        if (result.Success)
        {
            var isSaveDeleted = dataBase.Delete_UserData_DB(result.UserId, result.SaveFileName);
            if (!isSaveDeleted)
            {
                Refresh_StatusText_Account("账号已删除, 但存档文件删除失败。");
                Set_Interactable_Account(true);
                Refresh_View_Account();
                return;
            }
            // 提示账号删除成功.
            Debug.LogWarning($"{result.AccountId}账号删除成功");
            isAuthWindowOpen = false;
            currentWindowMode = AccountWindowMode_Auth.Login;
            Clear_InputFields_Account();
        }

        Set_Interactable_Account(true);
        Refresh_View_Account();
        Refresh_StatusText_Account(result.Message);
    }

    /// <summary>
    /// 当前已登录状态后手动点击进入主页。
    /// </summary>
    public void OnBtn_EnterHome_Account()
    {
        if (sysAuth == null || dataBase == null)
        {
            return;
        }

        if (!sysAuth.IsLoggedIn)
        {
            Set_AuthWindowMode_Account(AccountWindowMode_Auth.Login);
            Refresh_StatusText_Account("请先登录账号。");
            return;
        }

        // 进入主页前确保当前账号数据已由数据库准备好。
        if (!dataBase.Ensure_UserDataLoaded_DB(sysAuth.CurrentUserId, null))
        {
            Refresh_StatusText_Account("账号数据加载失败。");
            return;
        }

        if (SceneManager.GetActiveScene().name == "Home")
        {
            return;
        }

        if (Loading_UIManager.Instance == null)
        {
            Debug.LogWarning("[CC_Account] Loading_UIManager instance is missing.");
            return;
        }

        // Home 场景需要等待 CC_Home.Awake 同步完成首屏初始化后再关闭加载页。
        Loading_UIManager.Instance.OnLoadScene("Home", true);
    }

    // ==========================================
    // 3. 内部方法
    // ==========================================

    /// <summary>
    /// 【核心】尝试恢复本地自动登录状态。
    /// 流程: 1.检查会话有效性, 2.加载账号存档, 3.成功后停留在主界面等待玩家手动进入游戏。
    /// </summary>
    /// <returns>返回异步任务。</returns>
    async Task Try_AutoLogin_Account()
    {
        if (sysAuth == null || dataBase == null)
        {
            // 自动登录流程无法执行时, 直接释放等待中的加载页。
            Notify_SceneReady_Account();
            return;
        }

        // 自动登录阶段同样先锁定按钮, 避免用户在恢复流程中再次点击。
        var hadCurrentUserData = dataBase.Has_CurrentUserData_DB();
        Set_Interactable_Account(false);
        var result = await sysAuth.Check_AutoLogin_Auth();
        await Handle_LoginResult_Account(result);
        if (!result.Success && hadCurrentUserData && !sysAuth.IsLoggedIn)
        {
            dataBase.Close_CurrentUserData_DB();
        }

        Set_Interactable_Account(true);
        Refresh_View_Account();
        Refresh_StatusText_Account();
        // 自动登录成功或失败后, 登录入口 UI 已经稳定, 可以关闭加载页。
        Notify_SceneReady_Account();
    }

    /// <summary>
    /// 统一处理认证成功后的存档装载。
    /// </summary>
    /// <param name="result">认证结果。</param>
    /// <returns>返回异步任务。</returns>
    async Task Handle_LoginResult_Account(LocalAuthResult_Auth result)
    {
        if (result == null || !result.Success)
        {
            return;
        }

        // 认证成功后只装载账号数据并刷新主界面, 不自动进入主页。
        if (!dataBase.Open_AuthenticatedUserData_DB(result))
        {
            await sysAuth.Logout_Account_Auth();
            dataBase.Clear_CurrentUserData_DB();
            isAuthWindowOpen = true;
            return;
        }

        isAuthWindowOpen = false;
        currentWindowMode = AccountWindowMode_Auth.Login;
        Refresh_View_Account();
        Refresh_StatusText_Account();
    }

    /// <summary>
    /// 请求执行本地账号密码登录。
    /// </summary>
    /// <returns>返回异步任务。</returns>
    async Task Request_Login_Account()
    {
        if (sysAuth == null || dataBase == null)
        {
            return;
        }

        // 先禁用按钮, 防止重复点击触发多次登录。
        Set_Interactable_Account(false);
        var result = await sysAuth.Login_Password_Auth(GetAccountId_Account(), GetPassword_Account());
        await Handle_LoginResult_Account(result);

        Set_Interactable_Account(true);
        Refresh_View_Account();
        Refresh_StatusText_Account();
    }

    /// <summary>
    /// 请求完成本地账号注册流程。
    /// </summary>
    /// <returns>返回异步任务。</returns>
    async Task Request_Register_Account()
    {
        if (sysAuth == null || dataBase == null)
        {
            return;
        }

        // 先禁用按钮, 防止重复点击触发多次注册。
        Set_Interactable_Account(false);
        var result = await sysAuth.Register_Account_Auth(GetAccountId_Account(), GetPassword_Account(), GetVerifyCode_Account());
        await Handle_LoginResult_Account(result);

        Set_Interactable_Account(true);
        Refresh_View_Account();
        Refresh_StatusText_Account();
    }

    /// <summary>
    /// 请求使用验证码重置本地账号密码。
    /// </summary>
    /// <returns>返回异步任务。</returns>
    async Task Request_ResetPassword_Account()
    {
        if (sysAuth == null)
        {
            return;
        }

        // 重置密码不会自动登录, 成功后切回登录模式等待玩家重新登录。
        Set_Interactable_Account(false);
        var result = await sysAuth.Reset_Password_Auth(GetAccountId_Account(), GetVerifyCode_Account(), GetPassword_Account());
        if (result.Success)
        {
            Clear_InputFields_Account();
            currentWindowMode = AccountWindowMode_Auth.Login;
        }

        Set_Interactable_Account(true);
        Refresh_View_Account();
        Refresh_StatusText_Account(result.Message);
    }

    /// <summary>
    /// 清理编辑器开发阶段残留的输入框内容。
    /// </summary>
    void Clear_InputFields_Account()
    {
        if (accountIdInput != null)
        {
            accountIdInput.SetTextWithoutNotify(string.Empty);
        }

        if (passwordInput != null)
        {
            passwordInput.SetTextWithoutNotify(string.Empty);
        }

        if (verifyCodeInput != null)
        {
            verifyCodeInput.SetTextWithoutNotify(string.Empty);
        }
    }

    /// <summary>
    /// 处理认证状态变化后的界面刷新。
    /// </summary>
    /// <param name="isLoggedIn">是否已登录。</param>
    void Handle_AuthStateChanged_Account(bool isLoggedIn)
    {
        Refresh_View_Account();
    }

    /// <summary>
    /// 处理认证提示消息变化。
    /// </summary>
    /// <param name="message">最新提示消息。</param>
    void Handle_AuthMessageChanged_Account(string message)
    {
        Refresh_StatusText_Account(message);
    }

    /// <summary>
    /// 根据当前认证状态和账号窗口模式刷新页面显示。
    /// </summary>
    void Refresh_View_Account()
    {
        var isLoggedIn = sysAuth != null && sysAuth.IsLoggedIn;
        var isResetPasswordMode = currentWindowMode == AccountWindowMode_Auth.ResetPassword;
        var isRegisterMode = currentWindowMode == AccountWindowMode_Auth.Register;
        var isLoginMode = currentWindowMode == AccountWindowMode_Auth.Login;
        var isVerifyCodeMode = isRegisterMode || isResetPasswordMode;   // 当前窗口是注册还是重置密码模式
        var showAuthWindow = !isLoggedIn && isAuthWindowOpen;   // 是否已经登录或者登录窗口打开

        // 主界面作为登录场景背景存在, 不再只代表已登录状态。
        if (mainPanel != null)
        {
            mainPanel.SetActive(true);
        }

        if (authWindowPanel != null)
        {
            authWindowPanel.SetActive(showAuthWindow);
        }

        // 验证码控件只在注册和重置密码窗口内显示。
        if (verifyCodeInput != null)
        {
            verifyCodeInput.gameObject.SetActive(showAuthWindow && isVerifyCodeMode);
        }

        if (sendVerifyCodeButton != null)
        {
            sendVerifyCodeButton.gameObject.SetActive(showAuthWindow && isVerifyCodeMode);
        }

        if (openResetPasswordButton != null)
        {
            openResetPasswordButton.gameObject.SetActive(showAuthWindow && isLoginMode);
        }

        if (currentUserText != null)
        {
            currentUserText.text = isLoggedIn
                ? $"当前账号: {sysAuth.CurrentAccountId}"
                : "当前账号: 未登录";
        }

        Refresh_LogoutButtonText_Account();
        Refresh_AuthModeText_Account();
        Refresh_ButtonVisible_Account();
    }

    /// <summary>
    /// 通知加载控制器当前登录入口场景已经完成初始化。
    /// 这个方法只表达 LoadScene 可展示, 不负责改变认证状态。
    /// </summary>
    void Notify_SceneReady_Account()
    {
        if (Loading_UIManager.Instance != null)
        {
            Loading_UIManager.Instance.Notify_SceneReady_Loading();
        }
    }

    /// <summary>
    /// 刷新状态提示文本。
    /// </summary>
    /// <param name="message">可选的最新提示消息。</param>
    void Refresh_StatusText_Account(string message = null)
    {
        if (statusText == null)
        {
            return;
        }

        statusText.text = string.IsNullOrWhiteSpace(message)
            ? sysAuth?.LastMessage
            : message;
    }

    /// <summary>
    /// 控制账号窗口模式切换。
    /// </summary>
    /// <param name="windowMode">目标账号窗口模式。</param>
    void Set_AuthWindowMode_Account(AccountWindowMode_Auth windowMode)
    {
        currentWindowMode = windowMode;

        // 已登录时不显示账号窗口, 防止已登录状态下误操作登录或重置密码。
        if (sysAuth != null && sysAuth.IsLoggedIn)
        {
            isAuthWindowOpen = false;
            Refresh_View_Account();
            Set_Interactable_Account(true);
            return;
        }

        // 未登录时打开账号窗口, 并交给枚举状态决定显示登录,注册或重置密码内容。
        isAuthWindowOpen = true;
        Refresh_View_Account();
        Set_Interactable_Account(true);
    }

    /// <summary>
    /// 统一切换账号按钮可交互状态, 防止重复点击。
    /// </summary>
    /// <param name="isInteractable">是否允许交互。</param>
    void Set_Interactable_Account(bool isInteractable)
    {
        var isLoggedIn = sysAuth != null && sysAuth.IsLoggedIn;
        var isVerifyCodeMode = currentWindowMode == AccountWindowMode_Auth.Register ||
                               currentWindowMode == AccountWindowMode_Auth.ResetPassword;

        if (sendVerifyCodeButton != null)
        {
            sendVerifyCodeButton.interactable = isInteractable && !isLoggedIn && isAuthWindowOpen && isVerifyCodeMode;
        }

        if (confirmAuthButton != null)
        {
            confirmAuthButton.interactable = isInteractable && !isLoggedIn && isAuthWindowOpen;
        }

        if (switchAuthModeButton != null)
        {
            switchAuthModeButton.interactable = isInteractable && !isLoggedIn && isAuthWindowOpen;
        }

        if (openResetPasswordButton != null)
        {
            openResetPasswordButton.interactable = isInteractable && !isLoggedIn && isAuthWindowOpen;
        }

        if (closeAuthWindowButton != null)
        {
            closeAuthWindowButton.interactable = isInteractable && !isLoggedIn && isAuthWindowOpen;
        }

        if (enterGameButton != null)
        {
            enterGameButton.interactable = isInteractable;
        }

        if (signOutButton != null)
        {
            signOutButton.interactable = isInteractable && isLoggedIn;
        }

        if (deleteAccountButton != null)
        {
            deleteAccountButton.interactable = isInteractable && isLoggedIn;
        }
    }

    /// <summary>
    /// 同步注销按钮显示文本。
    /// </summary>
    void Refresh_LogoutButtonText_Account()
    {
        Set_ButtonText_Account(signOutButton, "注销");
        Set_ButtonText_Account(deleteAccountButton, "删除账号");
    }

    /// <summary>
    /// 同步账号窗口按钮和标题显示文本。
    /// </summary>
    void Refresh_AuthModeText_Account()
    {
        switch (currentWindowMode)
        {
            case AccountWindowMode_Auth.Register:
                Set_AuthWindowText_Account("注册账号", "注册", "去登录");
                Set_ButtonText_Account(sendVerifyCodeButton, "发送验证码");
                break;
            case AccountWindowMode_Auth.ResetPassword:
                Set_AuthWindowText_Account("重置密码", "重置", "去登录");
                Set_ButtonText_Account(sendVerifyCodeButton, "发送验证码");
                break;
            default:
                Set_AuthWindowText_Account("登录账号", "登录", "去注册");
                break;
        }
    }

    /// <summary>
    /// 同步账号窗口标题与主按钮文本。
    /// </summary>
    /// <param name="titleText">标题文本。</param>
    /// <param name="confirmText">确认按钮文本。</param>
    /// <param name="switchText">切换按钮文本。</param>
    void Set_AuthWindowText_Account(string titleText, string confirmText, string switchText)
    {
        if (authModeText != null)
        {
            authModeText.text = titleText;
        }

        Set_ButtonText_Account(confirmAuthButton, confirmText);
        Set_ButtonText_Account(switchAuthModeButton, switchText);
    }

    /// <summary>
    /// 同步主界面按钮显隐。
    /// </summary>
    void Refresh_ButtonVisible_Account()
    {
        var isLoggedIn = sysAuth != null && sysAuth.IsLoggedIn;

        if (enterGameButton != null)
        {
            enterGameButton.gameObject.SetActive(true);
        }

        if (signOutButton != null)
        {
            signOutButton.gameObject.SetActive(isLoggedIn);
        }

        if (deleteAccountButton != null)
        {
            deleteAccountButton.gameObject.SetActive(isLoggedIn);
        }
    }

    /// <summary>
    /// 设置按钮子文本。
    /// </summary>
    /// <param name="button">目标按钮。</param>
    /// <param name="text">按钮显示文本。</param>
    void Set_ButtonText_Account(Button button, string text)
    {
        if (button == null)
        {
            return;
        }

        var buttonText = button.GetComponentInChildren<TMP_Text>();
        if (buttonText != null)
        {
            buttonText.text = text;
        }
    }

    /// <summary>
    /// 读取当前账号输入内容。
    /// </summary>
    /// <returns>返回去除首尾空格后的账号字符串。</returns>
    string GetAccountId_Account() => accountIdInput != null ? accountIdInput.text.Trim() : string.Empty;

    /// <summary>
    /// 读取当前密码输入内容。
    /// </summary>
    /// <returns>返回密码字符串。</returns>
    string GetPassword_Account() => passwordInput != null ? passwordInput.text : string.Empty;

    /// <summary>
    /// 读取当前验证码输入内容。
    /// </summary>
    /// <returns>返回验证码字符串。</returns>
    string GetVerifyCode_Account() => verifyCodeInput != null ? verifyCodeInput.text.Trim() : string.Empty;
}
