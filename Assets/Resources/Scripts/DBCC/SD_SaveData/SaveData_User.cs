using System;

//======用户专属存档数据======//
[Serializable]
public class SaveData_User
{
    public string playerId; // 玩家名称
    public int stamina; //体力
    public int gold;    //金钱
    public int starStone; //星石
    public string lastStaminaUpdateTime; // 最近体力结算时间
    public bool isCompleted_NewLevel; //新手关卡是否完成
    public int playerDiceMax;   //玩家骰子最大上限
    public bool isAutoPlay; //是否自动化
}
