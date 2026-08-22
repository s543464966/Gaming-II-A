using UnityEngine;
using Newtonsoft.Json;
using System.IO;
using System;
using System.Collections.Generic;
using System.Collections;

public class DBCC_DataBase : MonoBehaviour
{
    //======单例模式======//
    public static DBCC_DataBase Instance { get; private set; }

    //======核心数据库======//
    [Header("模块: 核心数据库")]
    [Tooltip("当前账号对应的本地存档数据")] public SaveData SaveData; // 当前账号对应的本地存档数据
    [Tooltip("当前账号对应的运行时游戏数据")] public GameData GameData;   // 当前账号对应的运行时游戏数据

    public Sys_Auth Sys_Auth { get; private set; } = new Sys_Auth(); // 本地认证系统
    public Sys_PlayerRank Sys_PlayerRank { get; private set; } = new Sys_PlayerRank(); // 本地排行榜系统

    // --- 内部状态 --- (系统实现接口注册的列表)
    readonly List<ISavable> Systems = new List<ISavable>(); // 系统注册列表, 当前流程暂未启用
    // --- 内部状态 --- (当前账号存档路径)
    string savePath;
    // --- 内部状态 --- (存档操作标志，避免重复存档)
    bool isAsyncSaving = false; // 标志协程是否正在保存
    Coroutine asyncSaveCoroutine = null; // 用于保存协程的引用
    Coroutine userRuntimeTickCoroutine = null; // 用户运行时计时协程

    // ==========================================
    // 1. 初始化模块
    // ==========================================

    /// <summary>
    /// 初始化数据库单例与认证系统。
    /// </summary>
    void Awake()
    {
        if (Instance != null)
        {
            Destroy(gameObject);
            return;
        }

        Instance = this;
        DontDestroyOnLoad(gameObject);

        savePath = GetEditorDesktopSavePath();
        Sys_Auth.Init_Sys_Auth();
    }

    /// <summary>
    /// 获取当前平台的本地存档根目录。
    /// </summary>
    /// <returns>返回根目录绝对路径。</returns>
    public string Get_SaveRootDirectory_DB()
    {
        if (Application.platform == RuntimePlatform.WindowsEditor ||
            Application.platform == RuntimePlatform.OSXEditor)
        {
            return Environment.GetFolderPath(Environment.SpecialFolder.Desktop);
        }

        return Application.persistentDataPath;
    }

    /// <summary>
    /// 获取默认测试存档路径。
    /// </summary>
    /// <returns>返回默认存档绝对路径。</returns>
    string GetEditorDesktopSavePath()
    {
        return Path.Combine(Get_SaveRootDirectory_DB(), "save.json");
    }

    // ==========================================
    // 2. 账号存档管理
    // ==========================================

    /// <summary>
    /// 按账号ID加载或创建本地玩家存档。
    /// </summary>
    /// <param name="_userId">账号ID。</param>
    /// <param name="_saveFileName">存档文件名。</param>
    /// <returns>返回是否加载成功。</returns>
    public bool Load_UserData_DB(string _userId, string _saveFileName)
    {
        if (string.IsNullOrWhiteSpace(_userId))
        {
            Debug.LogWarning("[DBCC_DataBase] userId is empty.");
            return false;
        }

        // 加载新账号前先停止旧账号计时, 防止旧用户体力继续在线恢复.
        Stop_UserRuntimeTick_DB();

        // 先根据账号ID和存档文件名计算当前账号的存档路径。
        savePath = Get_UserSavePath_DB(_userId, _saveFileName);
        if (string.IsNullOrWhiteSpace(savePath))
        {
            Debug.LogWarning("[DBCC_DataBase] Save path is empty.");
            return false;
        }

        // 这里只是确保存档所在目录存在, 不会创建存档文件本身。
        var saveDirectoryPath = Path.GetDirectoryName(savePath);
        if (!string.IsNullOrWhiteSpace(saveDirectoryPath))
        {
            Directory.CreateDirectory(saveDirectoryPath);
        }

        // 没有存档时创建默认新手存档, 否则直接读取旧存档。
        if (!File.Exists(savePath))
        {
            SaveData = Create_NewSaveData_DB(_userId);
            if (!Write_SaveDataFile_DB(SaveData))
            {
                return false;
            }
        }
        else if (!Try_LoadSaveDataFile_DB(_userId, out var loadedSaveData))
        {
            return false;
        }
        else
        {
            SaveData = loadedSaveData;
        }

        // 存档准备完成后, 立即重建当前账号的运行时数据。
        Init_GameData_DB();
        return true;
    }

