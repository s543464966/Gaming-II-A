using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;
using UnityEngine;
using UnityEngine.Networking;

/// <summary>
/// 负责 Unity 客户端与 Auth 服务端之间的 HTTP 通信。
/// 这里不承载业务决策, 只负责请求发送与响应解析。
/// </summary>
public class AuthApiClient
{
    const string DefaultServerUrl = "http://localhost:5234";

    readonly string _serverUrl; // 服务端根地址

    /// <summary>
    /// 创建账号接口客户端。
    /// </summary>
    /// <param name="serverUrl">服务端根地址。</param>
    public AuthApiClient(string serverUrl = DefaultServerUrl)
    {
        _serverUrl = serverUrl.TrimEnd('/');
    }

    /// <summary>
    /// 请求发送注册验证码。
    /// </summary>
    /// <param name="_phone">手机号。</param>
    /// <returns>返回验证码发送结果。</returns>
    public Task<AuthApiResponse<SendRegisterCodeResponse_Auth>> Send_RegisterCode_Auth(string _phone)
    {
        var requestBody = new   //发送手机号object对象到服务端
        {
            Phone = _phone
        };

        return Send_Request_Auth<SendRegisterCodeResponse_Auth>("POST", "/api/auth/send-register-code", requestBody, null);
    }

    /// <summary>
    /// 请求服务端完成注册。
    /// </summary>
    /// <param name="_phone">手机号。</param>
    /// <param name="_password">密码。</param>
    /// <param name="_verifyCode">验证码。</param>
    /// <param name="_deviceId">设备标识。</param>
    /// <returns>返回注册后的登录态结果。</returns>
    public Task<AuthApiResponse<AuthTokenResponse_Auth>> Register_Account_Auth(string _phone, string _password, string _verifyCode, string _deviceId)
    {
        var requestBody = new
        {
            Phone = _phone,
            Password = _password,
            VerifyCode = _verifyCode,
            DeviceId = _deviceId
        };

        return Send_Request_Auth<AuthTokenResponse_Auth>("POST", "/api/auth/register", requestBody, null);
    }

    /// <summary>
    /// 请求服务端完成密码登录。
    /// </summary>
    /// <param name="_phone">手机号。</param>
    /// <param name="_password">密码。</param>
    /// <param name="_deviceId">设备标识。</param>
    /// <returns>返回登录态结果。</returns>
    public Task<AuthApiResponse<AuthTokenResponse_Auth>> Login_Password_Auth(string _phone, string _password, string _deviceId)
    {
        var requestBody = new
        {
            Phone = _phone,
            Password = _password,
            DeviceId = _deviceId
        };

        return Send_Request_Auth<AuthTokenResponse_Auth>("POST", "/api/auth/login/password", requestBody, null);
    }

    /// <summary>
    /// 使用 refresh token 请求新的登录态。
    /// </summary>
    /// <param name="_refreshToken">刷新令牌。</param>
    /// <returns>返回新的登录态结果。</returns>
    public Task<AuthApiResponse<AuthTokenResponse_Auth>> Refresh_Token_Auth(string _refreshToken)
    {
        var requestBody = new
        {
            RefreshToken = _refreshToken
        };

        return Send_Request_Auth<AuthTokenResponse_Auth>("POST", "/api/auth/refresh-token", requestBody, null);
    }

    /// <summary>
    /// 获取当前登录账号信息。
    /// </summary>
    /// <param name="_accessToken">访问令牌。</param>
    /// <returns>返回当前账号资料。</returns>
    public Task<AuthApiResponse<CurrentUserResponse_Auth>> Get_CurrentUser_Auth(string _accessToken)
    {
        return Send_Request_Auth<CurrentUserResponse_Auth>("GET", "/api/auth/me", null, _accessToken);
    }

    /// <summary>
    /// 请求注销当前登录会话。
    /// </summary>
    /// <param name="_accessToken">访问令牌。</param>
    /// <returns>返回退出结果。</returns>
    public Task<AuthApiResponse<object>> Logout_Account_Auth(string _accessToken)
    {
        return Send_Request_Auth<object>("POST", "/api/auth/logout", null, _accessToken);
    }

    /// <summary>
    /// 【核心】统一发送 Auth 请求并解析标准响应包。
    /// </summary>
    /// <typeparam name="T">响应数据类型。</typeparam>
    /// <param name="_method">HTTP 方法。</param>
    /// <param name="_path">接口路径。</param>
    /// <param name="_body">请求体对象。</param>
    /// <param name="_accessToken">访问令牌。</param>
    /// <returns>返回统一响应包。</returns>
    async Task<AuthApiResponse<T>> Send_Request_Auth<T>(string _method, string _path, object _body, string _accessToken)
    {
        var request = new UnityWebRequest($"{_serverUrl}{_path}", _method)  //拼接完整 URL
        {
            downloadHandler = new DownloadHandlerBuffer()
        };

        if (_body != null)
        {
            var bodyJson = JsonConvert.SerializeObject(_body);  //将C#对象序列化为JSON字符串
            var bodyBytes = Encoding.UTF8.GetBytes(bodyJson);
            request.uploadHandler = new UploadHandlerRaw(bodyBytes);
            request.SetRequestHeader("Content-Type", "application/json");   //设置请求头
        }

        if (!string.IsNullOrWhiteSpace(_accessToken))
        {
            request.SetRequestHeader("Authorization", $"Bearer {_accessToken}");
        }

        var operation = request.SendWebRequest();// 发送请求到服务端循环等待接收结果
        while (!operation.isDone)
        {
            await System.Threading.Tasks.Task.Yield();
        }

        var responseText = request.downloadHandler?.text;
        if (request.result == UnityWebRequest.Result.ConnectionError)
        {
            return new AuthApiResponse<T>
            {
                Success = false,
                Message = request.error,
                ErrorCode = "AUTH_NETWORK_ERROR"
            };
        }

        if (string.IsNullOrWhiteSpace(responseText))
        {
            return new AuthApiResponse<T>
            {
                Success = false,
                Message = "服务器返回了空响应。",
                ErrorCode = "AUTH_EMPTY_RESPONSE"
            };
        }

        try
        {
            //将服务器响应的 JSON 字符串反序列化为 AuthApiResponse<T> 对象
            return JsonConvert.DeserializeObject<AuthApiResponse<T>>(responseText); 
        }
        catch (System.Exception exception)
        {
            Debug.LogError($"[AuthApiClient] Parse failed: {exception.Message}\n{responseText}");
            return new AuthApiResponse<T>
            {
                Success = false,
                Message = "客户端解析服务器响应失败。",
                ErrorCode = "AUTH_PARSE_ERROR"
            };
        }
    }
}
