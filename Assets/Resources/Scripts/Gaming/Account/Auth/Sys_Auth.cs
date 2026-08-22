using System;
using System.Collections.Generic;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;
using UnityEngine;

/// <summary>
/// 负责本地单机版账号认证流程。
/// 包含: 账号注册, 密码登录, 自动登录与会话持久化。
/// </summary>
public class Sys_Auth
{
    const int AutoLoginHours = 24; // 自动登录有效时长, 单位为小时
    const int VerifyCodeMinutes = 1; // 验证码有效分钟数
    const string RegisterVerifyPurpose = "Register"; // 注册验证码用途
    const string ResetPasswordVerifyPurpose = "ResetPassword"; // 重置密码验证码用途

    // --- 内部状态 --- //
    string accountsFilePath; // 账号表文件路径
    string sessionFilePath; // 会话文件路径
    LocalVerifyCode_Auth registerVerifyCode; // 注册流程内存验证码
    LocalVerifyCode_Auth resetPasswordVerifyCode; // 重置密码流程内存验证码
    bool isPathInitialized = false; // 是否已完成文件路径初始化

    public bool IsLoggedIn { get; private set; } // 当前是否已登录
    public string CurrentUserId { get; private set; } // 当前登录账号ID
    public string CurrentAccountId { get; private set; } // 当前登录账号标识
    public string LastMessage { get; private set; } // 最近一次认证提示
    public LocalSession_Auth CurrentSession { get; private set; } // 当前会话数据

    public event Action<bool> OnAuthStateChanged; // 认证状态变化事件
    public event Action<string> OnAuthMessageChanged; // 认证消息变化事件

    // ==========================================
    // 1. 初始化与恢复
    // ==========================================

    /// <summary>
    /// 初始化本地认证系统运行时依赖。
    /// </summary>
    public void Init_Sys_Auth()
    {
        if (!isPathInitialized)
        {
            // 初始化本地认证相关文件路径, 并确保根目录存在。
            var saveRootPath = DBCC_DataBase.Instance.Get_SaveRootDirectory_DB();
            Directory.CreateDirectory(saveRootPath);
            // 获取账号表和会话文件
            accountsFilePath = Path.Combine(saveRootPath, "accounts.json");
            sessionFilePath = Path.Combine(saveRootPath, "auth_session.json");
            isPathInitialized = true;
        }
    }

    /// <summary>
    /// 校验当前设备是否存在有效自动登录会话。
    /// </summary>
    /// <returns>返回自动登录结果。</returns>
    public Task<LocalAuthResult_Auth> Check_AutoLogin_Auth()
    {
        Init_Sys_Auth();

        // 先读取当前设备保存的会话信息。
        if (!Try_LoadSession_Auth(out var session))
        {
            Set_LogoutState_Auth("本地会话读取失败。", true);
            return Task.FromResult(Build_FailedResult_Auth("本地会话读取失败。"));
        }

        // 没有会话时直接返回未登录状态。
        if (session == null)
        {
            Set_LogoutState_Auth("当前没有可恢复的登录态。");
            return Task.FromResult(Build_FailedResult_Auth("当前没有可恢复的登录态。"));
        }

        if (string.IsNullOrWhiteSpace(session.userId))
        {
            Set_LogoutState_Auth("本地会话缺少账号ID, 请重新登录。", true);
            return Task.FromResult(Build_FailedResult_Auth("本地会话缺少账号ID, 请重新登录。"));
        }

        // 会话过期后立即清理, 防止继续使用失效登录态。
        if (session.expiresAt <= DateTime.UtcNow)
        {
            Set_LogoutState_Auth("登录已过期, 请重新登录。", true);
            return Task.FromResult(Build_FailedResult_Auth("登录已过期, 请重新登录。"));
        }

        // 再读取账号表, 确认当前会话对应的账号仍然存在。
        if (!Try_LoadAccountsTable_Auth(out var accountsTable))
        {
            Set_LogoutState_Auth("账号数据读取失败。", true);
            return Task.FromResult(Build_FailedResult_Auth("账号数据读取失败。"));
        }

        var accountRecord = Find_AccountByUserId_Auth(accountsTable, session.userId);
        if (accountRecord == null)
        {
            Set_LogoutState_Auth("账号信息不存在, 请重新登录。", true);
            return Task.FromResult(Build_FailedResult_Auth("账号信息不存在, 请重新登录。"));
        }

        // 会话和账号都有效后, 同步当前登录状态并通知界面层。
        CurrentSession = session;
        Apply_LoginState_Auth(accountRecord);
        Set_Message_Auth("自动登录成功。");
        OnAuthStateChanged?.Invoke(true);
        return Task.FromResult(Build_SuccessResult_Auth(accountRecord, "自动登录成功。", true, false));
    }

    // ==========================================
    // 2. 对外认证流程
    // ==========================================

