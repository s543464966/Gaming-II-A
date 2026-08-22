using System;
using System.Collections.Generic;
using UnityEngine;

[System.Serializable]
public class Sys_Chapter
{
    // --- 内部状态 --- (数据源引用)
    private GameData GameData => DBCC_DataBase.Instance.GameData;

    // ==========================================
    // 1. 数据核心 (Data Core)
    // ==========================================

    //====== 章节字典 ======//
    Dictionary<int, Chapter> normalChapterDict = new Dictionary<int, Chapter>();     // 普通难度章节字典
    Dictionary<int, Chapter> _hardChapterDict = new Dictionary<int, Chapter>(); // 困难难度章节字典
    Dictionary<int, Chapter> _hellChapterDict = new Dictionary<int, Chapter>(); // 地狱难度章节字典

    //====== 运行时导航状态 ======//
    public int currentChapterIndex;    // 当前正在浏览的章节索引
    public int selectedChapterIndex;   // 确认选择的章节索引
    public Chapter currentChapter;     // 当前选中的章节数据
    public Dictionary<int, Chapter> currentChapterDict; // 当前选中的难度章节
    public ChapterEntryState currentEntryState = ChapterEntryState.NodeContent; // 当前章节入口恢复状态

    //====== 当前关卡属性 ======//
    Level _currentLevel; // 当前对战关卡（内部持有）

    /// <summary>
    /// 当前对战关卡的属性访问器
    /// 负责: 读写当前关卡，set 时同步派发 OnCurrentLevelChanged 事件通知订阅者
    /// </summary>
    public Level CurrentLevel
    {
        get => _currentLevel;
        set
        {
            _currentLevel = value;
            OnCurrentLevelChanged?.Invoke(_currentLevel);
        }
    }

    // ==========================================
    // 2. 事件总线 (Event Bus)
    // ==========================================

    /// <summary>
    /// 主页章节轮转事件
    /// 当玩家在主页左右切换浏览章节时触发，UI层可订阅此事件进行刷新
    /// </summary>
    public event Action<Chapter> OnChapterChangedEvent;

    /// <summary>
    /// 当前关卡变更事件
    /// 当 CurrentLevel 属性被赋值时触发，供关注当前关卡状态的模块订阅
    /// </summary>
    public event Action<Level> OnCurrentLevelChanged;

    // ==========================================
    // 3. 初始化 (Initialization)
    // ==========================================

    /// <summary>
    /// 【核心】初始化章节系统
    /// 负责: 1.遍历 All_SO_Chapters 与存档对比构建章节字典, 2.有存档的章节加载怪物并恢复关卡路线,
    ///       3.恢复玩家上次的章节选择与当前关卡指针
    /// </summary>
    /// <param name="_saveData">基础存储数据传入对象</param>
    public void Init_Sys_Chapter(SaveData _saveData)
    {
        normalChapterDict.Clear();  //到时这里将每个章节都进行初始化，或者按需初始化

        // 1. 遍历所有静态 SO_Chapter（由 GameData.LoadAllSO 统一填充）
        foreach (var kvp in GameData.All_SO_Chapters)
        {
            SO_Chapter SO_Chapter = kvp.Value;
            Chapter chapter;

            // 2. 查存档，判断该章节是否有进度记录
            if (_saveData.SD_NormalChapters.TryGetValue(SO_Chapter.chapterIndex, out SaveData_Chapter saveDataChapter))
            {
                chapter = new Chapter(SO_Chapter, saveDataChapter.isUnlocked);
                chapter.isCompleted = saveDataChapter.isCompleted;

                // 若存有关卡路线数据，则先补全怪物 SO 再复原路线
                if (saveDataChapter.saveData_Levels_Route != null && saveDataChapter.saveData_Levels_Route.Count > 0)
                {
                    Load_ChapterMonsterSO(chapter);
                    Restore_LevelRoute(saveDataChapter.saveData_Levels_Route, chapter);
                }
            }
            else
            {
                // 无存档 → 默认未解锁章节
                chapter = new Chapter(SO_Chapter, false);
            }

            normalChapterDict[SO_Chapter.chapterIndex] = chapter;
        }

        // 3. 恢复章节选择指针
        selectedChapterIndex = _saveData.selectedChapterIndex;
        currentChapterIndex  = _saveData.selectedChapterIndex;
        currentChapter = normalChapterDict[_saveData.selectedChapterIndex];
        currentChapterDict = normalChapterDict; //默认先在普通难度，后续如果有其他难度的章节，这里需要根据存档记录的选择难度来确定当前章节字典
        currentEntryState = _saveData.currentChapterEntryState;// 恢复章节入口状态。

        // 4. 恢复当前关卡指针（关卡列表非空才恢复）
        if (currentChapter.level_List.Count > 0)
        {
            CurrentLevel = currentChapter.level_List[_saveData.currentLevelIndex];
        }

        Debug.Log("完成章节系统初始化");
    }

