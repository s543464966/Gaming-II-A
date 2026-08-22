using System;
using System.Globalization;
using UnityEngine;

//======用户数据(资产/系统级状态)管理子系统======//
public class Sys_User
{
    public const string DefaultPlayerId = "勇者"; // 默认玩家名称
    const int staminaMaxValue = 100; // 体力上限
    const int staminaRecoverSeconds = 300; // 单点体力恢复秒数

    //====== 用户数据状态 ======//
    // 只读属性，确保外层不能随便改数值，只能通过系统方法调用
    public string playerId { get; private set; }
    public int stamina { get; private set; }
    public int staminaMax { get; private set; }
    public string staminaNextRecoveryTimeText { get; private set; }
    public string staminaFullRecoveryTimeText { get; private set; }
    public int gold { get; private set; }
    public int starStone { get; private set; }
    public bool isCompleted_NewLevel { get; private set; }
    public int playerDiceMax { get; private set; }
    public bool isAutoPlay { get; private set; }

    // --- 内部状态 --- //
    DateTime lastStaminaUpdateTimeUtc; // 最近体力结算时间
    int secondsUntilNextStamina; // 下一点体力剩余秒数
    int secondsUntilFullStamina; // 恢复满体力剩余秒数

    // ==========================================
    // 1. 广播事件大喇叭 (Action)
    // ==========================================
    public event Action<string> OnPlayerIdChanged;
    public event Action<int> OnStaminaChanged;
    public event Action<string, string> OnStaminaTimeChanged;
    public event Action<int> OnGoldChanged;
    public event Action<int> OnStarStoneChanged;

    // ==========================================
    // 2. 基底数仓构筑 (Initialize)
    // ==========================================

    /// <summary>
    /// 【核心】初始化用户系统数据
    /// 负责: 读取存档并赋给当前的系统数值 (体力/金币/骰上限)
    /// </summary>
    /// <param name="_SD_User">用户存档数据源</param>
    public void Init_Sys_User(SaveData_User _SD_User)
    {
        if (_SD_User == null)
        {
            // 兼容极端空存档输入, 保证用户系统仍可按默认值初始化.
            _SD_User = new SaveData_User();
        }

        // 先恢复存档里的基础状态, 缺失的旧存档字段使用当前版本默认值.
        staminaMax = staminaMaxValue;
        playerId = string.IsNullOrWhiteSpace(_SD_User.playerId) ? DefaultPlayerId : _SD_User.playerId;
        stamina = Mathf.Clamp(_SD_User.stamina, 0, staminaMax);
        gold = _SD_User.gold;
        starStone = _SD_User.starStone;
        isCompleted_NewLevel = _SD_User.isCompleted_NewLevel;
        playerDiceMax = _SD_User.playerDiceMax;
        isAutoPlay = _SD_User.isAutoPlay;
        lastStaminaUpdateTimeUtc = Parse_StaminaUpdateTime(_SD_User.lastStaminaUpdateTime, DateTime.UtcNow);

        // 初始化时立即结算离线体力, 让运行时数据进入当前时间点.
        Settle_StaminaToNow_User(DateTime.UtcNow);

        Debug.Log($"[Sys_User] 用户系统初始化完成。玩家:{playerId} 体力:{stamina} 金币:{gold} 骰子上限:{playerDiceMax}");
    }

    // ==========================================
    // 3. 通用资产划拨与状态机 (State & Currency)
    // ==========================================

    /// <summary>
    /// 【核心】切换自动战斗状态
    /// 负责: 刷新当前是否处于托管战斗状态
    /// </summary>
    /// <param name="_isAutoPlay">是否自动战斗</param>
    public void Set_AutoPlayState(bool _isAutoPlay)
    {
        isAutoPlay = _isAutoPlay;
        Debug.Log($"[Sys_User] 自动化状态已切换为: {isAutoPlay}");
    }

    /// <summary>
    /// 设置玩家名称
    /// 负责: 更新玩家显示名称并广播给界面
    /// </summary>
    /// <param name="_playerId">玩家名称</param>
    public void Set_PlayerId_User(string _playerId)
    {
        // 改名入口统一做空值兜底和首尾空格清理, 后续改名 UI 只需要调用这里.
        string newPlayerId = string.IsNullOrWhiteSpace(_playerId) ? DefaultPlayerId : _playerId.Trim();
        if (playerId == newPlayerId)
        {
            return;
        }

        playerId = newPlayerId;

        // 用户名变化通过事件驱动 UI, 避免界面层主动轮询.
        OnPlayerIdChanged?.Invoke(playerId);
    }