    /// <summary>
    /// 【核心】注册本地账号并建立登录会话。
    /// 流程: 1.校验账号和验证码, 2.创建账号记录, 3.写回账号表, 4.创建登录会话。
    /// </summary>
    /// <param name="_accountId">玩家输入账号。</param>
    /// <param name="_password">密码输入。</param>
    /// <param name="_verifyCode">玩家输入验证码。</param>
    /// <returns>返回注册结果。</returns>
    public Task<LocalAuthResult_Auth> Register_Account_Auth(string _accountId, string _password, string _verifyCode)
    {
        Init_Sys_Auth();

        // 先标准化并校验用户输入。
        var accountId = Normalize_AccountId_Auth(_accountId);
        if (!Check_AccountIdValid_Auth(accountId, out var accountIdErrorMessage))
        {
            Set_Message_Auth(accountIdErrorMessage, false);
            return Task.FromResult(Build_FailedResult_Auth(accountIdErrorMessage));
        }

        if (string.IsNullOrWhiteSpace(_password))
        {
            Set_Message_Auth("请输入密码。", false);
            return Task.FromResult(Build_FailedResult_Auth("请输入密码。"));
        }

        if (string.IsNullOrWhiteSpace(_verifyCode))
        {
            Set_Message_Auth("请输入验证码。", false);
            return Task.FromResult(Build_FailedResult_Auth("请输入验证码。"));
        }

        // 读取账号表, 检查当前账号是否已存在。
        if (!Try_LoadAccountsTable_Auth(out var accountsTable))
        {
            Set_Message_Auth("账号数据读取失败。", false);
            return Task.FromResult(Build_FailedResult_Auth("账号数据读取失败。"));
        }

        if (Find_AccountByAccountId_Auth(accountsTable, accountId) != null)
        {
            Set_Message_Auth("该账号已存在。", false);
            return Task.FromResult(Build_FailedResult_Auth("该账号已存在。"));
        }

        // 注册验证码只和注册流程绑定, 不能复用重置密码验证码。
        if (!Check_VerifyCode_Auth(accountId, _verifyCode, RegisterVerifyPurpose, registerVerifyCode, out var verifyErrorMessage, out var isVerifyCodeExpired))
        {
            if (isVerifyCodeExpired)
            {
                registerVerifyCode = null;
            }

            Set_Message_Auth(verifyErrorMessage, false);
            return Task.FromResult(Build_FailedResult_Auth(verifyErrorMessage));
        }

        // 生成新账号记录, 并为它分配专属存档文件名。
        var currentTime = DateTime.UtcNow;
        var userId = Guid.NewGuid().ToString("N");
        var passwordSalt = Create_Salt_Auth();
        var accountRecord = new LocalAccountRecord_Auth
        {
            userId = userId,
            accountId = accountId,
            passwordSalt = passwordSalt,
            passwordHash = Calculate_PasswordHash_Auth(_password, passwordSalt),
            saveFileName = $"save_{userId}.json",
            createdAt = currentTime,
            lastLoginAt = currentTime
        };

        // 先持久化账号表, 再创建登录会话。
        accountsTable.accountList.Add(accountRecord);
        if (!Save_AccountsTable_Auth(accountsTable))
        {
            Set_Message_Auth("账号数据保存失败。", false);
            return Task.FromResult(Build_FailedResult_Auth("账号数据保存失败。"));
        }

        if (!Create_LoginSession_Auth(accountRecord, currentTime))
        {
            Set_Message_Auth("登录会话创建失败。", false);
            return Task.FromResult(Build_FailedResult_Auth("登录会话创建失败。"));
        }

        // 最后更新提示并广播登录成功状态。
        registerVerifyCode = null;
        Set_Message_Auth("注册成功。");
        OnAuthStateChanged?.Invoke(true);
        return Task.FromResult(Build_SuccessResult_Auth(accountRecord, "注册成功。", false, true));
    }