    // ==========================================
    // 4. 数据加载辅助 (Data Helpers)
    // ==========================================

    /// <summary>
    /// 【核心】加载指定章节的怪物 SO 数据
    /// 负责: 1.从 Resources 路径拉取该章节 SO_Card 列表, 2.按 cardType (M/Me/Mb) 分类填入章节预选池
    /// </summary>
    /// <param name="_chapter">目标执行的章节宿主</param>
    public void Load_ChapterMonsterSO(Chapter _chapter)
    {
        string fileMonster = _chapter.SO_Chapter.file_Monster;
        SO_Card[] monsters = Resources.LoadAll<SO_Card>($"Card/{fileMonster}");

        Debug.Log("章节" + _chapter.SO_Chapter.chapterIndex + "的怪物种类有" + monsters.Length);

        foreach (SO_Card monster in monsters)
        {
            switch (monster.cardType)
            {
                case "M":  _chapter.SO_Monsters_List.Add(monster); break;
                case "Me": _chapter.SO_MonstersElite_List.Add(monster); break;
                case "Mb": _chapter.SO_MonstersBoss = monster; break;
                default:
                    Debug.LogWarning($"未知卡牌类型：{monster.cardType}，卡牌未分类！");
                    break;
            }
        }
    }

    /// <summary>
    /// 【核心】创建新章节的随机关卡图谱
    /// 负责: 1.加载章节怪物 SO, 2.通过外部委托调用随机地图生成器（解耦 MonoBehaviour 依赖）
    /// </summary>
    /// <param name="_chapter">操作涉及的目标章节宿主包</param>
    /// <param name="_generateAction">外部传入的随机地图生成逻辑委托</param>
    public void Create_ChapterMaps(Chapter _chapter, Action<Chapter> _generateAction)
    {
        Load_ChapterMonsterSO(_chapter);
        _generateAction?.Invoke(_chapter);
    }

