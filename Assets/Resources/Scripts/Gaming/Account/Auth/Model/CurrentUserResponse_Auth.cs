using System;

[Serializable]
public class CurrentUserResponse_Auth
{
    public string UserId { get; set; }

    public string UserNo { get; set; }

    public string Phone { get; set; }

    public string PhoneMasked { get; set; }

    public DateTime CreatedAt { get; set; }
}
