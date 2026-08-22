using System;

[Serializable]
public class SendRegisterCodeResponse_Auth
{
    public string Phone { get; set; }

    public DateTime ExpiresAt { get; set; }

    public int CooldownSeconds { get; set; }

    public string DevCode { get; set; }
}