    /// <summary>
    /// 【核心】章节关卡路线数据复原
    /// 负责: 1.根据存档恢复每个关卡的状态与 Icon, 2.重新映射同层/前层/后层连接关系, 3.恢复道路 Sprite 引用
    /// </summary>
    /// <param name="_saveData_Levels_Route">存档中的关卡路线数据</param>
    /// <param name="_chapter">当前操作的章节引用</param>
    void Restore_LevelRoute(List<SaveData_Level> _saveData_Levels_Route, Chapter _chapter)
    {
        List<Level> level_List = _chapter.level_List;

        // --- 第一遍：逐条还原关卡基础数据 ---
        for (int i = 0; i < _saveData_Levels_Route.Count; i++)
        {
            SaveData_Level SD_Level = _saveData_Levels_Route[i];
            if (SD_Level == null) { level_List.Add(null); continue; }

            List<string> monsterDiceList = new List<string>(SD_Level.monsterDiceList);
            Level level = new Level(SD_Level.monsterCount, monsterDiceList, SD_Level.staminaCost);

            level.levelType      = SD_Level.levelType;
            level.levelStar      = SD_Level.levelStar;
            level.isMakeSelected = SD_Level.isMakeSelected;
            level.levelrRoadStatus = SD_Level.levelRoadStatus;

            // 解锁 / 选择 / 完成状态 → 决定 Icon
            if (SD_Level.isUnlocked)
            {
                level.isUnlocked = true;
                if (SD_Level.isSelected)
                {
                    level.isSelected = true;
                    level.levelTypeIcon = SD_Level.isCompleted ? _chapter.Level_Monster_Pass : _chapter.Level_Monster_Ready;
                    level.isCompleted   = SD_Level.isCompleted;
                }
                else
                {
                    if (SD_Level.isBeforeSelecting)
                    {
                        level.isBeforeSelecting = true;
                        level.levelTypeIcon = _chapter.Level_Monster_Ready;
                    }
                    else
                    {
                        level.levelTypeIcon = _chapter.Level_Monster_Not;
                    }
                }
            }
            else
            {
                level.levelTypeIcon = _chapter.Level_Unknown;
            }

            // 恢复怪物 SO 列表
            foreach (string monsterId in SD_Level.monsterSO_List)
            {
                Restore_MonsterSO(_chapter, level, monsterId);
            }

            level_List.Add(level);
        }

        // --- 第二遍：映射层间引用 + 道路 Sprite ---
        for (int i = 0; i < _saveData_Levels_Route.Count; i++)
        {
            SaveData_Level SD_Level = _saveData_Levels_Route[i];
            if (SD_Level == null) continue;
            Level level = level_List[i];

            if (SD_Level.sameLayer != null)
            {
                List<Level> sameLayer = new List<Level>();
                foreach (int index in SD_Level.sameLayer) sameLayer.Add(level_List[index]);
                level.sameLayer = sameLayer;
            }
            if (SD_Level.nextLayer != null)
                foreach (int index in SD_Level.nextLayer) level.nextLayer.Add(level_List[index]);
            if (SD_Level.beforeLayer != null)
                foreach (int index in SD_Level.beforeLayer) level.beforeLayer.Add(level_List[index]);

            // 恢复道路 Sprite
            List<Sprite> levelRoad = level.levelrRoad;
            for (int j = 0; j < SD_Level.levelRoadSpriteStatus.Count; j++)
            {
                if (SD_Level.levelRoadSpriteStatus[j] == 0) continue; // 无路，跳过

                if (SD_Level.isCompleted)
                {
                    if (SD_Level.isMakeSelected)
                    {
                        if (j == 1)
                            levelRoad[j] = SD_Level.levelRoadStatus[j] == 0 ? _chapter.Level_ConnectLine_x_Off : _chapter.Level_ConnectLine_x_On;
                        else
                            levelRoad[j] = SD_Level.levelRoadStatus[j] == 0 ? _chapter.Level_ConnectLine_xy_Off : _chapter.Level_ConnectLine_xy_On;
                    }
                    else
                    {
                        levelRoad[j] = j == 1 ? _chapter.Level_ConnectLine_x_On : _chapter.Level_ConnectLine_xy_On;
                    }
                }
                else
                {
                    levelRoad[j] = j == 1 ? _chapter.Level_ConnectLine_x_Off : _chapter.Level_ConnectLine_xy_Off;
                }
            }
        }
    }

    /// <summary>
    /// 辅助方法：根据怪物 ID 在章节怪物池中查找 SO_Card 并加入关卡
    /// 负责: 遍历章节的普通/精英/Boss 怪物列表查找匹配 ID，找到后添加进关卡怪物列表
    /// </summary>
    /// <param name="_chapter">当前章节（怪物资源池来源）</param>
    /// <param name="_level">目标关卡（接收怪物 SO）</param>
    /// <param name="_monsterId">怪物卡牌 ID</param>
    void Restore_MonsterSO(Chapter _chapter, Level _level, string _monsterId)
    {
        foreach (SO_Card SO_Card in _chapter.SO_Monsters_List)
        {
            if (SO_Card.cardId == _monsterId) { _level.Add_MonsterSO(SO_Card); return; }
        }
        foreach (SO_Card SO_Card in _chapter.SO_MonstersElite_List)
        {
            if (SO_Card.cardId == _monsterId) { _level.Add_MonsterSO(SO_Card); return; }
        }
        if (_chapter.SO_MonstersBoss != null && _chapter.SO_MonstersBoss.cardId == _monsterId)
            _level.Add_MonsterSO(_chapter.SO_MonstersBoss);
    }

    // ==========================================
    // 5. 对外读取 API (Accessors)
    // ==========================================

    /// <summary>
    /// 获取当前章节字典
    /// 负责: 暴露内部章节字典供 UI 和 DBCC_DataBase 使用
    /// </summary>
    /// <returns>普通难度章节字典（只读引用）</returns>
    public Dictionary<int, Chapter> Get_CurrentChapterDict() => currentChapterDict;

