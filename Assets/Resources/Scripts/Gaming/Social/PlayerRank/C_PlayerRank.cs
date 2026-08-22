using TMPro;
using UnityEngine;

/// <summary>
/// 负责单个排行榜条目的文本显示。
/// </summary>
public class C_PlayerRank : MonoBehaviour
{
    [Header("模块: 排行榜条目")]
    [Tooltip("排名文本")] public TMP_Text rankCount; // 排名文本
    [Tooltip("玩家名称与账号文本")] public TMP_Text playerInfoText; // 玩家名称与账号文本
    [Tooltip("账号价值文本")] public TMP_Text valueText; // 账号价值文本

    /// <summary>
    /// 刷新单个排行榜条目显示。
    /// </summary>
    /// <param name="playerRank">排行榜数据。</param>
    public void Refresh_Item_PlayerRank(PlayerRank playerRank)
    {
        // 条目没有数据时不刷新UI, 防止显示上一轮残留文本。
        if (playerRank == null)
        {
            Debug.LogWarning("[C_PlayerRank] playerRank 为空。");
            return;
        }

        // 排名文本单独赋值, 当前只显示数字, 装饰样式交给UI预制体处理。
        if (rankCount != null)
        {
            rankCount.text = playerRank.rankIndex.ToString();
        }
        else
        {
            Debug.LogWarning("[C_PlayerRank] rankCount 未绑定。");
        }

        // 玩家信息由玩家名称和账号名拼装: 勇者 : 20260414。
        if (playerInfoText != null)
        {
            playerInfoText.text = $"{playerRank.playerId} : {playerRank.accountId}";
        }
        else
        {
            Debug.LogWarning("[C_PlayerRank] playerInfoText 未绑定。");
        }

        // 第二行单独显示价值文本: 价值 12345。
        if (valueText != null)
        {
            valueText.text = $"价值 {playerRank.value}";
        }
        else
        {
            Debug.LogWarning("[C_PlayerRank] valueText 未绑定。");
        }
    }
}
