// using System.Collections;
using System.Collections.Generic;
using System.Linq;
// using Unity.VisualScripting;
using UnityEngine;

public class Chapter_RandomGenerateLevelMaps : MonoBehaviour
{
    //设定必要数据与组件
    Chapter chapter;

    //生成路线
    // Level levelBoss; // 设定Boss层
    // Level levelStart; // 设定起始层   
    private List<List<Level>> layers = new List<List<Level>>();
    List<SO_Card> monsterPool; // 初始化怪物池
    List<SO_Card> monsterPoolUsed = new List<SO_Card>(); // 收纳已用过的普通怪物池
    List<SO_Card> monsterEPool; // 初始化怪物池
    List<SO_Card> monsterEPoolUsed = new List<SO_Card>(); // 收纳已用过的精英怪物池
    List<int> tempList = new List<int>(); //用于临时记录同层关卡，随机分配特殊关卡的列表
    [Tooltip("层关卡个数")] public int rowCountRule = 3; //层关卡个数
                                                    //public int monsterCount;   //层关卡个数

    // ----------------------------------------------------------------------------------------------------------

    //模块：RandomMaps
    public void Generate_RandomMaps(Chapter _chapter) //随机生成地图
    {
        chapter = _chapter;

        layers.Clear();
        int sectionCount = _chapter.SO_Chapter.chapterMonster.Count;
        //设定章节怪物池
        monsterPool = new List<SO_Card>(_chapter.SO_Monsters_List); // 初始化怪物池
        monsterEPool = new List<SO_Card>(_chapter.SO_MonstersElite_List); // 初始化怪物池
        //  处理起始层,并分配数据   
        List<Level> startLevels = new List<Level>();
        layers.Add(startLevels);
        Debug.Log($"layers:{layers != null}, layers[0]:{layers?[0] != null}, _chapter:{_chapter != null}, SO_Chapter:{_chapter?.SO_Chapter != null}, levelMonsterNum:{_chapter?.SO_Chapter?.levelMonsterNum?[0] != null}, levelMonsterDice:{_chapter?.SO_Chapter?.levelMonsterDice?[0] != null}");
        Level levelStart = new Level(_chapter.SO_Chapter.levelMonsterNum[0], _chapter.SO_Chapter.levelMonsterDice[0].dices_List, _chapter.SO_Chapter.staminaCost);
        levelStart.sameLayer = startLevels;   //单独处理
        startLevels.Add(levelStart);

        Set_LevelMonster(startLevels);//
        levelStart.levelTypeIcon = _chapter.Level_Monster_Ready;

        int layerIndex = 0; //除去起始层外的中间层
        //  创建层
        for (int i = 0; i < sectionCount; i++)  //处理每段
        {
            //  (待修改)做一个类似安全机制break强制跳出循环避免陷入死循环
            Debug.Log("现在处理第" + (i + 1) + "段");
            List<string> levelMonsterDice = _chapter.SO_Chapter.levelMonsterDice[i].dices_List;
            //  处理段内的关卡
            int layerCount = 0;
            layerCount += _chapter.SO_Chapter.chapterRest[i];//休整关卡;
            layerCount += _chapter.SO_Chapter.chapterMonster[i];
            layerCount += _chapter.SO_Chapter.chapterMonsterElite[i];
            layerCount += _chapter.SO_Chapter.chapterRelic[i];
            layerCount += _chapter.SO_Chapter.chapterBlackMarket[i];
            layerCount += _chapter.SO_Chapter.chapterAdvanture[i];

            List<int> randSection_Nums = new List<int>();
            //获取层的关卡类型数量数据
            Set_SectionTypeAndNums(_chapter, i, randSection_Nums);
            //层处理
            for (int j = 0; j < layerCount; j++)
            {
                List<Level> currentLayerLevel = new List<Level>();
                layers.Add(currentLayerLevel);
                // 随机决定当前层挖空位置或是否挖空 [-1] 不挖 [0 1 2]挖空位置
                int levelNull = Random.Range(-1, 3);
                // 创建当前层节点 [0 1 2]=3个
                Debug.Log("此时是第" + layerIndex + "层");
                for (int k = 0; k < rowCountRule; k++)
                {
                    // 遇到挖空的直接赋予null
                    if (levelNull == k)
                    {
                        currentLayerLevel.Add(null);
                        continue;
                    }
                    //为单层初始化创建所有关卡
                    Level tempLevel = new Level(_chapter.SO_Chapter.levelMonsterNum[layerIndex], levelMonsterDice, _chapter.SO_Chapter.staminaCost);
                    tempLevel.sameLayer = currentLayerLevel;   //单独处理
                    // 指定声明的位置放入临时Level对象
                    currentLayerLevel.Add(tempLevel);
                }
                layerIndex++;
                //  层分配数据
                if (j == layerCount - 1 && i != sectionCount - 1) AssignLevelData(new List<int> { 0 }, currentLayerLevel);
                else AssignLevelData(randSection_Nums, currentLayerLevel);
            }
            Debug.Log("第" + (i + 1) + "段处理完毕");
        }
        //  处理Boss层
        List<Level> bossLevels = new List<Level>();
        layers.Add(bossLevels);
        Level levelBoss = new Level(_chapter.SO_Chapter.levelMonsterNum[layers.Count - 3], _chapter.SO_Chapter.levelMonsterDice[sectionCount - 1].dices_List, _chapter.SO_Chapter.staminaCost);
        levelBoss.sameLayer = bossLevels;   //单独处理
        bossLevels.Add(levelBoss);
        //设定Boss层数据 ---> boss层应该最后处理，因为在加入levelList的时候是直接add方法加入的
        Set_LevelMonster(bossLevels); //为起始层设置怪物
        levelBoss.levelTypeIcon = _chapter.Level_Unknown; //设定关卡UI
        levelBoss.Add_MonsterSO(_chapter.SO_MonstersBoss); // 单独传入Boss怪物SO

        // 3. 连接节点普通层
        for (int layerLinkIndex = 0; layerLinkIndex < layers.Count - 1; layerLinkIndex++) //BOSS层不用往后面连接
        {
            List<Level> currentLayer = layers[layerLinkIndex];  //确认当前层中所有层的Level
            List<Level> nextLayer = layers[layerLinkIndex + 1]; //获取下一层中所有层的Level
            // Spchapter.Level_ConnectLine_xy_Off

            //起始层需要单独处理
            if (layerLinkIndex == 0)
            {
                if (nextLayer[0] != null) //    同样要处理层之间的连接关系
                {
                    currentLayer[0].levelrRoad[0] = chapter.Level_ConnectLine_xy_Off;
                    currentLayer[0].nextLayer.Add(nextLayer[0]);
                    nextLayer[0].beforeLayer.Add(currentLayer[0]);
                }
                if (nextLayer[1] != null)
                {
                    currentLayer[0].levelrRoad[1] = chapter.Level_ConnectLine_x_Off;
                    currentLayer[0].nextLayer.Add(nextLayer[1]);
                    nextLayer[1].beforeLayer.Add(currentLayer[0]);
                }
                if (nextLayer[2] != null)
                {
                    currentLayer[0].levelrRoad[2] = chapter.Level_ConnectLine_xy_Off;
                    currentLayer[0].nextLayer.Add(nextLayer[2]);
                    nextLayer[2].beforeLayer.Add(currentLayer[0]);
                }
                continue;
            }
            // 特殊处理：Boss前一层的所有节点只能连接到Boss
            if (layerLinkIndex == layers.Count - 2)
            {
                for (int levelIndex = 0; levelIndex < currentLayer.Count; levelIndex++)
                {
                    Level level = currentLayer[levelIndex];
                    if (level == null) continue;
                    //需要对3条路径进行循环判断，是否链接，如果连接就放入对应的图片，从而设置初始关卡链接状态）
                    if (levelIndex == 0)
                    {
                        level.levelrRoad[2] = chapter.Level_ConnectLine_xy_Off;
                        level.nextLayer.Add(nextLayer[0]);
                        nextLayer[0].beforeLayer.Add(level);
                    }
                    if (levelIndex == 1)
                    {
                        level.levelrRoad[1] = chapter.Level_ConnectLine_x_Off;
                        level.nextLayer.Add(nextLayer[0]);
                        nextLayer[0].beforeLayer.Add(level);
                    }
                    if (levelIndex == 2)
                    {
                        level.levelrRoad[0] = chapter.Level_ConnectLine_xy_Off;
                        level.nextLayer.Add(nextLayer[0]);
                        nextLayer[0].beforeLayer.Add(level);
                    }
                    // level.ConnectNextLevel.Add(layers[layerCount - 1][0]);//  连接到Boss
                }
                continue;
            }

            // 普通层连接规则[避免交叉]
            for (int i = 0; i < currentLayer.Count; i++)    //单层处理(3)
            {
                Level level = currentLayer[i];

                //检查当前关卡是否为空
                if (level == null) continue;

                //首先我需要对每个关卡都往上链接路线，在连接的时候通过判断下一层的目标关卡是否存在，来决定是否最终链接。
                for (int j = i - 1; j < i + 2; j++)
                {
                    if (i == 1) //中间的关卡 连接0,1,2
                    {
                        if (j == 0 && nextLayer[0] != null)
                        {
                            level.levelrRoad[0] = chapter.Level_ConnectLine_xy_Off;
                            level.nextLayer.Add(nextLayer[0]);
                            nextLayer[0].beforeLayer.Add(level);
                            continue;
                        }
                        if (j == 1 && nextLayer[1] != null)
                        {
                            level.levelrRoad[1] = chapter.Level_ConnectLine_x_Off;
                            level.nextLayer.Add(nextLayer[1]);
                            nextLayer[1].beforeLayer.Add(level);
                            continue;
                        }
                        if (j == 2 && nextLayer[2] != null)
                        {
                            level.levelrRoad[2] = chapter.Level_ConnectLine_xy_Off;
                            level.nextLayer.Add(nextLayer[2]);
                            nextLayer[2].beforeLayer.Add(level);
                            continue;
                        }
                        if (j == 3) continue;
                    }
                    else    //两边的关卡 左边的关卡连接 -1 0 1 [-1]不能连 右边的关卡连接 1 2 3 [3]不能连
                    {
                        if (j == -1) continue;
                        if (j == 0 && nextLayer[0] != null)
                        {
                            level.levelrRoad[1] = chapter.Level_ConnectLine_x_Off;
                            level.nextLayer.Add(nextLayer[0]);
                            nextLayer[0].beforeLayer.Add(level);
                            continue;
                        }
                        if (j == 1 && nextLayer[1] != null) //左右两边的关卡连接斜边的关卡 0->2 2->0
                        {
                            level.levelrRoad[2 - i] = chapter.Level_ConnectLine_xy_Off; // 2 / 0
                            level.nextLayer.Add(nextLayer[1]);
                            nextLayer[1].beforeLayer.Add(level);
                            continue;
                        }
                        if (j == 2 && nextLayer[2] != null)
                        {
                            level.levelrRoad[1] = chapter.Level_ConnectLine_x_Off;
                            level.nextLayer.Add(nextLayer[2]);
                            nextLayer[2].beforeLayer.Add(level);
                            continue;
                        }
                        if (j == 3) continue;
                    }
                }
            }
            Debug.Log($"第" + layerLinkIndex + "层连接完毕");
            //对该层的随机路线进行随机挑选
            if (currentLayer[0]?.levelrRoad[2] != null && currentLayer[1]?.levelrRoad[0] != null)   //防空null写法
            {
                int randX = Random.Range(0, 3); //三种形式，0代表 放弃右连接左 1代表 放弃左连接右 2代表两种都不连接
                if (randX == 0)
                {
                    currentLayer[0].levelrRoad[2] = null;
                    currentLayer[0].nextLayer.Remove(nextLayer[1]);
                    nextLayer[1].beforeLayer.Remove(currentLayer[0]);
                }
                if (randX == 1)
                {
                    currentLayer[1].levelrRoad[0] = null;
                    currentLayer[1].nextLayer.Remove(nextLayer[0]);
                    nextLayer[0].beforeLayer.Remove(currentLayer[1]);
                }
                if (randX == 2)
                {
                    currentLayer[0].levelrRoad[2] = null;
                    currentLayer[0].nextLayer.Remove(nextLayer[1]);
                    nextLayer[1].beforeLayer.Remove(currentLayer[0]);
                    currentLayer[1].levelrRoad[0] = null;
                    currentLayer[1].nextLayer.Remove(nextLayer[0]);
                    nextLayer[0].beforeLayer.Remove(currentLayer[1]);
                }
            }

            if (currentLayer[1]?.levelrRoad[2] != null && currentLayer[2]?.levelrRoad[0] != null)
            {
                int randX = Random.Range(0, 3);
                if (randX == 0)
                {
                    currentLayer[1].levelrRoad[2] = null;
                    currentLayer[1].nextLayer.Remove(nextLayer[2]);
                    nextLayer[2].beforeLayer.Remove(currentLayer[1]);
                }
                if (randX == 1)
                {
                    currentLayer[2].levelrRoad[0] = null;
                    currentLayer[2].nextLayer.Remove(nextLayer[1]);
                    nextLayer[1].beforeLayer.Remove(currentLayer[2]);
                }
                if (randX == 2)
                {
                    currentLayer[1].levelrRoad[2] = null;
                    currentLayer[1].nextLayer.Remove(nextLayer[2]);
                    nextLayer[2].beforeLayer.Remove(currentLayer[1]);
                    currentLayer[2].levelrRoad[0] = null;
                    currentLayer[2].nextLayer.Remove(nextLayer[1]);
                    nextLayer[1].beforeLayer.Remove(currentLayer[2]);
                }
            }
        }
        Debug.Log("整个章节关卡路线分配完毕");
        //首先设定当前章节的层数--->起始关卡和boss关都是单独处理，还需要再加上
        // int layerCount = 0;
        // //  先有几段
        // int sectionNum = _chapter.SO_Chapter.chapterMonster.Count;
        // for(int i = 0;i < sectionNum;i++)
        // {
        //     layerCount += _chapter.SO_Chapter.chapterMonster[i];
        //     layerCount += _chapter.SO_Chapter.chapterMonsterElite[i];
        //     layerCount += _chapter.SO_Chapter.chapterRelic[i];
        //     layerCount += _chapter.SO_Chapter.chapterBlackMarket[i];
        //     layerCount += _chapter.SO_Chapter.chapterAdvanture[i];
        //     if(i != sectionNum - 1) layerCount += 1;    //休整关卡;
        // }
        // //  还需要加上 起始关和Boss关
        // layerCount += 2;

        //从chapter中获取chapterMonster的数值，来设定同层关卡中所有怪物的数量
        // //按照怪物分段
        // List<int> monsterCountList = new List<int> { };
        // if (_chapter.SO_Chapter.chapterMonster1[0] > 0) monsterCountList.AddRange(_chapter.SO_Chapter.chapterMonster1); // 精英关卡 = 2
        // if (_chapter.SO_Chapter.chapterMonster2[0] > 0) monsterCountList.AddRange(_chapter.SO_Chapter.chapterMonster2); // 精英关卡 = 2
        // if (_chapter.SO_Chapter.chapterMonster3[0] > 0) monsterCountList.AddRange(_chapter.SO_Chapter.chapterMonster3); // 休整关卡 = 3
        // if (_chapter.SO_Chapter.chapterMonster4[0] > 0) monsterCountList.AddRange(_chapter.SO_Chapter.chapterMonster4); // 遗迹关卡 = 4
        // if (_chapter.SO_Chapter.chapterMonster5[0] > 0) monsterCountList.AddRange(_chapter.SO_Chapter.chapterMonster5); // 黑市关卡 = 5
        // if (_chapter.SO_Chapter.chapterMonster6[0] > 0) monsterCountList.AddRange(_chapter.SO_Chapter.chapterMonster6); // 奇遇关卡 = 6

        // List<string> monsterDiceCountList = new List<string> { };
        // if (_chapter.SO_Chapter.chapterDice1.Count > 0) monsterDiceCountList.AddRange(_chapter.SO_Chapter.chapterDice1); //
        // if (_chapter.SO_Chapter.chapterDice2.Count > 0) monsterDiceCountList.AddRange(_chapter.SO_Chapter.chapterDice2); //
        // if (_chapter.SO_Chapter.chapterDice3.Count > 0) monsterDiceCountList.AddRange(_chapter.SO_Chapter.chapterDice3); //
        // if (_chapter.SO_Chapter.chapterDice4.Count > 0) monsterDiceCountList.AddRange(_chapter.SO_Chapter.chapterDice4); //
        // if (_chapter.SO_Chapter.chapterDice5.Count > 0) monsterDiceCountList.AddRange(_chapter.SO_Chapter.chapterDice5); //
        // if (_chapter.SO_Chapter.chapterDice6.Count > 0) monsterDiceCountList.AddRange(_chapter.SO_Chapter.chapterDice6); //

        // // // 1. 创建Boss层和起始层
        // // Level levelStart = new Level(layers[0], _chapter.SO_Chapter.levelMonsterNum[0], _chapter.SO_Chapter.levelMonsterDice[0], chapter.SO_Chapter.staminaCost);
        // // // Level levelBoss = new Level(layers[layerCount - 1], _chapter.SO_Chapter.levelMonsterNum[layerCount - 1], monsterDiceCountList[layerCount - 1], chapter.SO_Chapter.staminaCost);
        // // // layers[layerCount - 1].Add(levelBoss);
        // // layers[0].Add(levelStart);

        // // 2. 生成剩余层节点并挖空=null
        // for (int layerIndex = layerCount - 2; layerIndex >= 1; layerIndex--)
        // {
        //     // 随机决定当前层挖空位置或是否挖空 [-1] 不挖 [0 1 2]挖空位置
        //     int levelNull = Random.Range(-1, 3);

        //     // 创建当前层节点 [0 1 2]=3个
        //     for (int i = 0; i < rowCountRule; i++)
        //     {
        //         // 遇到挖空的直接赋予null
        //         if (levelNull >= 0 && levelNull == i)
        //         {
        //             layers[layerIndex].Add(null);
        //             // levelID++;
        //             continue;
        //         }

        //         //为单层初始化创建所有关卡
        //         Level tempLevel = new Level(layers[layerIndex], _chapter.SO_Chapter.levelMonsterNum[layerIndex], monsterDiceCountList[layerIndex], chapter.SO_Chapter.staminaCost);
        //         tempLevel.sameLayer = layers[layerIndex];
        //         tempLevel.monsterCount = monsterCountList[layerIndex];
        //         tempLevel.monsterDiceCount = monsterDiceCountList[layerIndex];
        //         // 指定声明的位置放入临时Level对象
        //         layers[layerIndex].Add(tempLevel);
        //     }
        // }


    }
    //======解锁第一关======//
    // private void unLockedFirstLayer()
    // {
    //     for (int levelIndex = 0; levelIndex < layers[0].Count; levelIndex++)
    //     {
    //         // 检查当前关卡是否为空
    //         if (layers[0][levelIndex] == null) continue;
    //         // 初始解锁第一关关卡
    //         layers[0][levelIndex].isUnlocked = true;
    //     }
    // }

