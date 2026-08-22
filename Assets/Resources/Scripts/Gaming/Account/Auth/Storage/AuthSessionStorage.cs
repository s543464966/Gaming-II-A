using System.IO;
using Newtonsoft.Json;
using UnityEngine;

/// <summary>
/// 负责将账号会话持久化到本地文件。
/// 当前只保存认证所需字段, 不介入玩家存档系统。
/// </summary>
public class AuthSessionStorage
{
    readonly string sessionFilePath = Path.Combine(Application.persistentDataPath, "auth_session.json"); // 会话文件路径

    /// <summary>
    /// 从本地读取已保存的会话信息。
    /// </summary>
    /// <returns>返回会话对象, 若不存在则返回 null。</returns>
    public AuthSession Load_Session_Auth()
    {
        if (!File.Exists(sessionFilePath))
        {
            return null;
        }

        var json = File.ReadAllText(sessionFilePath);
        if (string.IsNullOrWhiteSpace(json))
        {
            return null;
        }

        return JsonConvert.DeserializeObject<AuthSession>(json);
    }

    /// <summary>
    /// 将当前认证会话写入本地文件。
    /// </summary>
    /// <param name="_session">待保存的会话对象。</param>
    public void Save_Session_Auth(AuthSession _session)
    {
        if (_session == null)
        {
            return;
        }

        var json = JsonConvert.SerializeObject(_session, Formatting.Indented);
        File.WriteAllText(sessionFilePath, json);
    }

    /// <summary>
    /// 删除本地保存的认证会话文件。
    /// </summary>
    public void Clear_Session_Auth()
    {
        if (File.Exists(sessionFilePath))
        {
            File.Delete(sessionFilePath);
        }
    }
}
