using System.Collections;
using System.Collections.Generic;
using System.Linq;
using DG.Tweening;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class CC_Chapter : MonoBehaviour
{
    //设定必要数据与组件
    private GameData GameData => DBCC_DataBase.Instance.GameData;   //GameData别名[因为单例原因]
    private SaveData SaveData => DBCC_DataBase.Instance.SaveData;   //SaveData简写
    //模块：Chapter
    private SO_Chapter[] all_SO_Chapters;
    Dictionary<int, Chapter> chapterDict;   //章节序列字典

    //模块：RandomMaps
    [HideInInspector] private Chapter_RandomGenerateLevelMaps Chapter_RandomGenerateLevelMaps;
    // 章节页面控制的UI对象



    // ----------------------------------------------------------------------------------------------------------

    //模块：Initial - 初始化
    // public void Init_Chapter() //初始化章节
    // {
    //     //初始化和获取必要数据
    //     chapterDict = new Dictionary<int, Chapter>();
    //     Chapter_RandomGenerateLevelMaps = GetComponent<Chapter_RandomGenerateLevelMaps>();

    //     //加载所有章节的固定SO数据 和 DBCC中关于Chapter的SaveData:
    //     all_SO_Chapters = Resources.LoadAll<SO_Chapter>("Chapter"); //不会加载非 SO_Chapter 类型的文件，也不会自动递归子文件夹，只会把Chapter文件夹下单层的SO_Chapter文件加载进来
    //     if (all_SO_Chapters == null) { Debug.LogError("未找到章节SO_Chapter: 请检查文件路径: Chapter"); }
    //     Dictionary<int, SaveData_Chapter> SD_Chapters = SaveData.SD_NormalChapters; //章节1~N;

    //     //初始化所有Chapter章节，并按章节序号生成字典，为其赋予SD和SO数据
    //     foreach (SO_Chapter _all_SO_Chapter in all_SO_Chapters)
    //     {
    //         Chapter chapter = null;

    //         //根据UserSaveData数据，设定章节基础信息。
    //         if (SD_Chapters.TryGetValue(_all_SO_Chapter.chapterIndex, out SaveData_Chapter saveDataChapter))
    //         {
    //             // 如果字典中存在该章节索引
    //             chapter = new Chapter(_all_SO_Chapter, saveDataChapter.isUnlocked);
    //             // 判断saveDataChapter所保存的关卡路线数量是否为0，不为0就复现，为0说明没有解锁不管
    //         }
    //         else
    //         {
    //             chapter = new Chapter(_all_SO_Chapter, false);

    //             //从文件中加载对应章节的所有level的UI
    //         }
    //         chapterDict[chapter.SO_Chapter.chapterIndex] = chapter;   //将生成的章节chapter添加进入章节字典                       
    //     }

    //     //将初次生成好的Chapter数据，存回到GameData中。
    //     GameData.chapterDict = chapterDict;
    //     GameData.currentChapterIndex = SaveData.currentChapterIndex;
    //     GameData.currentChapter = chapterDict[SaveData.currentChapterIndex];

    //     //拿到当前章节序号和章节信息，并指示Chapter_UI生成UI界面


    //     //告诉UI显示当前的章节信息
    //     //Chapter_UI.Instance.Update_ChapterUI(GameData.currentChapter);
    // }
    // //模块：初始化章节页面
    // public void Init_ChapterPage()
    // {
    //     // 更新章节的UI
    // }
    // public void OnBtn_EnterChapter()  //玩家操控：点击进入章节按钮
    // {
    //     if (GameData.currentChapter.isUnlocked == false)   //所选章节未解锁 或当前正在章节战斗状态中禁止访问
    //     {
    //         //弹出提示
    //         return;
    //     }
    //     else if (GameData.currentChapter.isUnlocked == true)   //所选章节已解锁
    //     {
    //         //Chapter_UI.Instance.Update_RamdonMapsPageSize(GameData.currentChapter);  //先调高度再可视化

    //         if (GameData.currentChapter.level_List.Count == 0)   //判断如果是新章节，则创建关卡路线并生成
    //         {
    //             Create_ChapterMaps(GameData.currentChapter);//创建新章节随机路线数据
    //             //  (待改进)取消章节UI在home下后与levelfighting场景融合后，这里需要去调用切换场景的方法，同时还需要把当前的chapter所挑战的章节要记录到gamedata上，让他带过去(已修改)在左右切换的时候就已经记录好当前挑战的章节
    //             //Chapter_UI.Instance.Restore_ChapterMaps(GameData.currentChapter);

    //             // Home场景切换到LevelFighting场景
    //             Loading_UIManager.Instance.OnLoadScene("LevelFighting");
    //         }
    //         else
    //         {
    //             //(待改进) 可能需要在gamedata里新增当前挑战章节的id
    //             // if (GameData.currentChapter.SO_Chapter.chapterIndex != Chapter_UI.Instance.chapterId)   //判断为关卡路线未复原则复原路线
    //             // {
    //             //     //Chapter_UI.Instance.Restore_ChapterMaps(GameData.currentChapter);
    //             //     // Home场景切换到LevelFighting场景
    //             //     Loading_UIManager.Instance.OnLoadScene("LevelFighting");
    //             // }
    //         }
    //         //Chapter_UI.Instance.OnChapterEnter();
    //     }
    // }

    // public void OnBtn_ForwardChapter()  //玩家操控：点击前进章节
    // {
    //     if (GameData.currentChapterIndex == 1)   //到低的关卡了
    //     {
    //         //提示到最前面关卡了

    //         return;
    //     }
    //     else if (GameData.currentChapterIndex <= GameData.chapterDict.Count)
    //     {
    //         GameData.currentChapterIndex--;
    //         GameData.currentChapter = GameData.chapterDict[GameData.currentChapterIndex];
    //         //Chapter_UI.Instance.Update_ChapterUI(GameData.currentChapter);(待改进，应该在其他地方来更新ui，或者是model_chapter_ui里)
    //     }
    //     // 
    // }

    // public void OnBtn_BackwardChapter() //玩家操控：点击后退章节
    // {
    //     if (GameData.currentChapterIndex == GameData.chapterDict.Count) //到最高的关卡了
    //     {
    //         //提示到最高的关卡了，(需要更新他的按钮UI)

    //         return;
    //     }
    //     else if (GameData.currentChapterIndex >= 1)
    //     {
    //         GameData.currentChapterIndex++;
    //         GameData.currentChapter = GameData.chapterDict[DBCC_DataBase.Instance.GameData.currentChapterIndex];
    //         //Chapter_UI.Instance.Update_ChapterUI(GameData.currentChapter);
    //     }
    // }


    // //模块：Chapter - 章节
    // public void Create_ChapterMaps(Chapter _chapter) //创建新章节地图
    // {
    //     //创建新章节前，先获取新章节必要的基本数据
    //     string fileMonster = _chapter.SO_Chapter.file_Monster;
    //     SO_Card[] Monsters = Resources.LoadAll<SO_Card>($"Card/{fileMonster}");

    //     //将获取的必要数据中的怪物SO_Card，以怪物类型M、Me、Mb进行分类，并存入Chapter中。
    //     foreach (SO_Card _monster in Monsters)
    //     {
    //         switch (_monster.cardType)
    //         {
    //             case "M":
    //                 _chapter.SO_Monsters_List.Add(_monster); // 添加到 M 类型卡牌列表
    //                 break;

    //             case "Me":
    //                 _chapter.SO_MonstersElite_List.Add(_monster); // 添加到 Me 类型卡牌列表
    //                 break;

    //             case "Mb":
    //                 _chapter.SO_MonstersBoss = _monster; // 添加到 Mb 类型卡牌列表
    //                 break;

    //             default:
    //                 Debug.LogWarning($"未知卡牌类型：{_monster.cardType}，卡牌未分类！");
    //                 break;
    //         }
    //     }
    //     ;

    //     //生成章节的随机地图
    //     Chapter_RandomGenerateLevelMaps.Generate_RandomMaps(_chapter);

    //     //再生成章节后，复原地图
    // }

    // public void Set_CompletedChapter()
    // {
    //     currentChapter.isCompleted = true;  //当前章节完成
    //     OnBtn_ForwardChapter(); //自动前进到下一章节

    // }


    //======记录该章节已完成======//
    // public void Set_CompletedChapter()
    // {
    //     // currentChapterIndex = DBCC_DataBase.Instance.GameData.currentChapterIndex;
    //     // //管理选择进入关卡的数据类
    //     // currentLevel.isCompleted = true;
    //     // //同一级的关卡也要被设置为完成

    //     // if (!isCompleted_NewLevel)  //新手关卡完成情况
    //     // {
    //     //     //  如果完成的是第一章的第一关
    //     //     // if (currentChapter.chapterIndex == 1 && currentChapter.levels_Route[0].Contains(currentLevel))
    //     //     {
    //     //         isCompleted_NewLevel = true;
    //     //         Debug.Log("新手关卡通关!");
    //     //     }
    //     // }

    //     // if (playerDiceMax < 4) playerDiceMax++; //玩家骰子通过给予 上限为4

    //     // Chapter_UI.Instance.Update_LevelUI(currentLevel);//通知UI更改
    //     //                                                      //  解锁下一关
    //     // if (currentLevel.levelType == LevelType.Mb)//Boss关通关解锁下一章
    //     // {
    //     //     int currentChapterIndex = currentChapter.chapterIndex;
    //     //     //  做区分是否通关过章节
    //     //     if (currentChapterIndex <= completedChapterCount)    //转换成实际的章节
    //     //     {
    //     //         // 通关重复挑战
    //     //     }
    //     //     else    //首次挑战解锁下一章节
    //     //     {
    //     //         Debug.Log("该章节Boss关首次挑战成功!!!");
    //     //         currentChapter.isCompleted = true;  //当前章节完成
    //     //         completedChapterCount++;
    //     //         int nextChapterIndex = currentChapter.chapterIndex;
    //     //         if (nextChapterIndex == chapters_List.Count) return;  //避免越界
    //     //         chapters_List[nextChapterIndex].isUnlocked = true;   //解锁下一章节---其第一关在初始化已经解锁
    //     //                                                              //同时给下一章生成随机路线
    //     //     }
    //     // } 
    //     // else    //其余关卡
    //     // {
    //     //     //  处理同层的关卡
    //     //     for (int levelIndex = 0; levelIndex < currentLayer.Count; levelIndex++)
    //     //     {
    //     //         if (currentLayer[levelIndex] == null) continue;
    //     //         //  标记未选择的关卡
    //     //         currentLayer[levelIndex].isUnSelected = true;
    //     //         Chapter_UI.Instance.UpdateLevelStateUI(currentLayer[levelIndex]);
    //     //     }

    //     //     //解锁该关卡所连接的下一个关卡
    //     //     List<Level> connectNextLevel = currentLevel.ConnectNextLevel;
    //     //     for (int levelIndex = 0; levelIndex < connectNextLevel.Count; levelIndex++)
    //     //     {
    //     //         if (connectNextLevel[levelIndex] == null) continue;
    //     //         //解锁关卡
    //     //         connectNextLevel[levelIndex].isUnlocked = true;
    //     //         //更改UI
    //     //         Chapter_UI.Instance.Update_LevelStateUI(connectNextLevel[levelIndex]);
    //     //     }
    //     //     Debug.Log("通关关卡，解锁下层关卡");
    //     // }
    // }


    //======读取存档加载关卡路线到章节里======//
    // private List<Level> ReadSaveLevelRouteToChapter(SaveData_Chapter saveData_Chapter)
    // {
    //     //获取存档章节路线
    //     var saveData_Levels_Route = saveData_Chapter.saveData_Levels_Route;

    //     //创建一个新Level的汇总List
    //     List<Level> levelList = new List<Level>();
    //     for (int i = 0; i < saveData_Levels_Route.Count; i++)
    //     {
    //         levelList.Add(new Level()); //new对象先申请内存地址
    //     }
    //     return levelList;

    // List<List<Level>> levels_Route = new List<List<Level>>();
    // //  初始化层结构
    // for (int i = 0; i < saveData_Levels_Route.Count; i++)
    // {
    //     List<Level> layer = new List<Level>();
    //     levels_Route.Add(layer);
    //     //  读取每层存档数据
    //     var saveData_Layer_Levels = saveData_Levels_Route[i];
    //     //  初始化每层的关卡结构
    //     for (int j = 0; j < saveData_Layer_Levels.Count; j++)
    //     {
    //         layer.Add(new Level()); //new对象先申请内存地址
    //     }
    // }
    // //  层遍历加载数据,修改进初始层里
    // for (int layerIndex = 0; layerIndex < saveData_Levels_Route.Count; layerIndex++)
    // {

    //     //  初始层
    //     List<Level> layer = levels_Route[layerIndex];
    //     // 读取每层的关卡结构
    //     List<SaveData_Level> saveData_currentLayer_Levels = saveData_Levels_Route[layerIndex];
    //     for (int levelIndex = 0; levelIndex < saveData_currentLayer_Levels.Count; levelIndex++)
    //     {
    //         //  具体关卡的存档数据
    //         SaveData_Level saveData_Level = saveData_currentLayer_Levels[levelIndex];
    //         // 遇到null为挖空,添加null后继续
    //         if (saveData_Level == null)
    //         {
    //             layer[levelIndex] = null;
    //             Debug.Log("加载关卡时遇到挖空赋值null");
    //             continue;
    //         }
    //         //  根据唯一ID获得关卡SO
    //         if (levelDict.TryGetValue(saveData_Level.levelID_SO, out SO_Level soLevel))
    //         {
    //             //  获取该初始关卡类
    //             Level level = layer[levelIndex];
    //             //  将存档记录属于该关卡的数据赋予
    //             level.levelData = soLevel;
    //             level.isCompleted = saveData_Level.isCompleted;
    //             level.isUnlocked = saveData_Level.isUnlocked;
    //             level.isUnSelected = saveData_Level.isUnSelected;
    //             //  加载关卡之间的连接关系数据
    //             if (layerIndex < saveData_Levels_Route.Count - 1)   //最后一层不需要获取下一层
    //             {
    //                 //  获取初始层的下一层的初始位置
    //                 List<Level> nextLayer = levels_Route[layerIndex + 1];
    //                 //  获取当前关卡存档连接下一层关卡的相对位置数据
    //                 var nextLevelRelativePos = saveData_Level.nextLevelRelativePos;
    //                 //  遍历数据逐个赋予
    //                 foreach (var offset in nextLevelRelativePos)    //目标相对于自身的偏移量
    //                 {
    //                     level.ConnectNextLevel.Add(nextLayer[levelIndex + offset]);
    //                 }
    //                 Debug.Log("关卡连接下一层关卡加载完毕");
    //             }
    //             // 后续可拓展内容...

    //         }
    //     }
    // }
    // Debug.Log("该章节的随机关卡路线数据加载完毕!总计:" + levels_Route.Count + "层数");

    // }
    //======保存随机关卡路线到存档里======//
    // private List<List<SaveData_Level>> SaveLevelRouteToChapterSaveData(Chapter chapter)
    // {
    //     //  获取章节随机关卡路线
    //     var levels_Route = chapter.levels_Route;
    //     //  新建一个存档临时关卡路线的载体
    //     List<List<SaveData_Level>> saveData_Levels_Route = new List<List<SaveData_Level>>();
    //     //  将该章节的随机关卡路线可序列化复制进存档变量里
    //     for (int layerIndex = 0; layerIndex < levels_Route.Count; layerIndex++)//  层遍历
    //     {
    //         List<SaveData_Level> saveData_Layer = new List<SaveData_Level>();   //存档记录每层的载体
    //         List<Level> currentLayer = levels_Route[layerIndex];
    //         for (int levelIndex = 0; levelIndex < levels_Route[layerIndex].Count; levelIndex++) //关遍历
    //         {
    //             //  具体的临时关卡数据
    //             Level level = currentLayer[levelIndex];
    //             if (level == null)   //遇到空位NULL
    //             {
    //                 saveData_Layer.Add(null);
    //             }
    //             else
    //             {
    //                 //  新建可序列化关卡类
    //                 SaveData_Level saveData_Level = new SaveData_Level();
    //                 saveData_Level.levelID_SO = level.levelData.levelID;
    //                 saveData_Level.isCompleted = level.isCompleted;
    //                 saveData_Level.isUnlocked = level.isUnlocked;
    //                 saveData_Level.isUnSelected = level.isUnSelected;
    //                 //  保存关卡之间的连接关系数据
    //                 if (layerIndex < levels_Route.Count - 1)    //最后一层不需要获取下一层
    //                 {
    //                     List<Level> connectNextLevel = level.ConnectNextLevel;  //需要连接的关卡
    //                     // 下一层存在的关卡
    //                     List<Level> nextLayer = levels_Route[layerIndex + 1];
    //                     //  根据所连接的关卡在所在关卡里的索引与自身索引的相对位置进行保存记录
    //                     foreach (var nextLevel in connectNextLevel)
    //                     {
    //                         int targetIndex = nextLayer.IndexOf(nextLevel); //获得目标所在索引
    //                         int selfIndex = currentLayer.IndexOf(level);    //获得自身所在索引
    //                         int offset = targetIndex - selfIndex;   //偏差 = 目标 - 自身索引
    //                         saveData_Level.nextLevelRelativePos.Add(offset);
    //                     }
    //                     Debug.Log("临时关卡连接下一层关卡保存完毕!");
    //                 }
    //                 saveData_Layer.Add(saveData_Level); //关卡保存进去
    //             }
    //         }
    //         saveData_Levels_Route.Add(saveData_Layer);  //一层关卡保存进去
    //     }
    //     Debug.Log("临时章节关卡随机路线保存完毕!");
    //     return saveData_Levels_Route;
    // }
    //======保存关卡进程======//[关键，同时在初始化的时候要判断]    章节进程

    //======外置调用来记录所选关卡类数据======//
    // public void SetSelectLevel(Level _selectLevel, List<Level> _selectLayer)
    // {
    //     currentLevel = _selectLevel;    //保存引用
    //     currentLayer = _selectLayer;
    // }
    //======外置访问当前关卡类数据======//
    // public Level GetCurrentLevelData()
    // {
    //     return currentLevel;
    // }


    //======外置调用，返回所选章节数据======//
    // public Chapter GetSelectChapterData(int _selectChapterIndex)
    // {
    //     //防止越界访问章节
    //     if (_selectChapterIndex > chapters_List.Count) return null;
    //     //  调用章节索引数据库得到章节
    //     currentChapter = chapterDict[_selectChapterIndex];  //记录当前所选的章节
    //     return currentChapter;
    // }

    //======外部获取当前在第几章======//
    // public int GetCurrentChapter()
    // {
    //     //  使用当前章节的保存索引
    //     int currentChapterIndex = currentChapter.chapterIndex;
    //     return currentChapterIndex;
    // }
}