    private void AssignLevelData(List<int> _randSectionNums, List<Level> _currentLayerLevel) //分配关卡数据
    {
        // //设定章节怪物池
        // monsterPool = new List<SO_Card>(_chapter.SO_Monsters_List); // 初始化怪物池
        // monsterEPool = new List<SO_Card>(_chapter.SO_MonstersElite_List); // 初始化怪物池

        List<Level> currentLayer = _currentLayerLevel;
        //随机分配一个关卡类型
        int randomIndex = Random.Range(0, _randSectionNums.Count); //随机索引
        int randomGateType = _randSectionNums[randomIndex]; //随机值

        switch (randomGateType)
        {
            case 0:
                Set_LevelRest(currentLayer, LevelType.Rest);
                _randSectionNums.RemoveAt(randomIndex);
                Debug.Log("当前层是休整关卡");
                break;
            case 1:
                Set_LevelMonster(currentLayer);
                _randSectionNums.RemoveAt(randomIndex);
                Debug.Log("当前层是普通怪物关卡");
                break;
            case 2:
                Set_LevelMonsterElite(currentLayer);
                _randSectionNums.RemoveAt(randomIndex);
                Debug.Log("当前层是精英怪物关卡");
                break;
            case 3:
                Set_LevelSpecial(currentLayer, LevelType.Relic);
                _randSectionNums.RemoveAt(randomIndex);
                Debug.Log("当前层是遗迹关卡");
                break;
            case 4:
                Set_LevelSpecial(currentLayer, LevelType.BlackMarket);
                _randSectionNums.RemoveAt(randomIndex);
                Debug.Log("当前层是黑市关卡");
                break;
            case 5:
                Set_LevelSpecial(currentLayer, LevelType.Advanture);
                _randSectionNums.RemoveAt(randomIndex);
                Debug.Log("当前层是奇遇关卡");
                break;
            default:
                Debug.Log("未知的关卡类型");
                break;
        }
        // //按照怪物分段
        // //  Section1
        // List<int> randSection1_Nums = new List<int> { };
        // List<int> chapterSection = SO_Chapter.chapterSection1;
        // Set_SectionTypeAndNums(chapterSection,randSection1_Nums);
        // //  Section2
        // List<int> randSection2_Nums = new List<int> { };
        // chapterSection = SO_Chapter.chapterSection2;
        // Set_SectionTypeAndNums(chapterSection,randSection2_Nums);
        // //  Section3
        // List<int> randSection3_Nums = new List<int> { };
        // chapterSection = SO_Chapter.chapterSection3;
        // Set_SectionTypeAndNums(chapterSection,randSection3_Nums);


        // if (SO_Chapter.chapterSection1[0] > 0) // 怪物关卡 = 1 
        // {
        //     for (int i = 0; i < SO_Chapter.chapterSection1[0]; i++)
        //     { randSection1_Nums.Add(1); } //给表里加2个[1]
        // }
        // if (SO_Chapter.chapterSection1[1] > 0) randSection1_Nums.Add(2); // 精英关卡 = 2
        // if (_chapter.SO_Chapter.chapterSection1[2] > 0) randSection1_Nums.Add(3); // 休整关卡 = 3
        // if (_chapter.SO_Chapter.chapterSection1[3] > 0) randSection1_Nums.Add(4); // 遗迹关卡 = 4
        // if (_chapter.SO_Chapter.chapterSection1[4] > 0) randSection1_Nums.Add(5); // 黑市关卡 = 5
        // if (_chapter.SO_Chapter.chapterSection1[5] > 0) randSection1_Nums.Add(6); // 奇遇关卡 = 6

        // //设定起始层数据
        // Set_LevelMonster(layers[0]);
        // levelStart.levelTypeIcon = chapter.Level_Monster_Ready;
        //  中间层
        // for (int layerIndex = 1; layerIndex < layerCount - 1; layerIndex++)
        // {


        // }
    }
    // 段的关卡种类和数量解析-->休整关卡不用分配解析
    void Set_SectionTypeAndNums(Chapter _chapter, int _i, List<int> _randSectionNums) //2,0,0,0 -> 1,1
    {
        // if (_chapter.SO_Chapter.chapterRest[_i] > 0) // 休整关卡 = 0 --->因为每段最后一个都是休整，boss那段除外
        // {
        //     for (int mNum = 0; mNum < _chapter.SO_Chapter.chapterRest[_i]; mNum++)
        //     { _randSectionNums.Add(0); }
        // }
        if (_chapter.SO_Chapter.chapterMonster[_i] > 0) // 怪物关卡 = 1 
        {
            for (int mNum = 0; mNum < _chapter.SO_Chapter.chapterMonster[_i]; mNum++)
            { _randSectionNums.Add(1); }        //给表里加2个[1]
        }
        if (_chapter.SO_Chapter.chapterMonsterElite[_i] > 0) // 精英关卡 = 2
        {
            for (int mNum = 0; mNum < _chapter.SO_Chapter.chapterMonsterElite[_i]; mNum++)
            { _randSectionNums.Add(2); }
        }
        if (_chapter.SO_Chapter.chapterRelic[_i] > 0)// 遗迹关卡= 3
        {
            for (int mNum = 0; mNum < _chapter.SO_Chapter.chapterRelic[_i]; mNum++)
            { _randSectionNums.Add(3); }
        }
        if (_chapter.SO_Chapter.chapterBlackMarket[_i] > 0) //黑市关卡 = 4
        {
            for (int mNum = 0; mNum < _chapter.SO_Chapter.chapterBlackMarket[_i]; mNum++)
            { _randSectionNums.Add(4); }
        }
        if (_chapter.SO_Chapter.chapterAdvanture[_i] > 0)// 奇遇关卡 = 5
        {
            for (int mNum = 0; mNum < _chapter.SO_Chapter.chapterAdvanture[_i]; mNum++)
            { _randSectionNums.Add(5); }
        }
    }