    /// <summary>
    /// 【核心】确保当前章节存在可进入的当前关卡
    /// </summary>
    /// <returns>是否成功确保当前关卡可用</returns>
    public bool Ensure_CurrentLevelReady()
    {
        // 当前章节或路线数据缺失时, 入口层不能继续定位关卡。
        if (currentChapter == null || currentChapter.level_List == null || currentChapter.level_List.Count == 0)
        {
            return false;
        }

        // 已存在当前关卡时直接复用, 避免覆盖失败后保留的未完成节点。
        if (CurrentLevel != null)
        {
            return true;
        }

        // 新章节首次进入时默认定位第一关。
        Level firstLevel = currentChapter.level_List[0];
        if (firstLevel == null)
        {
            return false;
        }

        // 第一关作为章节入口节点, 默认解锁并进入节点内容页。
        firstLevel.isUnlocked = true;
        firstLevel.isSelected = true;
        CurrentLevel = firstLevel;
        currentEntryState = ChapterEntryState.NodeContent;
        return true;
    }

    // ==========================================
    // 6. 玩家翻页操作 (Navigation)
    // ==========================================

    /// <summary>
    /// 【核心】玩家操控：向左划页(降序)
    /// 负责: 推进向低级章节轮转查阅，验证越界，并派发刷新事件
    /// </summary>
    public void Turn_BeforeChapter()
    {
        if (currentChapterIndex <= 1) return; // 到最低关卡了

        currentChapterIndex--;  //这里后续如果有其他难度的章节的话，需要用当前选择章节来做，当前选择章节就需要确定和记录了
        currentChapter = normalChapterDict[currentChapterIndex];
        OnChapterChangedEvent?.Invoke(currentChapter);
    }

    /// <summary>
    /// 【核心】玩家操控：向右划页(升序)
    /// 负责: 推进向高级章节轮转查阅，验证越界，并派发刷新事件
    /// </summary>
    public void Turn_AfterChapter()
    {
        if (currentChapterIndex >= normalChapterDict.Count) return; // 到最高关卡了

        currentChapterIndex++;
        currentChapter = normalChapterDict[currentChapterIndex];
        OnChapterChangedEvent?.Invoke(currentChapter);
    }

    /// <summary>
    /// 【核心】玩家操控：确认章节
    /// 负责: 将当前检视焦点转作强制记录，供后续进入关卡使用
    /// </summary>
    public void Confirm_ChapterSelection()
    {
        selectedChapterIndex = currentChapterIndex;
        currentChapter = normalChapterDict[selectedChapterIndex];
        currentChapterDict = normalChapterDict; //这个需要到时设计到切换难度那里，同时在初始化激活的时候默认在普通难度
        currentEntryState = ChapterEntryState.NodeContent;
    }

    // ==========================================
    // 7. 节点交互 (Node Interactions)
    // ==========================================

    /// <summary>
    /// 【核心】响应战局地图的节点点击
    /// 负责: 1.纯数据层面的排他性标记与记录, 2.路标连线数据的修改, 3.精准抛射对应节点的脏渲染触发广播
    /// </summary>
    /// <param name="_selectedLevel">被操控锁焦点选的主从Level节点</param>
    public void Process_LevelSelected(Level _selectedLevel)
    {
        // 1. 更新最新的数据给到游戏运行中枢
        CurrentLevel = _selectedLevel;
        currentEntryState = ChapterEntryState.NodeContent;
        Chapter chapter = currentChapter;

        // 2. 跳过自己，置灰同层其他关卡（纯数据修改）
        foreach (var sameLayer in _selectedLevel.sameLayer)
        {
            if (sameLayer == null) continue;

            if (sameLayer == _selectedLevel)
            {
                sameLayer.isSelected = true;
                sameLayer.isBeforeSelecting = false;
            }
            else
            {
                sameLayer.levelTypeIcon = chapter.Level_Monster_Not;
                sameLayer.isBeforeSelecting = false;
            }
            // 告知其他层级关卡节点刷新UI。
            sameLayer.OnLevelStateChangedEvent?.Invoke();
        }

        // 3. 找到上一关，置灰其他未被选中的路线（纯数据修改）
        foreach (var beforeLayer in _selectedLevel.beforeLayer)
        {
            if (beforeLayer == null) continue;
            if (beforeLayer.isCompleted == true)
            {
                // -- 核心重构：移除 transform 比对，采用拓扑比对 --
                // 找出选中的节点在 beforeLayer.nextLayer 中的 index 
                // 我们知道 nextLayer 中最多 3 个元素 (左, 中, 右)
                // 原代码：如果选中的关卡 x在右边->2，x在中间->1，x在左边->0
                int selectedIndexInBeforeNext = beforeLayer.nextLayer.IndexOf(_selectedLevel);

                // 重置当前路线，并在对应索引位置标注已选(1)
                beforeLayer.levelrRoadStatus[0] = 0;
                beforeLayer.levelrRoadStatus[1] = 0;
                beforeLayer.levelrRoadStatus[2] = 0;

                if (selectedIndexInBeforeNext >= 0 && selectedIndexInBeforeNext < 3)
                    beforeLayer.levelrRoadStatus[selectedIndexInBeforeNext] = 1;

                Update_LevelRoadSprite(beforeLayer, chapter);

                beforeLayer.isMakeSelected = true;
                // 告知其他层级关卡节点刷新UI。
                beforeLayer.OnLevelStateChangedEvent?.Invoke();
            }
        }
    }