    /// <summary>
    /// 增加体力
    /// 负责: 先结算当前体力恢复进度, 再增加体力并刷新倒计时
    /// </summary>
    /// <param name="_amount">增加的体力值</param>
    public void Add_Stamina_User(int _amount)
    {
        if (_amount <= 0)
        {
            return;
        }

        DateTime currentUtcTime = DateTime.UtcNow;

        // 增加体力前先结算自然恢复, 防止道具或购买体力覆盖未领取的恢复进度.
        Settle_StaminaToNow_User(currentUtcTime);
        int oldStamina = stamina;
        stamina = Mathf.Clamp(stamina + _amount, 0, staminaMax);
        if (stamina >= staminaMax)
        {
            // 满体力时恢复进度归零, 下一次扣体力后从当前时间重新计时.
            lastStaminaUpdateTimeUtc = currentUtcTime;
        }

        Notify_StaminaChanged(oldStamina);
        Refresh_StaminaTime(currentUtcTime);
    }

    /// <summary>
    /// 扣除体力
    /// 负责: 先结算当前体力恢复进度, 再扣除体力并刷新倒计时
    /// </summary>
    /// <param name="_amount">扣除的体力值</param>
    public void Deduct_Stamina_User(int _amount)
    {
        if (_amount <= 0)
        {
            return;
        }

        DateTime currentUtcTime = DateTime.UtcNow;

        // 扣除体力前先结算自然恢复, 保证消耗基于最新体力值stamina.
        Settle_StaminaToNow_User(currentUtcTime);
        // 检查最新体力值是否满足扣除需求.
        if (stamina < _amount)
        {
            // 体力不足时直接拦截, 不消耗当前体力.
            return;
        }
        // 满足扣除条件时进行业务扣除.
        bool wasFullStamina = stamina >= staminaMax;
        int oldStamina = stamina;
        stamina = Mathf.Clamp(stamina - _amount, 0, staminaMax);
        if (wasFullStamina)
        {
            // 从满体力状态被扣除时, 恢复计时从扣除这一刻开始.
            lastStaminaUpdateTimeUtc = currentUtcTime;
        }

        Notify_StaminaChanged(oldStamina);
        Refresh_StaminaTime(currentUtcTime);
    }

    /// <summary>
    /// 每秒推进用户体力时间
    /// 负责: 结算在线恢复并广播倒计时
    /// </summary>
    /// <param name="_currentUtcTime">当前 UTC 时间</param>
    public void Tick_Stamina_User(DateTime _currentUtcTime)
    {
        // DBCC_DataBase 只负责每秒驱动, 真实恢复逻辑统一收敛在结算方法里.
        Settle_StaminaToNow_User(_currentUtcTime);
    }

    /// <summary>
    /// 【核心】将体力恢复状态结算到指定 UTC 时间
    /// 负责: 1.计算时间差, 2.恢复体力, 3.刷新下一点与回满倒计时
    /// </summary>
    /// <param name="_currentUtcTime">当前 UTC 时间</param>
    public void Settle_StaminaToNow_User(DateTime _currentUtcTime)
    {
        // 所有体力时间都转成 UTC, 避免本地时区变化影响恢复计算.
        DateTime currentUtcTime = Normalize_UtcTime(_currentUtcTime);
        if (lastStaminaUpdateTimeUtc == default)
        {
            // 旧存档没有时间戳时, 从当前时间开始计算, 不倒推发放体力.
            lastStaminaUpdateTimeUtc = currentUtcTime;
        }

        if (currentUtcTime < lastStaminaUpdateTimeUtc)
        {
            // 系统时间被回拨时重置基准时间, 防止出现负倒计时.
            lastStaminaUpdateTimeUtc = currentUtcTime;
            Refresh_StaminaTime(currentUtcTime);
            return;
        }

        int oldStamina = stamina;
        if (stamina >= staminaMax)
        {
            // 满体力不继续累计恢复进度, 倒计时固定为 00:00:00.
            stamina = staminaMax;
            lastStaminaUpdateTimeUtc = currentUtcTime;
            Refresh_StaminaTime(currentUtcTime);
            return;
        }
        // 体力值结算
        int elapsedSeconds = Mathf.FloorToInt((float)(currentUtcTime - lastStaminaUpdateTimeUtc).TotalSeconds);
        int recoveryCount = elapsedSeconds / staminaRecoverSeconds;
        // 体力未满时按恢复周期结算体力, 结算后剩余秒数继续累计到下一点恢复.
        if (recoveryCount > 0)
        {
            // 按完整恢复周期发放体力, 不足一个周期的秒数保留到下一次结算.
            int actualRecoveryCount = Mathf.Min(recoveryCount, staminaMax - stamina);
            stamina += actualRecoveryCount;

            if (stamina >= staminaMax)
            {
                // 恢复到满体力后清空进度, 下次扣除体力时重新开始计时.
                lastStaminaUpdateTimeUtc = currentUtcTime;
            }
            else
            {
                // 只推进已经兑换成体力的时间, 剩余秒数继续作为下一点恢复进度.
                int usedRecoverySeconds = actualRecoveryCount * staminaRecoverSeconds;
                lastStaminaUpdateTimeUtc = lastStaminaUpdateTimeUtc.AddSeconds(usedRecoverySeconds);
            }
        }

        Notify_StaminaChanged(oldStamina);
        Refresh_StaminaTime(currentUtcTime);
    }