    //为单个Level设置独有数据
    void Set_LevelMonster(List<Level> _currentLayer)  //设置普通怪物
    {
        //首先拿到这一层的怪物的随机种类，如果为空就从空的池子里拿
        if (monsterPool.Count == 0) { monsterPool = monsterPoolUsed; }
        //从怪物池中提取怪物，赋值并移入已用怪物池
        int randomMonster = Random.Range(0, monsterPool.Count);
        SO_Card selectedMonster = monsterPool[randomMonster];
        monsterPoolUsed.Add(selectedMonster);
        monsterPool.RemoveAt(randomMonster);

        foreach (Level level in _currentLayer)
        {
            //空位跳过
            if (level == null)
            {
                chapter.level_List.Add(level);
                continue;
            }
            //将怪物赋值给关卡
            Add_MonsterNumToLevel(level, selectedMonster, null, level.monsterCount);
            // level.GetMonsterSO(selectedMonster); // 传入怪物SO
            // level.levelType = LevelType.M; // 传入关卡类型
            // level.monsterNum = 2; // 传入关卡类型
            level.levelTypeIcon = chapter.Level_Unknown;
            Debug.Log("为关卡分配了怪物：" + selectedMonster.cardName);
            // return checkLevel;
            chapter.level_List.Add(level);
        }
    }

