using System;
using System.Collections.Generic;

/// <summary>
/// 账号窗口当前交互模式。
/// </summary>
public enum AccountWindowMode_Auth
{
    Login, // 登录账号
    Register, // 注册账号
    ResetPassword // 重置密码
}

/// <summary>
/// 本地账号记录数据。
/// </summary>
[Serializable]
public class LocalAccountRecord_Auth
{
    public string userId; // 账号唯一ID
    public string accountId; // 玩家输入账号ID
    public string passwordHash; // 密码哈希值
    public string passwordSalt; // 密码
    public string saveFileName; // 对应存档文件名
    public DateTime createdAt; // 创建时间
    public DateTime lastLoginAt; // 最近登录时间
}

/// <summary>
/// 本地账号表数据。
/// </summary>
[Serializable]
public class LocalAccountsTable_Auth
{
    public List<LocalAccountRecord_Auth> accountList = new List<LocalAccountRecord_Auth>(); // 本机账号列表
}

/// <summary>
/// 本地账号公开信息, 不包含密码哈希和盐值。
/// </summary>
[Serializable]
public class LocalAccountPublicInfo_Auth
{
    public string userId; // 账号唯一ID
    public string accountId; // 玩家输入账号ID
    public string saveFileName; // 对应存档文件名
}

/// <summary>
/// 当前设备登录会话数据。
/// </summary>
[Serializable]
public class LocalSession_Auth
{
    public string userId; // 当前登录账号ID
    public string accountId; // 当前登录账号标识
    public DateTime expiresAt; // 自动登录失效时间
    public DateTime lastLoginAt; // 最近登录时间
}

/// <summary>
/// 本地模拟验证码数据。
/// </summary>
[Serializable]
public class LocalVerifyCode_Auth
{
    public string accountId; // 验证码所属账号
    public string code; // 验证码内容
    public DateTime expiresAt; // 验证码失效时间
    public string purpose; // 验证码用途
}

/// <summary>
/// 本地认证流程返回结果。
/// </summary>
[Serializable]
public class LocalAuthResult_Auth
{
    public bool Success; // 是否成功
    public bool IsAutoLogin; // 是否自动登录成功
    public bool IsNewAccount; // 是否为新注册账号
    public string UserId; // 账号唯一ID
    public string AccountId; // 玩家输入账号ID
    public string SaveFileName; // 对应存档文件名
    public string Message; // 结果提示信息
}