    /// <summary>
    /// 使用本地账号和密码执行登录。
    /// </summary>
    /// <param name="_accountId">玩家输入账号。</param>
    /// <param name="_password">密码输入。</param>
    /// <returns>返回登录结果。</returns>
    public Task<LocalAuthResult_Auth> Login_Password_Auth(string _accountId, string _password)
    {
        Init_Sys_Auth();

        // 先标准化并校验用户输入。
        var accountId = Normalize_AccountId_Auth(_accountId);
        if (!Check_AccountIdValid_Auth(accountId, out var accountIdErrorMessage))
        {
            Set_Message_Auth(accountIdErrorMessage, false);
            return Task.FromResult(Build_FailedResult_Auth(accountIdErrorMessage));
        }

        if (string.IsNullOrWhiteSpace(_password))
        {
            Set_Message_Auth("请输入密码。", false);
            return Task.FromResult(Build_FailedResult_Auth("请输入密码。"));
        }

        // 读取账号表并查找目标账号。
        if (!Try_LoadAccountsTable_Auth(out var accountsTable))
        {
            Set_Message_Auth("账号数据读取失败。", false);
            return Task.FromResult(Build_FailedResult_Auth("账号数据读取失败。"));
        }

        var accountRecord = Find_AccountByAccountId_Auth(accountsTable, accountId);
        if (accountRecord == null)
        {
            Set_Message_Auth("账号不存在。", false);
            return Task.FromResult(Build_FailedResult_Auth("账号不存在。"));
        }

        // 使用输入密码重新计算哈希, 与本地记录进行比对。
        var currentHash = Calculate_PasswordHash_Auth(_password, accountRecord.passwordSalt);
        if (!string.Equals(currentHash, accountRecord.passwordHash, StringComparison.Ordinal))
        {
            Set_Message_Auth("密码错误。", false);
            return Task.FromResult(Build_FailedResult_Auth("密码错误。"));
        }

        // 登录成功后刷新最近登录时间, 然后写回账号表。
        accountRecord.lastLoginAt = DateTime.UtcNow;
        if (!Save_AccountsTable_Auth(accountsTable))
        {
            Set_Message_Auth("账号数据保存失败。", false);
            return Task.FromResult(Build_FailedResult_Auth("账号数据保存失败。"));
        }

        if (!Create_LoginSession_Auth(accountRecord, accountRecord.lastLoginAt))
        {
            Set_Message_Auth("登录会话创建失败。", false);
            return Task.FromResult(Build_FailedResult_Auth("登录会话创建失败。"));
        }

        // 最后更新提示并广播登录成功状态。
        Set_Message_Auth("登录成功。");
        OnAuthStateChanged?.Invoke(true);
        return Task.FromResult(Build_SuccessResult_Auth(accountRecord, "登录成功。", false, false));
    }

    /// <summary>
    /// 注销当前本地登录态并清理会话文件。
    /// </summary>
    public Task Logout_Account_Auth()
    {
        Init_Sys_Auth();
        Set_LogoutState_Auth("已注销登录。", true);
        return Task.CompletedTask;
    }

    /// <summary>
    /// 只读获取本机账号公开信息, 不包含密码哈希与盐值。
    /// </summary>
    /// <param name="accounts">账号公开信息列表。</param>
    /// <returns>返回是否读取成功。</returns>
    public bool Try_GetPublicAccounts_Auth(out List<LocalAccountPublicInfo_Auth> accounts)
    {
        // 确保账号表路径已初始化, 让外部系统可以独立调用该只读接口。
        Init_Sys_Auth();
        accounts = new List<LocalAccountPublicInfo_Auth>();

        // 账号表解析失败时直接返回 false, 由排行榜系统决定如何降级显示。
        if (!Try_LoadAccountsTable_Auth(out var accountsTable))
        {
            return false;
        }

        foreach (var accountRecord in accountsTable.accountList)
        {
            // 跳过异常账号记录, 避免空记录影响整个排行榜列表生成。
            if (accountRecord == null || string.IsNullOrWhiteSpace(accountRecord.userId))
            {
                continue;
            }

            // 只复制公开字段, 不把 passwordHash/passwordSalt 暴露给排行榜。
            accounts.Add(new LocalAccountPublicInfo_Auth
            {
                userId = accountRecord.userId,
                accountId = accountRecord.accountId,
                saveFileName = accountRecord.saveFileName
            });
        }

        return true;
    }