    void Set_LevelMonsterElite(List<Level> _currentLayer) //设置精英怪物
    {
        // 查看是否有精英怪物关卡
        //首先拿到这一层的怪物的随机种类，如果为空就从空的池子里拿
        if (monsterEPool.Count == 0) { monsterEPool = monsterEPoolUsed; }
        //从怪物池中提取怪物，赋值并移入已用怪物池
        int randomMonsterElite = Random.Range(0, monsterEPool.Count);
        SO_Card selectedMonsterElite = monsterEPool[randomMonsterElite];
        monsterEPoolUsed.Add(selectedMonsterElite);
        monsterEPool.RemoveAt(randomMonsterElite);

        //然后再拿到这一层的怪物的随机种类，如果为空就从空的池子里拿
        if (monsterPool.Count == 0) { monsterPool = monsterPoolUsed; }
        //从怪物池中提取怪物，赋值并移入已用怪物池
        int randomMonster = Random.Range(0, monsterPool.Count);
        SO_Card selectedMonster = monsterPool[randomMonster];
        monsterPoolUsed.Add(selectedMonster);
        monsterPool.RemoveAt(randomMonster);

        foreach (Level level in _currentLayer)
        {
            //空位跳过
            if (level == null)
            {
                chapter.level_List.Add(level);
                continue;
            }
            //将怪物赋值给关卡
            Add_MonsterNumToLevel(level, selectedMonster, selectedMonsterElite, level.monsterCount);
            level.levelTypeIcon = chapter.Level_Unknown;
            Debug.Log("为关卡分配了怪物：" + selectedMonster.cardName);
            chapter.level_List.Add(level);
        }
    }

