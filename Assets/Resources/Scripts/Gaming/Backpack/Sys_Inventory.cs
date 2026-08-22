using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

[System.Serializable] // 关键：加上它，GameData在Inspector里才能看见详情
public class Sys_Inventory  //仓库背包系统
{
    // --- 内部状态 --- (数据源)
    private GameData GameData => DBCC_DataBase.Instance.GameData; // GameData别名[因为单例原因]
    
    // ==========================================
    // 1. 数据核心 (Data Core)
    // ==========================================
    
    // --- 内部状态 --- (存放集合)
    // 推荐使用 List, 为了方便 Unity 序列化和 Inspector 查看
    [SerializeField] private List<Item> heroItemList = new List<Item>(); // 玩家所有物品数据结构列表

    // ==========================================
    // 2. 初始化 (Initial)
    // ==========================================
    
    /// <summary>
    /// 【核心】初始化仓库系统
    /// 负责: 1.清空当前物品列表, 2.遍历存档数据通过ID获取最新配置重建物品结构
    /// </summary>
    /// <param name="_SD_Items">外部传入的存档物品列表</param>
    public void Init_Sys_Inventory(List<SaveData_Item> _SD_Items)
    {
        heroItemList.Clear();
        // 遍历存档数据
        foreach (SaveData_Item _SD_Item in _SD_Items)
        {
            // 核心步骤：跨部门调用！
            // 去 GameData 的静态数据库里，根据 ID 查找对应的 SO_Item
            if (GameData.All_SO_Items.TryGetValue(_SD_Item.itemID, out SO_Item SO_Item))
            {
                // 找到配置了！
                // 创建运行时Item对象 (SO + 数量) 并加入列表
                Item newItem = new Item(SO_Item, _SD_Item.itemCount);
                heroItemList.Add(newItem);
            }
            else
            {
                // 没找到配置（可能是版本更新删除了该物品，或者是存档被篡改了）
                Debug.LogWarning($"[Sys_Inventory] 无法恢复物品,ID {_SD_Item.itemID} 在 All_SO_Items 中找不到！");
            }
        }

        Debug.Log("完成仓库系统数据初始化加载");
    }
    // ==========================================
    // 3. 核心 API (基础业务)
    // ==========================================