    /// <summary>
    /// 检查货币是否足够
    /// 负责: 拦截不足额支付
    /// </summary>
    /// <param name="_type">货币类型</param>
    /// <param name="_amount">需要扣除的货币数量</param>
    /// <returns>布尔值，是否足够</returns>
    public bool Has_EnoughCurrency(CurrencyType _type, int _amount)
    {
        switch (_type)
        {
            case CurrencyType.Gold:
                return gold >= _amount;
            case CurrencyType.StarStone:
                return starStone >= _amount;
            default:
                return false;
        }
    }

    /// <summary>
    /// 扣除货币
    /// 负责: 1.检查货币是否足够, 2.扣除货币数值, 3.发送广播刷新UI
    /// </summary>
    /// <param name="_type">货币类型</param>
    /// <param name="_amount">需要扣除的货币数量</param>
    public void Deduct_Currency(CurrencyType _type, int _amount)
    {
        if (!Has_EnoughCurrency(_type, _amount)) return;

        switch (_type)
        {
            case CurrencyType.Gold:
                gold -= _amount;
                OnGoldChanged?.Invoke(gold); // 广播刷新金币
                break;
            case CurrencyType.StarStone:
                starStone -= _amount;
                OnStarStoneChanged?.Invoke(starStone); // 广播刷新星石
                break;
        }
    }

    /// <summary>
    /// 增加货币
    /// 负责: 1.增加对应货币数值, 2.发送广播刷新UI
    /// </summary>
    /// <param name="_type">货币类型</param>
    /// <param name="_amount">需要增加的货币数量</param>
    public void Add_Currency(CurrencyType _type, int _amount)
    {
        switch (_type)
        {
            case CurrencyType.Gold:
                gold += _amount;
                OnGoldChanged?.Invoke(gold); // 广播刷新金币
                break;
            case CurrencyType.StarStone:
                starStone += _amount;
                OnStarStoneChanged?.Invoke(starStone); // 广播刷新星石
                break;
        }
    }
    // ==========================================
    // 导出数据 API (自己打包)
    // ==========================================
    /// <summary>
    /// 导出需要保存的用户数据
    /// </summary>
    /// <returns>组装好的用户存档数据</returns>
    public SaveData_User Export_UserSaveData()
    {
        // 这里只打包当前运行时状态, 体力结算由保存编排在调用前完成.
        SaveData_User SD_User = new SaveData_User();
        SD_User.playerId = playerId;
        SD_User.stamina = stamina;
        SD_User.gold = gold;
        SD_User.starStone = starStone;
        SD_User.lastStaminaUpdateTime = lastStaminaUpdateTimeUtc.ToString("o");
        SD_User.isCompleted_NewLevel = isCompleted_NewLevel;
        SD_User.playerDiceMax = playerDiceMax;
        SD_User.isAutoPlay = isAutoPlay;
        return SD_User;
    }