    void Set_LevelSpecial(List<Level> _currentLayer, LevelType _levelType)  //设置特殊关卡
    {
        // VariableAssigner assigner = new VariableAssigner();
        List<int> availableGates = new List<int>();
        for (int i = 0; i < _currentLayer.Count; i++)
        {
            if (_currentLayer[i] == null) continue;   //非null的关卡位置才能够参与分配
            availableGates.Add(i);
        }
        int assigned = RandomAssignVariable(availableGates);
        //  先分配为怪物关卡，确认好层关系，然后再通过改变其中的level从怪物关卡变为特殊关卡
        //50%随机决定是普通怪物关卡还是精英怪物关卡
        int randomGate = Random.Range(0, 2);
        if (randomGate == 0) Set_LevelMonster(_currentLayer);
        if (randomGate == 1) Set_LevelMonsterElite(_currentLayer);
        for (int i = 0; i < _currentLayer.Count; i++)   //遍历当前层
        {
            if (i == assigned)  //如果是被分配的特殊关卡
            {
                _currentLayer[i].levelType = _levelType; //设置类型
                _currentLayer[i].levelTypeIcon = chapter.Level_Unknown;
                //  更改为特殊关卡的level内容
                _currentLayer[i].monsterSO_List.Clear();
            }
        }
    }
    void Set_LevelRest(List<Level> _currentLayer, LevelType _levelType)  //单独设置设置休整关卡
    {
        // VariableAssigner assigner = new VariableAssigner();
        // List<int> availableGates = new List<int>();
        // for (int i = 0; i < _currentLayer.Count; i++) { availableGates.Add(i); }
        //int assigned = RandomAssignVariable(availableGates);

        foreach (Level level in _currentLayer)   //遍历当前层全部分布休整关卡
        {
            if (level == null)  //如果当前分配关卡为空就跳过
            {
                chapter.level_List.Add(null);
                continue;
            }
            level.levelTypeIcon = chapter.Level_Unknown;    //设置关卡UI
            level.levelType = _levelType; //设置类型
            chapter.level_List.Add(level);
        }
        // if (_currentLayer.Count >= 1)   //如果还有剩余关卡
        // {
        //     //50%随机决定是普通怪物关卡还是精英怪物关卡
        //     int randomGate = Random.Range(0, 2);
        //     if (randomGate == 0) Set_LevelMonster(_currentLayer);
        //     if (randomGate == 1) Set_LevelMonsterElite(_currentLayer);
        // }
    }