    /// <summary>
    /// 根据认证结果准备当前账号数据。
    /// </summary>
    /// <param name="_authResult">认证结果。</param>
    /// <returns>返回数据是否准备完成。</returns>
    public bool Open_AuthenticatedUserData_DB(LocalAuthResult_Auth _authResult)
    {
        if (_authResult == null || !_authResult.Success || string.IsNullOrWhiteSpace(_authResult.UserId))
        {
            return false;
        }

        return Ensure_UserDataLoaded_DB(_authResult.UserId, _authResult.SaveFileName);
    }

    /// <summary>
    /// 确保指定账号的数据已经加载到运行时。
    /// </summary>
    /// <param name="_userId">账号唯一ID。</param>
    /// <param name="_saveFileName">存档文件名。</param>
    /// <returns>返回数据是否已就绪。</returns>
    public bool Ensure_UserDataLoaded_DB(string _userId, string _saveFileName)
    {
        // 检查当前账号数据是否已加载, 避免重复加载同一账号数据导致性能浪费或数据异常。
        if (Is_CurrentUserDataLoaded_DB(_userId))
        {
            return true;
        }

        return Load_UserData_DB(_userId, _saveFileName);
    }

    /// <summary>
    /// 只读读取指定账号的本地存档数据, 不切换当前运行时账号。
    /// </summary>
    /// <param name="_userId">账号唯一ID。</param>
    /// <param name="_saveFileName">账号存档文件名。</param>
    /// <param name="saveData">读取到的临时存档对象。</param>
    /// <returns>返回是否读取成功。</returns>
    public bool Try_ReadUserSaveData_DB(string _userId, string _saveFileName, out SaveData saveData)
    {
        saveData = null;

        // 排行榜只接受明确账号ID, 避免用空ID拼出错误的默认存档路径。
        if (string.IsNullOrWhiteSpace(_userId))
        {
            Debug.LogWarning("[DBCC_DataBase] 只读读取存档失败: userId为空。");
            return false;
        }

        // 使用DBCC统一的账号存档路径规则, 但不写入当前 savePath 字段。
        var readSavePath = Get_UserSavePath_DB(_userId, _saveFileName);
        if (!File.Exists(readSavePath))
        {
            Debug.LogWarning($"[DBCC_DataBase] 只读读取存档失败, 文件不存在: {readSavePath}");
            return false;
        }

        try
        {
            // 这里只做旁路读取, 不调用 Load_UserData_DB, 防止切换当前登录账号。
            var json = File.ReadAllText(readSavePath);
            if (string.IsNullOrWhiteSpace(json))
            {
                Debug.LogWarning($"[DBCC_DataBase] 只读读取存档失败, 文件内容为空: {readSavePath}");
                return false;
            }

            // 反序列化得到临时 SaveData, 不赋值给 DBCC_DataBase.SaveData。
            saveData = JsonConvert.DeserializeObject<SaveData>(json);
            if (saveData == null)
            {
                Debug.LogWarning($"[DBCC_DataBase] 只读读取存档失败, 解析结果为空: {readSavePath}");
                return false;
            }

            // 校验存档归属, 防止账号表和存档文件错配后进入排行榜。
            if (!string.IsNullOrWhiteSpace(saveData.userId) && !string.Equals(saveData.userId, _userId, StringComparison.Ordinal))
            {
                Debug.LogWarning($"[DBCC_DataBase] 只读读取存档失败, 目标账号: {_userId}, 存档账号: {saveData.userId}");
                saveData = null;
                return false;
            }

            // 兼容旧存档缺少 userId 的情况, 只补齐临时对象, 不回写磁盘。
            saveData.userId = _userId;
            return true;
        }
        catch (Exception exception)
        {
            Debug.LogWarning($"[DBCC_DataBase] 只读读取存档失败: {exception.Message}");
            saveData = null;
            return false;
        }
    }