    /// <summary>
    /// 【核心】发送本地模拟【注册】验证码。
    /// 流程: 1.校验账号格式, 2.确认账号不存在, 3.模拟发送延迟, 4.生成验证码并写入内存。
    /// </summary>
    /// <param name="_accountId">玩家输入账号。</param>
    /// <returns>返回验证码发送结果。</returns>
    public async Task<LocalAuthResult_Auth> Send_RegisterCode_Auth(string _accountId)
    {
        Init_Sys_Auth();

        // 注册验证码只允许发送给尚未存在的合法账号。
        var accountId = Normalize_AccountId_Auth(_accountId);
        if (!Check_AccountIdValid_Auth(accountId, out var accountIdErrorMessage))
        {
            Set_Message_Auth(accountIdErrorMessage, false);
            return Build_FailedResult_Auth(accountIdErrorMessage);
        }

        // 同账号注册验证码未过期时, 拦截重复发送请求并提示剩余冷却时间。
        if (registerVerifyCode != null &&
            string.Equals(registerVerifyCode.accountId, accountId, StringComparison.Ordinal) &&
            string.Equals(registerVerifyCode.purpose, RegisterVerifyPurpose, StringComparison.Ordinal) &&
            registerVerifyCode.expiresAt > DateTime.UtcNow)
        {
            var remainingSeconds = Math.Max(1, (int)Math.Ceiling((registerVerifyCode.expiresAt - DateTime.UtcNow).TotalSeconds));
            Set_Message_Auth("验证码已发送, 请勿重复点击。", false);
            Debug.LogWarning($"[Sys_Auth] 验证码冷却中, 剩余 {remainingSeconds} 秒。");
            return Build_FailedResult_Auth("验证码已发送, 请勿重复点击。");
        }

        if (!Try_LoadAccountsTable_Auth(out var accountsTable))
        {
            Set_Message_Auth("账号数据读取失败。", false);
            return Build_FailedResult_Auth("账号数据读取失败。");
        }

        if (Find_AccountByAccountId_Auth(accountsTable, accountId) != null)
        {
            Set_Message_Auth("该账号已存在。", false);
            return Build_FailedResult_Auth("该账号已存在。");
        }

        // 本地模拟验证码发送耗时, 用于模拟真实短信或邮件服务延迟。
        var delayMilliseconds = UnityEngine.Random.Range(1000, 5001);
        await Task.Delay(delayMilliseconds);

        // 发送完成后生成注册验证码, 与重置密码验证码分开保存。
        var verifyCode = Create_VerifyCode_Auth();
        registerVerifyCode = new LocalVerifyCode_Auth   //注册的验证码
        {
            accountId = accountId,
            code = verifyCode,
            expiresAt = DateTime.UtcNow.AddMinutes(VerifyCodeMinutes),
            purpose = RegisterVerifyPurpose
        };

        Debug.LogWarning($"[Sys_Auth] 注册验证码: {verifyCode}, 1分钟内有效。");
        Set_Message_Auth("验证码已发送, 请查看 Console。");
        return Build_SuccessMessageResult_Auth("验证码已发送, 请查看 Console。");
    }

    /// <summary>
    /// 【核心】发送本地模拟【重置密码】验证码。
    /// 流程: 1.校验账号, 2.模拟发送延迟, 3.生成验证码并写入内存, 4.通过 Console 输出验证码。
    /// </summary>
    /// <param name="_accountId">玩家输入账号。</param>
    /// <returns>返回验证码发送结果。</returns>
    public async Task<LocalAuthResult_Auth> Send_ResetPasswordCode_Auth(string _accountId)
    {
        Init_Sys_Auth();

        // 先校验账号输入, 避免给非法账号生成验证码。
        var accountId = Normalize_AccountId_Auth(_accountId);
        if (!Check_AccountIdValid_Auth(accountId, out var accountIdErrorMessage))
        {
            Set_Message_Auth(accountIdErrorMessage, false);
            return Build_FailedResult_Auth(accountIdErrorMessage);
        }

        // 同账号重置密码验证码未过期时, 拦截重复发送请求并提示剩余冷却时间。
        if (resetPasswordVerifyCode != null &&
            string.Equals(resetPasswordVerifyCode.accountId, accountId, StringComparison.Ordinal) &&
            string.Equals(resetPasswordVerifyCode.purpose, ResetPasswordVerifyPurpose, StringComparison.Ordinal) &&
            resetPasswordVerifyCode.expiresAt > DateTime.UtcNow)
        {
            var remainingSeconds = Math.Max(1, (int)Math.Ceiling((resetPasswordVerifyCode.expiresAt - DateTime.UtcNow).TotalSeconds));
            Set_Message_Auth("验证码已发送, 请勿重复点击。", false);
            Debug.LogWarning($"[Sys_Auth] 验证码冷却中, 剩余 {remainingSeconds} 秒。");
            return Build_FailedResult_Auth("验证码已发送, 请勿重复点击。");
        }

        // 发送验证码前必须确认账号表里存在该账号。
        if (!Try_LoadAccountsTable_Auth(out var accountsTable))
        {
            Set_Message_Auth("账号数据读取失败。", false);
            return Build_FailedResult_Auth("账号数据读取失败。");
        }

        if (Find_AccountByAccountId_Auth(accountsTable, accountId) == null)
        {
            Set_Message_Auth("账号不存在。", false);
            return Build_FailedResult_Auth("账号不存在。");
        }

        // 本地模拟验证码发送耗时, 用于模拟真实短信或邮件服务延迟。
        var delayMilliseconds = UnityEngine.Random.Range(1000, 5001);
        await Task.Delay(delayMilliseconds);

        // 延迟结束后再生成验证码并设置1分钟有效期。
        var verifyCode = Create_VerifyCode_Auth();
        resetPasswordVerifyCode = new LocalVerifyCode_Auth  //重置密码的验证码
        {
            accountId = accountId,
            code = verifyCode,
            expiresAt = DateTime.UtcNow.AddMinutes(VerifyCodeMinutes),
            purpose = ResetPasswordVerifyPurpose
        };

        Debug.LogWarning($"[Sys_Auth] 重置密码验证码: {verifyCode}, 1分钟内有效。");
        Set_Message_Auth("验证码已发送, 请查看 Console。");
        return Build_SuccessMessageResult_Auth("验证码已发送, 请查看 Console。");
    }