    /// <summary>
    /// 解析体力结算时间，将存档里的string类型的时间转为DateTime类型的UTC时间
    /// </summary>
    /// <param name="staminaUpdateTime">存档中的体力结算时间</param>
    /// <param name="defaultUtcTime">默认 UTC 时间</param>
    /// <returns>返回可用的 UTC 时间</returns>
    DateTime Parse_StaminaUpdateTime(string staminaUpdateTime, DateTime defaultUtcTime)
    {
        // RoundtripKind 对应 ToString("o"), 用于保留 UTC 信息并兼容 Json 字符串.
        if (DateTime.TryParse(staminaUpdateTime, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind, out DateTime parsedTime))
        {
            return Normalize_UtcTime(parsedTime);
        }
        // 解析失败默认当前时间.
        return Normalize_UtcTime(defaultUtcTime);
    }

    /// <summary>
    /// 统一转换为 UTC 时间
    /// </summary>
    /// <param name="time">输入时间</param>
    /// <returns>返回 UTC 时间</returns>
    DateTime Normalize_UtcTime(DateTime time)
    {
        return time.Kind == DateTimeKind.Utc ? time : time.ToUniversalTime();
    }

    /// <summary>
    /// 刷新体力恢复倒计时
    /// </summary>
    /// <param name="currentUtcTime">当前 UTC 时间</param>
    void Refresh_StaminaTime(DateTime currentUtcTime)
    {
        if (stamina >= staminaMax)
        {
            // 满体力时不需要展示下一点或回满等待时间.
            Set_StaminaTime(0, 0);
            return;
        }

        // elapsedSeconds 表示从上次体力结算基准点到当前时间经过的总秒数.
        int elapsedSeconds = Mathf.Max(0, Mathf.FloorToInt((float)(currentUtcTime - lastStaminaUpdateTimeUtc).TotalSeconds));

        // progressSeconds 表示当前恢复周期里已经累计的秒数，相当于转换为体力后还累计多少秒数作为下一点体力的进度.
        int progressSeconds = elapsedSeconds % staminaRecoverSeconds;

        // nextSeconds 表示距离下一点体力恢复还需要等待的秒数.
        int nextSeconds = staminaRecoverSeconds - progressSeconds;

        // missingStamina 表示当前距离满体力还差多少点.
        int missingStamina = Mathf.Max(0, staminaMax - stamina);

        // fullSeconds 表示恢复满体力总剩余秒数, 包含下一点剩余时间和后续完整恢复周期.
        int fullSeconds = nextSeconds + Mathf.Max(0, missingStamina - 1) * staminaRecoverSeconds;

        // 统一写入内部状态并广播已经格式化好的 HH:MM:SS 文本.
        Set_StaminaTime(nextSeconds, fullSeconds);
    }

    /// <summary>
    /// 设置体力恢复倒计时并广播
    /// </summary>
    /// <param name="nextSeconds">下一点体力剩余秒数</param>
    /// <param name="fullSeconds">恢复满体力剩余秒数</param>
    void Set_StaminaTime(int nextSeconds, int fullSeconds)
    {
        // 内部状态更新为秒数, 对外广播已经格式化好的文本.
        secondsUntilNextStamina = nextSeconds;
        secondsUntilFullStamina = fullSeconds;
        // 格式化为 HH:MM:SS 文本, 供 UI 显示.
        staminaNextRecoveryTimeText = Format_StaminaTimeText(secondsUntilNextStamina);
        staminaFullRecoveryTimeText = Format_StaminaTimeText(secondsUntilFullStamina);

        // 时间刷新也通过事件推给 UI, UI 只接收已经处理好的 HH:MM:SS 文本.
        OnStaminaTimeChanged?.Invoke(staminaNextRecoveryTimeText, staminaFullRecoveryTimeText);
    }

    /// <summary>
    /// 格式化体力时间文本
    /// </summary>
    /// <param name="totalSeconds">总秒数</param>
    /// <returns>返回 HH:MM:SS 格式文本</returns>
    string Format_StaminaTimeText(int totalSeconds)
    {
        // 倒计时下限固定为 0, 防止异常时间差显示负数.
        totalSeconds = Mathf.Max(0, totalSeconds);
        int hours = totalSeconds / 3600;
        int minutes = totalSeconds % 3600 / 60;
        int seconds = totalSeconds % 60;
        return $"{hours:D2}:{minutes:D2}:{seconds:D2}";
    }

    /// <summary>
    /// 按需广播体力变化
    /// </summary>
    /// <param name="oldStamina">旧体力值</param>
    void Notify_StaminaChanged(int oldStamina)
    {
        // 当体力变化时才广播事件，避免不必要的UI刷新.
        if (oldStamina != stamina)
        {
            OnStaminaChanged?.Invoke(stamina);
        }
    }
}