    /// <summary>
    /// 判断当前是否已经加载指定账号数据。
    /// </summary>
    /// <param name="_userId">账号唯一ID。</param>
    /// <returns>返回当前账号数据是否已加载。</returns>
    public bool Is_CurrentUserDataLoaded_DB(string _userId)
    {
        return SaveData != null &&
               GameData != null &&
               !string.IsNullOrWhiteSpace(_userId) &&
               string.Equals(SaveData.userId, _userId, StringComparison.Ordinal) &&
               string.Equals(GameData.userId, _userId, StringComparison.Ordinal);
    }

    /// <summary>
    /// 判断当前是否存在已加载的账号数据。
    /// </summary>
    /// <returns>返回当前是否有账号数据。</returns>
    public bool Has_CurrentUserData_DB()
    {
        // 首次登录时SaveData和GameData都是Null
        return SaveData != null &&
               GameData != null &&
               !string.IsNullOrWhiteSpace(SaveData.userId);
    }

    /// <summary>
    /// 基于当前存档重建运行时游戏数据。
    /// </summary>
    public void Init_GameData_DB()
    {
        // 每次切换账号或重进流程时都重建一份全新的运行时数据。
        GameData = new GameData();
        if (SaveData == null)
        {
            Debug.LogWarning("[DBCC_DataBase] SaveData is null, skip GameData init.");
            return;
        }

        GameData.Init_GameData(SaveData);
    }

    /// <summary>
    /// 清理当前账号的运行时数据。
    /// </summary>
    public void Clear_CurrentUserData_DB()
    {
        // 先中断进行中的计时与异步保存, 再清空当前账号数据引用。
        Stop_UserRuntimeTick_DB();

        if (asyncSaveCoroutine != null)
        {
            StopCoroutine(asyncSaveCoroutine);
            asyncSaveCoroutine = null;
        }

        isAsyncSaving = false;
        SaveData = null;
        GameData = new GameData();
        savePath = GetEditorDesktopSavePath();
    }

    /// <summary>
    /// 按当前已加载账号尝试保存一次本地存档。
    /// </summary>
    public void Save_CurrentUserData_DB()
    {
        Save();
    }

    /// <summary>
    /// 保存并清理当前账号运行时数据。
    /// </summary>
    public void Close_CurrentUserData_DB()
    {
        Save_CurrentUserData_DB();
        Clear_CurrentUserData_DB();
    }

    /// <summary>
    /// 【核心】删除指定账号的本地存档文件。
    /// 流程: 1.停止当前运行时保存逻辑, 2.删除目标存档文件, 3.清理当前账号运行时数据。
    /// </summary>
    /// <param name="_userId">账号唯一ID。</param>
    /// <param name="_saveFileName">账号存档文件名。</param>
    /// <returns>返回是否删除成功。</returns>
    public bool Delete_UserData_DB(string _userId, string _saveFileName)
    {
        if (string.IsNullOrWhiteSpace(_userId))
        {
            Debug.LogError("[DBCC_DataBase] 删除账号存档失败: userId为空。");
            return false;
        }

        // 删除账号时不能调用 Save, 否则会把即将删除的数据重新写回磁盘。
        Stop_UserRuntimeTick_DB();
        if (asyncSaveCoroutine != null)
        {
            StopCoroutine(asyncSaveCoroutine);
            asyncSaveCoroutine = null;
        }

        isAsyncSaving = false;

        var deleteSavePath = Get_UserSavePath_DB(_userId, _saveFileName);
        try
        {
            if (File.Exists(deleteSavePath))
            {
                File.Delete(deleteSavePath);
            }

            // 如果删除的是当前已加载账号, 需要同步清理内存数据。
            if (Is_CurrentUserDataLoaded_DB(_userId))
            {
                Clear_CurrentUserData_DB();
            }

            return true;
        }
        catch (Exception exception)
        {
            Debug.LogError($"[DBCC_DataBase] 删除账号存档失败: {exception.Message}");
            return false;
        }
    }

