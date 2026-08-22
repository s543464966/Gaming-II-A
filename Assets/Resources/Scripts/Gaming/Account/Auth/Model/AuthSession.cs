using System;

/// <summary>
/// 表示客户端本地保存的认证会话。
/// 只保存账号身份与登录态字段, 不承载玩家业务数据。
/// </summary>
[Serializable]
public class AuthSession
{
    public string userId; // 当前账号 Id
    public string userNo; // 当前账号编号
    public string phone; // 原始手机号
    public string phoneMasked; // 脱敏手机号
    public string accessToken; // 访问令牌
    public string refreshToken; // 刷新令牌
    public DateTime accessTokenExpiresAt; // 访问令牌过期时间
    public DateTime refreshTokenExpiresAt; // 刷新令牌过期时间
    public DateTime createdAt; // 账号创建时间
}
