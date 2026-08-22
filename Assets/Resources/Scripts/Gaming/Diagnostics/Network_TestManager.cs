using System.Collections;
using Microsoft.AspNetCore.SignalR.Client;
using TMPro;
using UnityEngine;
using UnityEngine.Networking;

/// <summary>
/// 用于保留开发期网络联调能力。
/// 当前承接从 Loading_UIManager 中迁出的时间接口与 SignalR 测试逻辑。
/// </summary>
public class Network_TestManager : MonoBehaviour
{
    //====== 网络测试 ======//
    [Header("模块: 网络测试")]
    [Tooltip("服务端根地址")] public string serverUrl = "http://localhost:5234"; // 服务端根地址
    [Tooltip("时间显示文本")] public TMP_Text timeDisplayText; // 时间显示文本

    // --- 内部状态 ---
    string _latestServerTime = "???"; // 最新服务端时间
    bool _isTimeUpdated; // 时间是否已更新
    HubConnection _hubConnection; // SignalR 连接

    void Update()
    {
        if (_isTimeUpdated && timeDisplayText != null)
        {
            timeDisplayText.text = "Server Time: " + _latestServerTime;
            _isTimeUpdated = false;
        }
    }

    /// <summary>
    /// 初始化 SignalR 连接, 并监听服务端时间广播。
    /// </summary>
    /// <param name="_endpoint">Hub 路径。</param>
    public async void Init_Connection_Network(string _endpoint)
    {
        var endUrl = $"{serverUrl.TrimEnd('/')}{_endpoint}";
        _hubConnection = new HubConnectionBuilder()
            .WithUrl(endUrl)
            .Build();

        _hubConnection.On<string>("Receive_Time_Update", serverTime =>
        {
            _latestServerTime = serverTime;
            _isTimeUpdated = true;
        });

        try
        {
            await _hubConnection.StartAsync();
            Debug.Log("SignalR connected.");
        }
        catch (System.Exception ex)
        {
            Debug.LogError("SignalR connect failed: " + ex.Message);
        }
    }

    /// <summary>
    /// 通过普通 HTTP 请求测试服务端接口可达性。
    /// </summary>
    /// <param name="_endpoint">接口路径。</param>
    /// <returns>协程枚举器。</returns>
    public IEnumerator Execute_Request_Network(string _endpoint)
    {
        var endUrl = $"{serverUrl.TrimEnd('/')}{_endpoint}";
        using var webRequest = UnityWebRequest.Get(endUrl);
        yield return webRequest.SendWebRequest();

        if (webRequest.result == UnityWebRequest.Result.ConnectionError ||
            webRequest.result == UnityWebRequest.Result.ProtocolError)
        {
            Debug.LogError("Network error: " + webRequest.error);
            yield break;
        }

        if (timeDisplayText != null)
        {
            timeDisplayText.text = "Server Time: " + webRequest.downloadHandler.text;
        }
    }
}