    /// <summary>
    /// 创建新账号对应的默认存档数据。
    /// </summary>
    /// <param name="_userId">账号ID。</param>
    /// <returns>返回初始化后的新存档对象。</returns>
    SaveData Create_NewSaveData_DB(string _userId)
    {
        var newSaveData = new SaveData
        {
            userId = _userId
        };

        newSaveData.Init_NewSaveData();
        return newSaveData;
    }

    /// <summary>
    /// 读取指定账号的本地存档文件。
    /// </summary>
    /// <param name="_userId">账号ID。</param>
    /// <param name="loadedSaveData">读取到的存档对象。</param>
    /// <returns>返回是否读取成功。</returns>
    bool Try_LoadSaveDataFile_DB(string _userId, out SaveData loadedSaveData)
    {
        loadedSaveData = null;

        try
        {
            // 先读取并反序列化本地存档文件。
            var json = File.ReadAllText(savePath);
            loadedSaveData = JsonConvert.DeserializeObject<SaveData>(json);
            if (loadedSaveData == null)
            {
                Debug.LogError("[DBCC_DataBase] 存档解析失败。");
                return false;
            }

            // 校验当前存档的归属账号, 防止错误加载到其他玩家数据。
            if (!string.IsNullOrWhiteSpace(loadedSaveData.userId) && loadedSaveData.userId != _userId)
            {
                Debug.LogError($"[DBCC_DataBase] 存档归属异常, 目标账号: {_userId}, 存档账号: {loadedSaveData.userId}");
                loadedSaveData = null;
                return false;
            }

            loadedSaveData.userId = _userId;
            return true;
        }
        catch (Exception exception)
        {
            Debug.LogError($"[DBCC_DataBase] 读取存档失败: {exception.Message}");
            return false;
        }
    }

    /// <summary>
    /// 将当前存档对象写入本地文件。
    /// </summary>
    /// <param name="saveData">待保存的存档对象。</param>
    /// <returns>返回是否写入成功。</returns>
    bool Write_SaveDataFile_DB(SaveData saveData)
    {
        if (saveData == null || string.IsNullOrWhiteSpace(savePath))
        {
            return false;
        }

        try
        {
            // 写盘前补齐当前账号ID, 确保存档归属信息完整。
            saveData.userId = string.IsNullOrWhiteSpace(saveData.userId) ? GameData?.userId : saveData.userId;
            var saveDirectoryPath = Path.GetDirectoryName(savePath);
            if (!string.IsNullOrWhiteSpace(saveDirectoryPath))
            {
                Directory.CreateDirectory(saveDirectoryPath);
            }

            var json = JsonConvert.SerializeObject(saveData, Formatting.Indented);
            File.WriteAllText(savePath, json);
            return true;
        }
        catch (Exception exception)
        {
            Debug.LogError($"[DBCC_DataBase] 写入存档失败: {exception.Message}");
            return false;
        }
    }

    /// <summary>
    /// 生成账号专属存档文件路径。
    /// </summary>
    /// <param name="_userId">账号ID。</param>
    /// <param name="_saveFileName">指定存档文件名。</param>
    /// <returns>返回存档绝对路径。</returns>
    string Get_UserSavePath_DB(string _userId, string _saveFileName)
    {
        var saveFileName = string.IsNullOrWhiteSpace(_saveFileName) ? $"save_{_userId}.json" : _saveFileName;
        return Path.Combine(Get_SaveRootDirectory_DB(), saveFileName);
    }