    /// <summary>
    /// 【核心】使用本地验证码重置账号密码。
    /// 流程: 1.校验账号和验证码, 2.重建密码盐值与哈希, 3.写回账号表。
    /// </summary>
    /// <param name="_accountId">玩家输入账号。</param>
    /// <param name="_verifyCode">玩家输入验证码。</param>
    /// <param name="_newPassword">玩家输入新密码。</param>
    /// <returns>返回密码重置结果。</returns>
    public Task<LocalAuthResult_Auth> Reset_Password_Auth(string _accountId, string _verifyCode, string _newPassword)
    {
        Init_Sys_Auth();

        // 先校验基础输入, 避免读取账号表后才失败。
        var accountId = Normalize_AccountId_Auth(_accountId);
        if (!Check_AccountIdValid_Auth(accountId, out var accountIdErrorMessage))
        {
            Set_Message_Auth(accountIdErrorMessage, false);
            return Task.FromResult(Build_FailedResult_Auth(accountIdErrorMessage));
        }

        if (string.IsNullOrWhiteSpace(_verifyCode))
        {
            Set_Message_Auth("请输入验证码。", false);
            return Task.FromResult(Build_FailedResult_Auth("请输入验证码。"));
        }

        if (string.IsNullOrWhiteSpace(_newPassword))
        {
            Set_Message_Auth("请输入新密码。", false);
            return Task.FromResult(Build_FailedResult_Auth("请输入新密码。"));
        }

        // 账号表读取成功后再查找目标账号。
        if (!Try_LoadAccountsTable_Auth(out var accountsTable))
        {
            Set_Message_Auth("账号数据读取失败。", false);
            return Task.FromResult(Build_FailedResult_Auth("账号数据读取失败。"));
        }

        var accountRecord = Find_AccountByAccountId_Auth(accountsTable, accountId);
        if (accountRecord == null)
        {
            Set_Message_Auth("账号不存在。", false);
            return Task.FromResult(Build_FailedResult_Auth("账号不存在。"));
        }

        // 重置密码验证码只和重置流程绑定, 不能复用注册验证码。
        if (!Check_VerifyCode_Auth(accountId, _verifyCode, ResetPasswordVerifyPurpose, resetPasswordVerifyCode, out var verifyErrorMessage, out var isVerifyCodeExpired))
        {
            if (isVerifyCodeExpired)
            {
                resetPasswordVerifyCode = null;
            }

            Set_Message_Auth(verifyErrorMessage, false);
            return Task.FromResult(Build_FailedResult_Auth(verifyErrorMessage));
        }

        // 验证通过后重建密码盐值与哈希, 再写回账号表。
        var passwordSalt = Create_Salt_Auth();
        accountRecord.passwordSalt = passwordSalt;
        accountRecord.passwordHash = Calculate_PasswordHash_Auth(_newPassword, passwordSalt);
        if (!Save_AccountsTable_Auth(accountsTable))
        {
            Set_Message_Auth("账号数据保存失败。", false);
            return Task.FromResult(Build_FailedResult_Auth("账号数据保存失败。"));
        }

        resetPasswordVerifyCode = null;
        Set_Message_Auth("密码已重置, 请重新登录。");
        return Task.FromResult(Build_SuccessMessageResult_Auth("密码已重置, 请重新登录。"));
    }

    /// <summary>
    /// 【核心】删除当前已登录账号。
    /// 流程: 1.校验登录态, 2.从账号表删除账号, 3.清理会话和验证码, 4.重置认证状态。
    /// </summary>
    /// <returns>返回删除账号结果。</returns>
    public Task<LocalAuthResult_Auth> Delete_CurrentAccount_Auth()
    {
        Init_Sys_Auth();

        if (!IsLoggedIn || string.IsNullOrWhiteSpace(CurrentUserId))
        {
            Set_Message_Auth("请先登录账号。", false);
            return Task.FromResult(Build_FailedResult_Auth("请先登录账号。"));
        }

        // 删除前缓存当前账号信息, 因为后面会清空登录态。
        var deleteUserId = CurrentUserId;
        var deleteAccountId = CurrentAccountId;

        if (!Try_LoadAccountsTable_Auth(out var accountsTable))
        {
            Set_Message_Auth("账号数据读取失败。", false);
            return Task.FromResult(Build_FailedResult_Auth("账号数据读取失败。"));
        }

        var accountRecord = Find_AccountByUserId_Auth(accountsTable, deleteUserId);
        if (accountRecord == null)
        {
            Set_LogoutState_Auth("账号信息不存在, 已清理登录态。", true);
            return Task.FromResult(Build_FailedResult_Auth("账号信息不存在, 已清理登录态。"));
        }

        // 先从账号表移除账号并写回文件, 写回成功后再清理当前登录态。
        accountsTable.accountList.Remove(accountRecord);
        if (!Save_AccountsTable_Auth(accountsTable))
        {
            Set_Message_Auth("账号数据保存失败。", false);
            return Task.FromResult(Build_FailedResult_Auth("账号数据保存失败。"));
        }

        Clear_SessionFile_Auth();
        Clear_VerifyCodeCache_Auth();
        Reset_LoginState_Auth();
        Set_Message_Auth("账号已删除。");
        OnAuthStateChanged?.Invoke(false);

        return Task.FromResult(new LocalAuthResult_Auth
        {
            Success = true,
            UserId = accountRecord.userId,
            AccountId = string.IsNullOrWhiteSpace(accountRecord.accountId) ? deleteAccountId : accountRecord.accountId,
            SaveFileName = accountRecord.saveFileName,
            Message = "账号已删除。"
        });
    }