    /// <summary>
    /// 【核心】处理关卡成功或失败后的章节数据结算
    /// 负责: 失败时恢复章节入口状态, 胜利时标记已通过节点、点亮路线并解锁下一层节点
    /// </summary>
    /// <param name="_levelResult">通关成功/失败判定凭据</param>
    public void Process_CompletedLevel(LevelCompletionResult _levelResult)
    {
        // 根据战斗结果分流章节数据处理, 失败不推进路线。
        switch (_levelResult)
        {
            case LevelCompletionResult.Defeat:
                // 失败后保留当前未完成节点, 下次进入可继续挑战。
                currentEntryState = ChapterEntryState.NodeContent;
                return;
            case LevelCompletionResult.Victory:
                break;
            default:
                Debug.LogWarning($"未知关卡结算结果：{_levelResult}，忽略通关处理。");
                return;
        }

        // 胜利后回到路线选择态, 供玩家继续选择下一层节点。
        currentEntryState = ChapterEntryState.RouteSelection;
        CurrentLevel.levelTypeIcon = currentChapter.Level_Monster_Pass;
        CurrentLevel.isCompleted   = true;
        CurrentLevel.levelrRoadStatus = new List<int> { 1, 1, 1 };
        Update_LevelRoadSprite(CurrentLevel, currentChapter);
        // 通知当前层节点 UI 自己已变更
        CurrentLevel.OnLevelStateChangedEvent?.Invoke();

        Debug.Log("完成关卡");

        // 解锁下一层可选节点, 等待玩家在路线页选择后续路线。
        foreach (var nextLayer in CurrentLevel.nextLayer)
        {
            nextLayer.levelTypeIcon = currentChapter.Level_Monster_Ready;
            nextLayer.isUnlocked    = true;
            nextLayer.isBeforeSelecting = true;
            // 通知下一层节点 UI 自己已变更
            nextLayer.OnLevelStateChangedEvent?.Invoke();
        }
    }

    // ==========================================
    // 8. 导出存档 API (Export)
    // ==========================================

    /// <summary>
    /// 【核心】导出所有章节的可存储数据
    /// 负责: 遍历内部章节字典，将运行时 Chapter 对象转换为 SaveData_Chapter 存档结构并打包返回
    /// </summary>
    /// <returns>普通难度章节存档字典，供 DBCC_DataBase 写盘使用</returns>
    public Dictionary<int, SaveData_Chapter> Export_NormalChapterSaveData()
    {
        Dictionary<int, SaveData_Chapter> SD_NormalChapters = new Dictionary<int, SaveData_Chapter>();

        foreach (var kvp in normalChapterDict)
        {
            Chapter chapter = kvp.Value;
            int chapterIndex = chapter.SO_Chapter.chapterIndex;

            SaveData_Chapter saveData_Chapter = new SaveData_Chapter(chapterIndex, chapter.isUnlocked, chapter.isCompleted);
            saveData_Chapter.saveData_Levels_Route = Convert_LevelsToSaveData(chapter.level_List);
            SD_NormalChapters[chapterIndex] = saveData_Chapter;
        }

        return SD_NormalChapters;
    }

