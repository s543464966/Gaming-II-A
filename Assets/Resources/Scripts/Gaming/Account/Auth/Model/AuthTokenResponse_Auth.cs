using System;

[Serializable]
public class AuthTokenResponse_Auth
{
    public string UserId { get; set; }

    public string Phone { get; set; }

    public string PhoneMasked { get; set; }

    public string AccessToken { get; set; }

    public string RefreshToken { get; set; }

    public DateTime AccessTokenExpiresAt { get; set; }

    public DateTime RefreshTokenExpiresAt { get; set; }
}