    // ==========================================
    // 3. 本地文件与状态流转
    // ==========================================

    /// <summary>
    /// 创建新的本地登录会话并立即持久化。
    /// </summary>
    /// <param name="accountRecord">账号记录。</param>
    /// <param name="currentTime">当前登录时间。</param>
    /// <returns>返回是否创建成功。</returns>
    bool Create_LoginSession_Auth(LocalAccountRecord_Auth accountRecord, DateTime currentTime)
    {
        // 根据账号记录生成新的本地登录会话, 并写入有效期。
        CurrentSession = new LocalSession_Auth
        {
            userId = accountRecord.userId,
            accountId = accountRecord.accountId,
            lastLoginAt = currentTime,
            expiresAt = currentTime.AddHours(AutoLoginHours)
        };

        if (!Save_Session_Auth(CurrentSession))
        {
            CurrentSession = null;
            return false;
        }

        // 会话写入成功后, 再同步内存中的登录状态。
        Apply_LoginState_Auth(accountRecord);
        return true;
    }

    /// <summary>
    /// 校验内存验证码是否与玩家输入匹配。
    /// </summary>
    /// <param name="accountId">玩家账号。</param>
    /// <param name="verifyCode">玩家输入验证码。</param>
    /// <param name="purpose">目标验证码用途。</param>
    /// <param name="storedVerifyCode">服务端内存验证码。</param>
    /// <param name="errorMessage">错误提示。</param>
    /// <param name="isExpired">验证码是否已过期。</param>
    /// <returns>返回验证码是否有效。</returns>
    bool Check_VerifyCode_Auth(string accountId, string verifyCode, string purpose, LocalVerifyCode_Auth storedVerifyCode, out string errorMessage, out bool isExpired)
    {
        isExpired = false;

        // 验证码只存在内存中, 游戏重启后自然失效。
        if (storedVerifyCode == null)
        {
            errorMessage = "请先发送验证码。";
            return false;
        }

        if (!string.Equals(storedVerifyCode.purpose, purpose, StringComparison.Ordinal))
        {
            errorMessage = "验证码用途不匹配。";
            return false;
        }

        if (!string.Equals(storedVerifyCode.accountId, accountId, StringComparison.Ordinal))
        {
            errorMessage = "验证码账号不匹配。";
            return false;
        }

        if (storedVerifyCode.expiresAt <= DateTime.UtcNow)
        {
            isExpired = true;
            errorMessage = "验证码已过期, 请重新发送。";
            return false;
        }

        if (!string.Equals(storedVerifyCode.code, verifyCode.Trim(), StringComparison.Ordinal))
        {
            errorMessage = "验证码错误。";
            return false;
        }

        errorMessage = null;
        return true;
    }

    /// <summary>
    /// 将账号记录同步为当前运行中的登录状态。
    /// </summary>
    /// <param name="accountRecord">账号记录。</param>
    void Apply_LoginState_Auth(LocalAccountRecord_Auth accountRecord)
    {
        IsLoggedIn = true;
        CurrentUserId = accountRecord.userId;
        CurrentAccountId = accountRecord.accountId;
    }

    /// <summary>
    /// 读取本地账号表文件。
    /// </summary>
    /// <param name="accountsTable">读取到的账号表。</param>
    /// <returns>返回是否读取成功。</returns>
    bool Try_LoadAccountsTable_Auth(out LocalAccountsTable_Auth accountsTable)
    {
        accountsTable = new LocalAccountsTable_Auth();

        // 缺文件表示首次运行, 账号表读取成功且内容为空。
        if (!File.Exists(accountsFilePath))
        {
            return true;
        }

        try
        {
            var json = File.ReadAllText(accountsFilePath);
            if (string.IsNullOrWhiteSpace(json))
            {
                Debug.LogError("[Sys_Auth] 账号表文件存在但内容为空。");
                accountsTable = null;
                return false;
            }

            accountsTable = JsonConvert.DeserializeObject<LocalAccountsTable_Auth>(json);
            if (accountsTable == null)
            {
                Debug.LogError("[Sys_Auth] 账号表解析结果为空。");
                return false;
            }

            if (accountsTable.accountList == null)
            {
                accountsTable.accountList = new List<LocalAccountRecord_Auth>();
            }
            return true;
        }
        catch (Exception exception)
        {
            Debug.LogError($"[Sys_Auth] 读取账号表失败: {exception.Message}");
            accountsTable = null;
            return false;
        }
    }