    // ==========================================
    // 3. 存档流程
    // ==========================================

    /// <summary>
    /// 程序退出时尝试保存当前账号存档。
    /// </summary>
    void OnApplicationQuit()
    {
        Save();
        Stop_UserRuntimeTick_DB();
    }

    /// <summary>
    /// 统一保存当前账号的存档数据。
    /// </summary>
    public void Save()
    {
        if (SaveData == null || GameData == null || string.IsNullOrWhiteSpace(SaveData.userId) || string.IsNullOrWhiteSpace(savePath))
        {
            return;
        }

        // 同步保存前先终止正在执行的异步保存流程。
        if (asyncSaveCoroutine != null)
        {
            StopCoroutine(asyncSaveCoroutine);
            asyncSaveCoroutine = null;
        }

        Debug.Log("协程保存被打断，执行同步保存。");
        // 先把运行时数据回写到存档对象, 再落盘到本地文件。
        BuildSaveDataFromGameData();
        Write_SaveDataFile_DB(SaveData);
        Debug.Log("保存完毕!");
    }

    /// <summary>
    /// 启动协程异步保存当前账号存档。
    /// </summary>
    public void StartSaveCoroutine()
    {
        if (SaveData == null || GameData == null || string.IsNullOrWhiteSpace(SaveData.userId) || string.IsNullOrWhiteSpace(savePath))
        {
            return;
        }

        if (asyncSaveCoroutine == null)
        {
            asyncSaveCoroutine = StartCoroutine(SaveAsync());
        }
    }

    /// <summary>
    /// 启动当前账号的用户运行时计时。
    /// </summary>
    public void Start_UserRuntimeTick_DB()
    {
        if (SaveData == null || GameData == null || GameData.Sys_User == null)
        {
            return;
        }

        // 启动前先清理旧协程, 保证同一时间只有当前账号的一条 tick.
        Stop_UserRuntimeTick_DB();

        // 启动时先立即 tick 一次, 让 UI 进入当前秒的最新状态.
        GameData.Sys_User.Tick_Stamina_User(DateTime.UtcNow);
        userRuntimeTickCoroutine = StartCoroutine(UserRuntimeTickRoutine());
    }

    /// <summary>
    /// 停止当前账号的用户运行时计时。
    /// </summary>
    public void Stop_UserRuntimeTick_DB()
    {
        if (userRuntimeTickCoroutine == null)
        {
            return;
        }

        // 停止的是数据库托管的协程, 不直接修改 Sys_User 的业务状态.
        StopCoroutine(userRuntimeTickCoroutine);
        userRuntimeTickCoroutine = null;
    }

    /// <summary>
    /// 每秒驱动用户系统的运行时计时。
    /// </summary>
    /// <returns>返回协程枚举器。</returns>
    IEnumerator UserRuntimeTickRoutine()
    {
        while (true)
        {
            yield return new WaitForSeconds(1f);// 每秒驱动一次.

            if (SaveData == null || GameData == null || GameData.Sys_User == null)
            {
                // 当前账号数据被清理时自动退出, 防止空引用和旧账号残留 tick.
                userRuntimeTickCoroutine = null;
                yield break;
            }

            // 数据库只提供每秒驱动, 具体体力恢复判断交给 Sys_User.
            GameData.Sys_User.Tick_Stamina_User(DateTime.UtcNow);
        }
    }

    /// <summary>
    /// 协程方式异步保存当前账号存档。
    /// </summary>
    /// <returns>返回协程枚举器。</returns>
    IEnumerator SaveAsync()
    {
        if (isAsyncSaving)
        {
            yield break;
        }

        // 异步保存流程与同步保存保持一致: 先回写, 再写文件。
        isAsyncSaving = true;
        BuildSaveDataFromGameData();
        Write_SaveDataFile_DB(SaveData);
        Debug.Log("保存完毕!");

        isAsyncSaving = false;
        asyncSaveCoroutine = null;
    }

