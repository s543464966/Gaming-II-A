using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 负责排行榜页面刷新与条目生成。
/// </summary>
public class CC_PlayerRank : MonoBehaviour
{
    [Header("模块: 排行榜列表")]
    [Tooltip("排行榜条目父节点")] public Transform contentRoot; // 排行榜条目父节点
    [Tooltip("排行榜条目预制体")] public GameObject rankItemPrefab; // 排行榜条目预制体

    readonly List<C_PlayerRank> rankItemList = new List<C_PlayerRank>(); // 当前生成的排行榜条目
    readonly List<C_PlayerRank> rankItemPool = new List<C_PlayerRank>(); // 可复用的排行榜条目对象池
    bool isInitialized; // 是否已完成排行榜页面初始化

    /// <summary>
    /// 页面打开时刷新一次排行榜。
    /// </summary>
    void OnEnable()
    {
        // 页面被打开时刷新一次, 第一版不监听实时数据变化。
        Refresh_Rank_PlayerRank();
    }

    /// <summary>
    /// 页面关闭时清理已生成条目。
    /// </summary>
    void OnDisable()
    {
        // 页面关闭时回收动态条目, 避免频繁Destroy产生GC压力。
        Clear_RankItems_PlayerRank();
    }
    /// <summary>
    /// 【核心】初始化排行榜界面。
    /// 负责: 1.清理对象池缓存, 2.清除开发时残留在Content下的排行榜条目。
    /// </summary>
    public void Init_PagePlayerRank()
    {
        if (contentRoot == null)
        {
            Debug.LogWarning("[CC_PlayerRank] 初始化失败: contentRoot 未绑定。");
            return;
        }

        // 初始化时直接清空缓存列表, 避免对象池继续引用即将被销毁的开发残留对象。
        rankItemList.Clear();
        rankItemPool.Clear();

        // 清除编辑器开发阶段预留或测试生成后残留在Content下的所有子对象。
        foreach (Transform child in contentRoot)
        {
            Destroy(child.gameObject);
        }

        //isInitialized = true;
        Debug.Log("排行榜开发时残留对象清除!");
    }

    /// <summary>
    /// 刷新排行榜条目列表。
    /// </summary>
    public void Refresh_Rank_PlayerRank()
    {
        // if (!isInitialized)
        // {
        //     Init_PagePlayerRank();
        // }

        // 刷新前先清空旧条目, 保证列表内容完全来自本次读取结果。
        Clear_RankItems_PlayerRank();

        // contentRoot 和 rankItemPrefab 都由 Inspector 绑定, 缺失时不继续生成。
        if (contentRoot == null)
        {
            Debug.LogWarning("[CC_PlayerRank] contentRoot 未绑定。");
            return;
        }

        if (rankItemPrefab == null)
        {
            Debug.LogWarning("[CC_PlayerRank] rankItemPrefab 未绑定。");
            return;
        }

        // 从DBCC持有的排行榜系统读取数据, 页面层不直接读账号表或存档文件。
        var dataBase = DBCC_DataBase.Instance;
        if (dataBase == null || dataBase.Sys_PlayerRank == null)
        {
            Debug.LogWarning("[CC_PlayerRank] DBCC_DataBase 或 Sys_PlayerRank 缺失。");
            return;
        }

        var playerRanks = dataBase.Sys_PlayerRank.Get_RankList_PlayerRank();
        foreach (var playerRank in playerRanks)
        {
            // 每条排行榜数据对应一个当前激活的条目, 优先复用对象池实例。
            var rankItem = Create_RankItem_PlayerRank();
            if (rankItem == null)
            {
                continue;
            }

            // 条目脚本只负责自己的两个TMP_Text赋值。
            rankItem.Refresh_Item_PlayerRank(playerRank);
            rankItemList.Add(rankItem);
        }
    }

    /// <summary>
    /// 清理当前已生成的排行榜条目。
    /// </summary>
    public void Clear_RankItems_PlayerRank()
    {
        foreach (var rankItem in rankItemList)
        {
            if (rankItem != null)
            {
                // 回收时只隐藏对象, 保留实例供下次刷新复用。
                rankItem.gameObject.SetActive(false);
                if (contentRoot != null)
                {
                    rankItem.transform.SetParent(contentRoot, false);
                }
                rankItemPool.Add(rankItem);
            }
        }

        rankItemList.Clear();
    }

    /// <summary>
    /// 创建一个排行榜条目实例。
    /// </summary>
    /// <returns>返回条目脚本。</returns>
    C_PlayerRank Create_RankItem_PlayerRank()
    {
        C_PlayerRank rankItem;
        if (rankItemPool.Count > 0)
        {
            // 按先进先出复用条目, 保持第二次打开时仍按1,2,3的UI顺序刷新。
            rankItem = rankItemPool[0];
            rankItemPool.RemoveAt(0);
            rankItem.transform.SetParent(contentRoot, false);
            rankItem.gameObject.SetActive(true);
            return rankItem;
        }

        // 对象池为空时才实例化新条目, 并挂到ScrollView Content下。
        var rankItemObject = Instantiate(rankItemPrefab, contentRoot);
        rankItem = rankItemObject.GetComponent<C_PlayerRank>();
        if (rankItem == null)
        {
            // 预制体根节点没有条目脚本时销毁实例, 避免产生无法刷新的空条目。
            Debug.LogWarning("[CC_PlayerRank] rankItemPrefab 根节点缺少 C_PlayerRank 组件。");
            Destroy(rankItemObject);
        }

        return rankItem;
    }
}