    /// <summary>
    /// 保存本地账号表文件。
    /// </summary>
    /// <param name="accountsTable">待保存的账号表。</param>
    /// <returns>返回是否保存成功。</returns>
    bool Save_AccountsTable_Auth(LocalAccountsTable_Auth accountsTable)
    {
        try
        {
            var json = JsonConvert.SerializeObject(accountsTable, Formatting.Indented);
            File.WriteAllText(accountsFilePath, json);
            return true;
        }
        catch (Exception exception)
        {
            Debug.LogError($"[Sys_Auth] 保存账号表失败: {exception.Message}");
            return false;
        }
    }

    /// <summary>
    /// 读取本地会话文件。
    /// </summary>
    /// <param name="session">读取到的会话数据。</param>
    /// <returns>返回是否读取成功。</returns>
    bool Try_LoadSession_Auth(out LocalSession_Auth session)
    {
        session = null;

        // 缺文件表示没有自动登录态, 会话读取成功且内容为空。
        if (!File.Exists(sessionFilePath))
        {
            return true;
        }

        try
        {
            var json = File.ReadAllText(sessionFilePath);
            if (string.IsNullOrWhiteSpace(json))
            {
                Debug.LogError("[Sys_Auth] 会话文件存在但内容为空。");
                return false;
            }

            session = JsonConvert.DeserializeObject<LocalSession_Auth>(json);
            if (session == null)
            {
                Debug.LogError("[Sys_Auth] 会话解析结果为空。");
                return false;
            }

            return true;
        }
        catch (Exception exception)
        {
            Debug.LogError($"[Sys_Auth] 读取会话失败: {exception.Message}");
            return false;
        }
    }

    /// <summary>
    /// 保存本地会话文件。
    /// </summary>
    /// <param name="session">待保存的会话数据。</param>
    /// <returns>返回是否保存成功。</returns>
    bool Save_Session_Auth(LocalSession_Auth session)
    {
        try
        {
            var json = JsonConvert.SerializeObject(session, Formatting.Indented);
            File.WriteAllText(sessionFilePath, json);
            return true;
        }
        catch (Exception exception)
        {
            Debug.LogError($"[Sys_Auth] 保存会话失败: {exception.Message}");
            return false;
        }
    }

    /// <summary>
    /// 删除本地会话文件。
    /// </summary>
    void Clear_SessionFile_Auth()
    {
        if (File.Exists(sessionFilePath))
        {
            File.Delete(sessionFilePath);
        }
    }

    /// <summary>
    /// 按玩家输入账号查找本地账号记录。
    /// </summary>
    /// <param name="accountsTable">账号表。</param>
    /// <param name="accountId">玩家输入账号。</param>
    /// <returns>返回匹配到的账号记录。</returns>
    LocalAccountRecord_Auth Find_AccountByAccountId_Auth(LocalAccountsTable_Auth accountsTable, string accountId)
    {
        return accountsTable.accountList.Find(account => string.Equals(account.accountId, accountId, StringComparison.Ordinal));
    }

    /// <summary>
    /// 按账号唯一ID查找本地账号记录。
    /// </summary>
    /// <param name="accountsTable">账号表。</param>
    /// <param name="userId">账号ID。</param>
    /// <returns>返回匹配到的账号记录。</returns>
    LocalAccountRecord_Auth Find_AccountByUserId_Auth(LocalAccountsTable_Auth accountsTable, string userId)
    {
        return accountsTable.accountList.Find(account => string.Equals(account.userId, userId, StringComparison.Ordinal));
    }

    /// <summary>
    /// 标准化账号输入内容。
    /// </summary>
    /// <param name="accountId">原始账号输入。</param>
    /// <returns>返回清理后的账号字符串。</returns>
    string Normalize_AccountId_Auth(string accountId)
    {
        return string.IsNullOrWhiteSpace(accountId) ? string.Empty : accountId.Trim();
    }

    /// <summary>
    /// 校验玩家输入账号格式。
    /// </summary>
    /// <param name="accountId">玩家输入账号。</param>
    /// <param name="errorMessage">错误提示。</param>
    /// <returns>返回账号格式是否有效。</returns>
    bool Check_AccountIdValid_Auth(string accountId, out string errorMessage)
    {
        if (string.IsNullOrWhiteSpace(accountId))
        {
            errorMessage = "请输入账号。";
            return false;
        }

        if (accountId.Length >= 10)
        {
            errorMessage = "账号长度需要少于10个字符。";
            return false;
        }

        foreach (var accountChar in accountId)
        {
            if (!char.IsLetterOrDigit(accountChar) || accountChar > 127)
            {
                errorMessage = "账号只能使用英文字母和数字。";
                return false;
            }
        }

        errorMessage = null;
        return true;
    }