    /// <summary>
    /// 辅助：将运行时关卡列表转换为可序列化的存档列表
    /// 负责: 遍历关卡对象，提取状态、路线、怪物等信息转化为纯数据结构
    /// </summary>
    /// <param name="_levelList">运行时关卡列表</param>
    /// <returns>可序列化的 SaveData_Level 列表</returns>
    List<SaveData_Level> Convert_LevelsToSaveData(List<Level> _levelList)
    {
        List<SaveData_Level> saveData_Levels_Route = new List<SaveData_Level>();
        if (_levelList.Count == 0) return saveData_Levels_Route;

        for (int i = 0; i < _levelList.Count; i++)
        {
            Level level = _levelList[i];
            if (level == null) { saveData_Levels_Route.Add(null); continue; }

            SaveData_Level saveData_Level = new SaveData_Level();
            saveData_Level.isCompleted = level.isCompleted;
            saveData_Level.isSelected = level.isSelected;
            saveData_Level.isUnlocked = level.isUnlocked;
            saveData_Level.isMakeSelected = level.isMakeSelected;
            saveData_Level.isBeforeSelecting = level.isBeforeSelecting;
            saveData_Level.levelType = level.levelType;
            saveData_Level.levelStar = level.levelStar;
            saveData_Level.staminaCost = level.staminaCost;
            saveData_Level.monsterCount = level.monsterCount;
            saveData_Level.levelRoadStatus = level.levelrRoadStatus;

            // 怪物 SO -> ID 列表
            saveData_Level.monsterSO_List = new List<string>();
            foreach (SO_Card m in level.monsterSO_List) saveData_Level.monsterSO_List.Add(m.cardId);

            // 骰子
            saveData_Level.monsterDiceList = new List<string>(level.monsterDiceList);

            // 道路有无状态（Sprite 是否为 null → 1/0）
            saveData_Level.levelRoadSpriteStatus = new List<int>();
            foreach (Sprite sprite in level.levelrRoad)
                saveData_Level.levelRoadSpriteStatus.Add(sprite == null ? 0 : 1);

            // 层间引用 → 索引
            if (level.sameLayer != null)
            {
                saveData_Level.sameLayer = new List<int>();
                foreach (Level s in level.sameLayer) saveData_Level.sameLayer.Add(_levelList.IndexOf(s));
            }
            if (level.nextLayer != null)
            {
                saveData_Level.nextLayer = new List<int>();
                foreach (Level n in level.nextLayer) saveData_Level.nextLayer.Add(_levelList.IndexOf(n));
            }
            if (level.beforeLayer != null)
            {
                saveData_Level.beforeLayer = new List<int>();
                foreach (Level b in level.beforeLayer) saveData_Level.beforeLayer.Add(_levelList.IndexOf(b));
            }

            saveData_Levels_Route.Add(saveData_Level);
        }

        return saveData_Levels_Route;
    }

    // ==========================================
    // 9. 内部计算辅助 (Internal Helpers)
    // ==========================================

    /// <summary>
    /// 辅助拆解计算单节点的三线绘制响应贴图
    /// 负责: 基于标记集配置渲染不同组合下的实/虚引线
    /// </summary>
    /// <param name="_level">目标关卡节点</param>
    /// <param name="_chapter">章节资源提供者</param>
    void Update_LevelRoadSprite(Level _level, Chapter _chapter)
    {
        for (int i = 0; i < _level.levelrRoad.Count; i++)
        {
            if (_level.levelrRoad[i] == null) continue; // 没路直接跳过不处理

            if (i == 1) // 特殊处理中间位置
            {
                if (_level.levelrRoadStatus[i] == 0) _level.levelrRoad[i] = _chapter.Level_ConnectLine_x_Off;
                else _level.levelrRoad[i] = _chapter.Level_ConnectLine_x_On;
            }
            else
            {
                if (_level.levelrRoadStatus[i] == 0) _level.levelrRoad[i] = _chapter.Level_ConnectLine_xy_Off;
                else _level.levelrRoad[i] = _chapter.Level_ConnectLine_xy_On;
            }
        }
    }
}