    /// <summary>
    /// 【核心】添加物品(无限堆叠逻辑)
    /// 负责: 1.查找是否拥有该ID物品, 2.若有则累加数量, 若无则创建新对象置入
    /// </summary>
    /// <param name="_id">物品SO资产唯一标识ID</param>
    /// <param name="_count">增加的数量</param>
    public void Add_Item(string _id, int _count)
    {
        if (_count <= 0) return;

        // 1. 查找是否已经拥有该物品 (通过 ID)
        // 注意：这里我们不再判断 maxStack，逻辑层允许 count 无限大
        Item existingItem = heroItemList.FirstOrDefault(i => i.SO_Item.itemId == _id);

        if (existingItem != null)
        {
            // A. 已有：直接在总数上累加
            existingItem.itemCount += _count;
            Debug.Log($"[背包] 已有物品 {existingItem.SO_Item.itemName}，数量增加到 {existingItem.itemCount}");
        }
        else
        {
            // B. 没有：去大数据库那里查 SO，创建新对象
            if (GameData.All_SO_Items.TryGetValue(_id, out SO_Item SO_Item))
            {
                Item newItem = new Item(SO_Item, _count);
                heroItemList.Add(newItem);
                Debug.Log($"[背包] 获得新物品 {SO_Item.itemName} x{_count}");
            }
            else
            {
                Debug.LogWarning($"[Sys_Inventory] 添加失败：找不到 ID 为 {_id} 的配置数据！");
            }
        }
    }
    /// <summary>
    /// 【核心】移除或消耗物品
    /// 负责: 1.查找是否存在该物品, 2.若存在且数量充足则扣除对应份额, 3.扣光时物理移除对象本身
    /// </summary>
    /// <param name="_id">物品SO唯一标识ID</param>
    /// <param name="_count">要消耗的数量</param>
    /// <returns>操作成功返回true, 数量不足或不存在返回false</returns>
    public bool Remove_Item(string _id, int _count)
    {
        //  查找物品
        Item existingItem = heroItemList.FirstOrDefault(i => i.SO_Item.itemId == _id);

        // 检查是否存在且数量足够
        if (existingItem != null && existingItem.itemCount >= _count)
        {
            existingItem.itemCount -= _count;

            // 如果扣光了，逻辑上直接移除该对象 (省内存)
            if (existingItem.itemCount <= 0)
            {
                heroItemList.Remove(existingItem);
            }
            return true;
        }

        Debug.LogWarning($"[背包] 移除失败：物品 {_id} 数量不足或不存在");
        return false;
    }
    /// <summary>
    /// 查询物品拥有数量
    /// 负责: 在整个仓库列表中寻找同ID物品, 若存在则返回内部数量属性
    /// </summary>
    /// <param name="_id">物品SO唯一标识ID</param>
    /// <returns>返回对应物品的具体数量值, 不存在返回0</returns>
    public int Get_ItemCount(string _id)
    {
        Item item = heroItemList.FirstOrDefault(i => i.SO_Item.itemId == _id);
        return item != null ? item.itemCount : 0;
    }
    /// <summary>
    /// 检查是否有足够的物品
    /// 负责: 验证当前系统内该物品的数量是否满足阈值, 常用于 UI 按钮状态判断
    /// </summary>
    /// <param name="_id">物品SO唯一标识ID</param>
    /// <param name="_count">需要比对的需求底线条</param>
    /// <returns>满足返回true, 不满足返回false</returns>
    public bool Has_Item(string _id, int _count = 1)
    {
        return Get_ItemCount(_id) >= _count;
    }
    /// <summary>
    /// 【核心】获取用于 UI 显示的物品列表
    /// 负责: 1.根据传入参数筛选大分类, 2.依据SO中的UI显示上限堆叠数拆分大数量对象
    /// </summary>
    /// <param name="_itemType">ItemType.None表示全部, 其他表示特定分类</param>
    /// <returns>返回处理并拆分完毕的临时物品UI展示列表</returns>
    public List<Item> Get_DisplayItemList(ItemType _itemType)
    {
        // 1. 新new一个存放筛选后的表
        List<Item> displayList = new List<Item>();

        // 2. 遍历仓库里的真实数据
        foreach (var realItem in heroItemList)
        {
            // --- 筛选逻辑 ---
            // 如果 _itemType 不是 None，且当前物品类型不匹配，则跳过
            if (_itemType != ItemType.None && realItem.SO_Item.itemType != _itemType)
            {
                continue; 
            }
            // --- 分堆逻辑 ---
            // 获取 UI 显示上限 (防止填 0 死循环)
            int uiStackLimit = realItem.SO_Item.maxStack > 0 ? realItem.SO_Item.maxStack : 1;
            int remainingCount = realItem.itemCount;

            // 循环拆分
            while (remainingCount > 0)
            {
                // 这次取多少？取 剩余量 和 上限 的较小值(满足格子)
                int countForGrid = Mathf.Min(remainingCount, uiStackLimit);

                // 创建一个"临时"物品对象传给 UI
                // 注意：这个对象只用于显示，不存入 heroItemList
                Item tempDisplayItem = new Item(realItem.SO_Item, countForGrid);
                displayList.Add(tempDisplayItem);

                remainingCount -= countForGrid;
            }
        }
        // --- 排序逻辑 (可选) ---
        // 比如按 ID 排序，保证拆分后的堆叠在一起
        // displayList.Sort((a, b) => a.SO_Item.itemId.CompareTo(b.SO_Item.itemId));

        return displayList;
    }
    /// <summary>
    /// 获取整个物品逻辑数据表
    /// 负责: 暴露内部的 List 给外部调用读取
    /// </summary>
    /// <returns>英雄持有物品全量列表</returns>
    public List<Item> Get_HeroItemList() => heroItemList;
    // ==========================================
    // 4. 拓展 API (高级业务逻辑)
    // ==========================================
    /// <summary>
    /// 【拓展】一键整理 (排序)
    /// </summary>
    // public void SortInventory()
    // {
    //     // 规则：先按类型排，再按 ID 排，再按数量排
    //     heroItemList = heroItemList
    //         .OrderBy(i => i.itemData.type)   //缺少类型
    //         .ThenBy(i => i.ID)
    //         .ThenByDescending(i => i.stackCount)
    //         .ToList();

    //     Debug.Log("[背包] 整理完成");
    // }

    // ==========================================
    // 5. 导出数据 API (自己打包)
    // ==========================================
    
    /// <summary>
    /// 【核心】导出所有的可存储物品数据
    /// 负责: 将运行时的 Item 对象精简提取成 ID 与 Count 的字典/列表存档内容
    /// </summary>
    /// <returns>精简化的存档物品数据列表</returns>
    public List<SaveData_Item> Export_ItemSaveData()
    {
        // 申请新空间来存储
        List<SaveData_Item> SD_Items = new List<SaveData_Item>();

        foreach (var item in heroItemList)
        {
            // 将运行时对象转为存档数据对象
            SaveData_Item saveData_Item = new SaveData_Item(item.SO_Item.itemId, item.itemCount);
            SD_Items.Add(saveData_Item);
        }
        // 返回背包系统数据
        return SD_Items;
    }
}