    void Add_MonsterNumToLevel(Level _level, SO_Card _selectedMonster, SO_Card _selectedMonsterElite, int _num) //给关卡添加普通怪物[传入的是普通怪物的数量]
    {
        for (int i = 0; i < _num; i++) //为每个关卡怪物都安排一个SO_Card
        {
            _level.Add_MonsterSO(_selectedMonster); // 传入怪物SO
        }
        _level.levelType = LevelType.M; // 传入关卡类型
        if (_selectedMonsterElite != null)
        {
            _level.Add_MonsterSO(_selectedMonsterElite); // 传入怪物SO
            _level.levelType = LevelType.Me; // 传入关卡类型
            //_num++; 
        }
    }

    public int RandomAssignVariable(List<int> availableNumbers) //为同层关卡随机分配一个特殊关卡
    {
        // 清空临时列表
        tempList.Clear();

        // 如果没有任何可用数值，返回-1表示错误
        if (availableNumbers == null || availableNumbers.Count == 0)
        {
            Debug.LogError("没有可用的数值进行分配!");
            return -1;
        }

        // 如果只有一个数值，直接分配并返回
        if (availableNumbers.Count == 1)
        {
            return availableNumbers[0];
        }

        // 有多个数值时，随机选择一个分配变量A
        int randomIndex = Random.Range(0, availableNumbers.Count);
        int assignedNumber = availableNumbers[randomIndex];

        // 将其余数值添加到临时列表
        for (int i = 0; i < availableNumbers.Count; i++)
        {
            if (i != randomIndex)
            {
                tempList.Add(availableNumbers[i]);
            }
        }
        return assignedNumber;
    }

    // ======调试用：打印关卡结构======//
    // public void PrintLevelStructure()
    // {
    //     Debug.Log("===== 关卡结构 =====");
    //     for (int i = 0; i < layers.Count; i++)
    //     {
    //         string layerInfo = $"层 {i + 1} ({layers[i].Count}个节点): ";
    //         for (int levelIndex = 0; levelIndex < layers[i].Count; levelIndex++)
    //         {
    //             if (layers[i][levelIndex] == null)
    //             {
    //                 layerInfo += $"[NULL]→，";
    //                 continue;
    //             }
    //             layerInfo += $"[{layers[i][levelIndex].levelType}→";
    //             foreach (Level next in layers[i][levelIndex].ConnectNextLevel)
    //             {
    //                 layerInfo += layers[i + 1].IndexOf(next) + ",";
    //             }
    //             layerInfo = layerInfo.TrimEnd(',') + "] ";
    //         }
    //         Debug.Log(layerInfo);
    //     }
    // }
}