    /// <summary>
    /// 生成密码盐值。
    /// </summary>
    /// <returns>返回新的盐值字符串。</returns>
    string Create_Salt_Auth()
    {
        var saltBytes = new byte[16];
        using (var random = RandomNumberGenerator.Create())
        {
            random.GetBytes(saltBytes);
        }

        return Convert.ToBase64String(saltBytes);
    }

    /// <summary>
    /// 生成6位数字验证码。
    /// </summary>
    /// <returns>返回6位数字验证码。</returns>
    string Create_VerifyCode_Auth()
    {
        return UnityEngine.Random.Range(0, 1000000).ToString("D6");
    }

    /// <summary>
    /// 根据密码和盐值计算哈希字符串。
    /// </summary>
    /// <param name="password">原始密码。</param>
    /// <param name="salt">密码盐值。</param>
    /// <returns>返回哈希后的字符串。</returns>
    string Calculate_PasswordHash_Auth(string password, string salt)
    {
        using (var sha256 = SHA256.Create())
        {
            var hashBytes = sha256.ComputeHash(Encoding.UTF8.GetBytes($"{password}:{salt}"));
            return Convert.ToBase64String(hashBytes);
        }
    }

    /// <summary>
    /// 构建成功认证结果对象。
    /// </summary>
    /// <param name="accountRecord">账号记录。</param>
    /// <param name="message">提示消息。</param>
    /// <param name="isAutoLogin">是否为自动登录。</param>
    /// <param name="isNewAccount">是否为新账号。</param>
    /// <returns>返回成功结果对象。</returns>
    LocalAuthResult_Auth Build_SuccessResult_Auth(LocalAccountRecord_Auth accountRecord, string message, bool isAutoLogin, bool isNewAccount)
    {
        return new LocalAuthResult_Auth
        {
            Success = true,
            IsAutoLogin = isAutoLogin,
            IsNewAccount = isNewAccount,
            UserId = accountRecord.userId,
            AccountId = accountRecord.accountId,
            SaveFileName = accountRecord.saveFileName,
            Message = message
        };
    }

    /// <summary>
    /// 构建失败认证结果对象。
    /// </summary>
    /// <param name="message">提示消息。</param>
    /// <returns>返回失败结果对象。</returns>
    LocalAuthResult_Auth Build_FailedResult_Auth(string message)
    {
        return new LocalAuthResult_Auth
        {
            Success = false,
            Message = message
        };
    }

    /// <summary>
    /// 构建不携带账号数据的成功认证结果对象。
    /// </summary>
    /// <param name="message">提示消息。</param>
    /// <returns>返回成功结果对象。</returns>
    LocalAuthResult_Auth Build_SuccessMessageResult_Auth(string message)
    {
        return new LocalAuthResult_Auth
        {
            Success = true,
            Message = message
        };
    }

    /// <summary>
    /// 重置当前内存中的登录状态字段。
    /// </summary>
    void Reset_LoginState_Auth()
    {
        CurrentSession = null;
        IsLoggedIn = false;
        CurrentUserId = null;
        CurrentAccountId = null;
    }

    /// <summary>
    /// 清空所有内存验证码。
    /// </summary>
    void Clear_VerifyCodeCache_Auth()
    {
        registerVerifyCode = null;  //注册用验证码
        resetPasswordVerifyCode = null; //重置密码用验证码
    }

    /// <summary>
    /// 清理当前登录态, 并按需删除本地会话文件。
    /// </summary>
    /// <param name="message">状态提示。</param>
    /// <param name="clearStorage">是否清理本地会话文件。</param>
    void Set_LogoutState_Auth(string message, bool clearStorage = false)
    {
        // 已登录时需要额外广播状态变化, 未登录时仅同步清理内存状态。
        if (clearStorage)
        {
            Clear_SessionFile_Auth();
        }

        if (IsLoggedIn)
        {
            Reset_LoginState_Auth();
            Set_Message_Auth(message, false);
            OnAuthStateChanged?.Invoke(false);
            return;
        }

        Reset_LoginState_Auth();
        Set_Message_Auth(message, false);
    }

    /// <summary>
    /// 更新最近一次认证消息并广播给界面层。
    /// </summary>
    /// <param name="message">提示消息。</param>
    /// <param name="isSuccess">是否为成功消息。</param>
    void Set_Message_Auth(string message, bool isSuccess = true)
    {
        LastMessage = message;
        if (!isSuccess && string.IsNullOrWhiteSpace(message))
        {
            LastMessage = "认证请求失败。";
        }

        OnAuthMessageChanged?.Invoke(LastMessage);
    }
}