    // ==========================================
    // 4. GameData 转存档
    // ==========================================

    /// <summary>
    /// 【核心】将当前运行时数据回写到存档对象。
    /// </summary>
    public void BuildSaveDataFromGameData()
    {
        if (SaveData == null || GameData == null)
        {
            return;
        }

        // 先同步存档归属账号ID, 再分模块回写业务数据。
        SaveData.userId = GameData.userId;

        User_BuildSaveDataFromGameData();
        Chapter_BuildSaveDataFromGameData();
        Card_BuildSaveDataFromGameData();
        Dice_BuildSaveDataFromGameData();
        SaveData.SD_Items = GameData.Sys_Inventory.Export_ItemSaveData();
        SaveData.SD_Mall = GameData.Sys_Mall.Export_MallSaveData();
    }

    /// <summary>
    /// 回写用户基础数据。
    /// </summary>
    void User_BuildSaveDataFromGameData()
    {
        // 保存前先把内部体力推进到当前 UTC 时间, 再统一通过导出接口写回存档.
        GameData.Sys_User.Settle_StaminaToNow_User(DateTime.UtcNow);
        SaveData.SD_User = GameData.Sys_User.Export_UserSaveData();
    }

    /// <summary>
    /// 回写章节与关卡进度数据。
    /// </summary>
    void Chapter_BuildSaveDataFromGameData()
    {
        SaveData.SD_NormalChapters = GameData.Sys_Chapter.Export_NormalChapterSaveData();
        SaveData.selectedChapterIndex = GameData.Sys_Chapter.selectedChapterIndex;
        SaveData.currentChapterEntryState = GameData.Sys_Chapter.currentEntryState;
        Level currentLevel = GameData.Sys_Chapter.CurrentLevel;
        if (currentLevel != null && GameData.Sys_Chapter.currentChapter.level_List.Count > 0)
        {
            SaveData.currentLevelIndex = GameData.Sys_Chapter.currentChapter.level_List.IndexOf(currentLevel);
        }
    }

    /// <summary>
    /// 回写卡牌存档数据。
    /// </summary>
    void Card_BuildSaveDataFromGameData()
    {
        SaveData.SD_HeroCards = GameData.Sys_Card.Export_HeroCardSaveData();
    }

    /// <summary>
    /// 回写骰子存档数据。
    /// </summary>
    void Dice_BuildSaveDataFromGameData()
    {
        if (GameData.heroDiceDict == null)
        {
            return;
        }

        Dictionary<string, Dice> heroDiceDict = GameData.heroDiceDict;
        Dictionary<string, SaveData_Dices> SD_Dices = SaveData.SD_Dices;
        SD_Dices.Clear();
        foreach (KeyValuePair<string, Dice> kv in heroDiceDict)
        {
            string diceId = kv.Key;
            Dice dice = kv.Value;
            string diceID = dice.SO_Dice.diceId;
            int num = dice.getNum;
            bool isDiceFight = dice.isDiceFight;
            SaveData_Dices saveData_Dices = new SaveData_Dices(diceID, num, isDiceFight);
            SD_Dices[diceId] = saveData_Dices;
        }

        if (GameData.heroDiceFightList == null)
        {
            return;
        }

        List<Dice> heroDiceFightList = GameData.heroDiceFightList;
        List<SaveData_Dices> SD_FightDices = SaveData.SD_FightDices;
        SD_FightDices.Clear();
        for (int i = 0; i < heroDiceFightList.Count; i++)
        {
            Dice dice = heroDiceFightList[i];
            string diceID = dice.SO_Dice.diceId;
            int num = dice.getNum;
            bool isDiceFight = dice.isDiceFight;
            SaveData_Dices saveData_Dices = new SaveData_Dices(diceID, num, isDiceFight)
            {
                diceID = diceID,
                getNum = num,
                isDiceFight = isDiceFight
            };
            SD_FightDices.Add(saveData_Dices);
        }
    }
}
