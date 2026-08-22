using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;

public static class Manager_Random_LevelRoutes//随机关卡路线分配算法
{
    private static Dictionary<int,List<LevelNode>> random_LevelRoutes = new Dictionary<int, List<LevelNode>>();//new一个接发的中转站

    //外部关卡调用接口---拿到关卡位置信息进行生成随机关卡路线连接
    public static Dictionary<int,List<LevelNode>> RandomAlgorithm_LevelRoutes(Dictionary<int,List<LevelNode>> original_Level)//只接收源关卡位置信息
    {
        int isLinking;//随机连接值
        //关卡级循环
        for(int level = 0; level< original_Level.Count-1;level++)
        {
            List<LevelNode> currentLevelNodes = original_Level[level];//拿到当前级的关卡
            List<LevelNode> nextLevelNodes = original_Level[level+1];//拿到下一级的关卡
            //注意区别Boss关[不能让下一级关卡拿到Boss关]
            if (level < original_Level.Count - 2)
            {   
                //do-while循环确保[该级的连接数>=当前级关卡个数]
                int levelLinkCount = 0;//该级连接数
                do
                {
                    if(original_Level[level].Count>=3)//确保数量大于等于3个
                    {
                        //将上一轮的结果进行清空
                        levelLinkCount = 0;//清零
                        for (int index = 0; index < original_Level[level].Count; index++)//对一级内的所有关卡操作
                        {
                            //修改逻辑状态
                            currentLevelNodes[index].Islinking = false;
                            nextLevelNodes[index].Islinked = false;
                            currentLevelNodes[index].ConnectNextNodes.Clear();//将每个保存连接的列表进行清空
                        }

                        //级内循环[对每个关卡进行操作]
                        for (int index = 0; index < original_Level[level].Count; index++)
                        {
                            //确保每个只会向上有3个分支选择[其他没有的要处理]
                            //第一个
                            if (index == 0)
                            {
                                //只对下一级的0-1关卡操作
                                for (int isLinkingLevelNode = 0; isLinkingLevelNode < 2; isLinkingLevelNode++)
                                {
                                    isLinking = Random.Range(0, 2);//在[0,1]之间随机，如果是0代表对该关卡不连接，反之则连接
                                    if (isLinking == 1)//如果是1代表连接
                                    {
                                        //将要连接的关卡放入当前关卡的连接列表里
                                        currentLevelNodes[index].ConnectNextNodes.Add(nextLevelNodes[isLinkingLevelNode]);
                                        //将当前关卡和要连接关卡的逻辑状态修改
                                        currentLevelNodes[index].Islinking = true;
                                        nextLevelNodes[isLinkingLevelNode].Islinked = true;
                                        //连接后将连接数增加
                                        levelLinkCount++;
                                    }
                                    else
                                    {
                                        //下一级的关卡不连接[修改逻辑状态]
                                        nextLevelNodes[isLinkingLevelNode].Islinked = false;
                                    }
                                }
                            }
                            else if (index == original_Level[level].Count - 1)//第三个[最后一个]
                            {
                                //只对最后两个关卡进行操作[注意自身顶部的关卡状态]
                                for (int isLinkingLevelNode = -1; isLinkingLevelNode < 1; isLinkingLevelNode++)
                                {
                                    //避免有连接交叉情况
                                    if (isLinkingLevelNode == -1)
                                    {
                                        if ( currentLevelNodes[index+isLinkingLevelNode].ConnectNextNodes.Contains(nextLevelNodes[index]))//如果同级上一个关卡要连接的关卡包含了中间的就不连接了
                                        {   //nextLevelNodes[index].Islinked == true//如果是被连接状态说明前一关卡对其有连接
                                            continue;//直接跳过
                                        }
                                        else
                                        {
                                            isLinking = Random.Range(0, 2);//在[0,1]之间随机，如果是0代表对该关卡不连接，反之则连接
                                            if (isLinking == 1)//连接
                                            {
                                                
                                                //将要连接的关卡放入当前关卡的连接列表里
                                                currentLevelNodes[index].ConnectNextNodes.Add(nextLevelNodes[index + isLinkingLevelNode]);
                                                //将当前关卡和要连接关卡的逻辑状态修改
                                                currentLevelNodes[index].Islinking = true;
                                                nextLevelNodes[index + isLinkingLevelNode].Islinked = true;
                                                levelLinkCount++;
                                            }

                                        }
                                    } else if(isLinkingLevelNode == 0)
                                    {
                                        //该关卡头顶关卡Node
                                        isLinking = Random.Range(0, 2);//在[0,1]之间随机，如果是0代表对该关卡不连接，反之则连接
                                        if (isLinking == 1)//连接
                                        {
                                            //将要连接的关卡放入当前关卡的连接列表里
                                            currentLevelNodes[index].ConnectNextNodes.Add(nextLevelNodes[index + isLinkingLevelNode]);
                                            //将当前关卡和要连接关卡的逻辑状态修改
                                            currentLevelNodes[index].Islinking = true;
                                            nextLevelNodes[index + isLinkingLevelNode].Islinked = true;
                                            levelLinkCount++;
                                        }
                                    }
                                    
                                }
                            }
                            else//其余[中间的]
                            {
                                //对下一级的左 中 右关卡进行操作
                                for (int isLinkingLevelNode = -1; isLinkingLevelNode < 2; isLinkingLevelNode++)
                                {
                                    //避免有连接交叉[注意中间的状态]
                                    if (isLinkingLevelNode == -1)
                                    {
                                        if (currentLevelNodes[index+isLinkingLevelNode].ConnectNextNodes.Contains(nextLevelNodes[index]))//如果同级上一个关卡要连接的关卡包含了中间的就不连接了
                                        {   //nextLevelNodes[index].Islinked == true//如果是被连接状态说明前一关卡对其有连接
                                            continue;//直接跳过对其的连接
                                        }
                                        else//前一关卡没有连接
                                        {
                                            isLinking = Random.Range(0, 2);//在[0,1]之间随机，如果是0代表对该关卡不连接，反之则连接
                                            if (isLinking == 1)//连接
                                            {
                                                //将要连接的关卡放入当前关卡的连接列表里
                                                currentLevelNodes[index].ConnectNextNodes.Add(nextLevelNodes[index + isLinkingLevelNode]);
                                                //将当前关卡和要连接关卡的逻辑状态修改
                                                currentLevelNodes[index].Islinking = true;
                                                nextLevelNodes[index + isLinkingLevelNode].Islinked = true;
                                                levelLinkCount++;
                                            }
                                        }
                                    }//中间和右边 [右边需要预先给好状态]
                                    else if (isLinkingLevelNode == 0)//中间
                                    {
                                        isLinking = Random.Range(0, 2);
                                        if (isLinking == 1)
                                        {
                                            //将要连接的关卡放入当前关卡的连接列表里
                                            currentLevelNodes[index].ConnectNextNodes.Add(nextLevelNodes[index + isLinkingLevelNode]);
                                            //将当前关卡和要连接关卡的逻辑状态修改
                                            currentLevelNodes[index].Islinking = true;
                                            nextLevelNodes[index + isLinkingLevelNode].Islinked = true;
                                            levelLinkCount++;
                                        }
                                    }
                                    else if (isLinkingLevelNode == 1)//右边[只需要对该关卡进行完整逻辑状态修改]
                                    {
                                        isLinking = Random.Range(0, 2);//在[0,1]之间随机，如果是0代表对该关卡不连接，反之则连接
                                        if (isLinking == 1)//如果是1代表连接
                                        {
                                            //将要连接的关卡放入当前关卡的连接列表里
                                            currentLevelNodes[index].ConnectNextNodes.Add(nextLevelNodes[index + isLinkingLevelNode]);
                                            //将当前关卡和要连接关卡的逻辑状态修改
                                            currentLevelNodes[index].Islinking = true;
                                            nextLevelNodes[index + isLinkingLevelNode].Islinked = true;
                                            levelLinkCount++;
                                        }
                                        else
                                        {
                                            //下一级的关卡不连接[修改逻辑状态]
                                            nextLevelNodes[index + isLinkingLevelNode].Islinked = false;
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                } while (levelLinkCount < original_Level[level].Count);//[该级的连接数>=当前级关卡个数]

                //针对其他特殊情况[再分配]
                //再对该级的所有关卡循环检测[注意第一级]
                if (level != 0)//不是第一级的
                {
                    List<LevelNode> lastLevelNodes = original_Level[level-1];//拿到初次分配好的上一级关卡
                    for (int index = 0; index < original_Level[level].Count; index++)//级内循环所有关卡
                    {
                        //[有主动连接的,没有被连接的] [先让他被正下方的关卡连接] [可以更灵活]
                        if (currentLevelNodes[index].Islinking == true && currentLevelNodes[index].Islinked == false)
                        {
                            if(!lastLevelNodes[index].ConnectNextNodes.Contains(currentLevelNodes[index]))
                            {
                                //注意三个区间
                                //避免交叉[注意与右下]
                                lastLevelNodes[index].ConnectNextNodes.Add(currentLevelNodes[index]);
                                //修改两者的逻辑状态
                                currentLevelNodes[index].Islinked = true;
                                lastLevelNodes[index].Islinking = true;
                            }
                        }
                        //[没有主动连接的,有被连接的] [考虑是否会交叉]->因为前面已经初次分配好了,需要格外注意
                        if (currentLevelNodes[index].Islinking == false && currentLevelNodes[index].Islinked == true)
                        {
                            //第一个
                            if (index == 0)//注意正上和右边的
                            {
                                for (int isLinkingLevelNode = 0; isLinkingLevelNode < 2; isLinkingLevelNode++)//要连接下一级的关卡
                                {
                                    //先检测右边的
                                    if (isLinkingLevelNode == 1)
                                    {
                                        //检测同级下一关卡是否有连接正上[检测交叉情况]
                                        if (!currentLevelNodes[index + isLinkingLevelNode].ConnectNextNodes.Contains(nextLevelNodes[index]))//如果不包含[随机连接右边的]
                                        {
                                            isLinking = Random.Range(0, 2);
                                            if (isLinking == 1)//连接
                                            {
                                                currentLevelNodes[index].ConnectNextNodes.Add(nextLevelNodes[index + isLinkingLevelNode]);//将右边添加进要连接的列表里
                                                //修改逻辑状态
                                                currentLevelNodes[index].Islinking = true;
                                                nextLevelNodes[index + isLinkingLevelNode].Islinked = true;
                                            }
                                            else//不连接就去连正上的[如果自身没有连接的话] 
                                            {
                                                if (!currentLevelNodes[index].ConnectNextNodes.Contains(nextLevelNodes[index]))
                                                {
                                                    currentLevelNodes[index].ConnectNextNodes.Add(nextLevelNodes[index]);//正上[中间]的关卡
                                                    //修改逻辑状态
                                                    currentLevelNodes[index].Islinking = true;
                                                    nextLevelNodes[index].Islinked = true;
                                                }
                                            }
                                        }else//如果包含那就连正上，如果自身没连那就连接
                                        {
                                            if (!currentLevelNodes[index].ConnectNextNodes.Contains(nextLevelNodes[index]))
                                            { 
                                                currentLevelNodes[index].ConnectNextNodes.Add(nextLevelNodes[index]);//正上[中间]的关卡
                                                //修改逻辑状态
                                                currentLevelNodes[index].Islinking = true;
                                                nextLevelNodes[index].Islinked = true;
                                            }
                                        }
                                    }
                                    else//正上的随机[先对正上进行随机]
                                    {
                                        isLinking = Random.Range(0, 2);
                                        if (isLinking == 1)//连接
                                        {
                                            currentLevelNodes[index].ConnectNextNodes.Add(nextLevelNodes[index]);//正上[中间]的关卡
                                            //修改逻辑状态
                                            currentLevelNodes[index].Islinking = true;
                                            nextLevelNodes[index].Islinked = true;
                                        }
                                    }
                                }
                            }
                            //最后一个
                            else if (index == original_Level[level].Count - 1)//左边 正上中间
                            {
                                //下一级要连接的关卡
                                for (int isLinkingLevelNode = -1; isLinkingLevelNode < 1; isLinkingLevelNode++)
                                {
                                    //对于左边的连接需要注意中间是否被连接了
                                    if (isLinkingLevelNode == -1)//下一级左边的关卡
                                    {
                                        if (!currentLevelNodes[index + isLinkingLevelNode].ConnectNextNodes.Contains(nextLevelNodes[index]))//如果不包含就是同级上一个关卡没有连接
                                        {
                                            isLinking = Random.Range(0, 2);//随机连接
                                            if (isLinking == 1)//连接
                                            {
                                                currentLevelNodes[index].ConnectNextNodes.Add(nextLevelNodes[index + isLinkingLevelNode]);//将右边添加进要连接的列表里
                                                //修改逻辑状态
                                                currentLevelNodes[index].Islinking = true;
                                                nextLevelNodes[index + isLinkingLevelNode].Islinked = true;
                                            }
                                            else//不连接随机连接正上
                                            {
                                                if (!currentLevelNodes[index].ConnectNextNodes.Contains(nextLevelNodes[index]))
                                                {
                                                    isLinking = Random.Range(0, 2);
                                                    if (isLinking == 1)//连接
                                                    {
                                                        currentLevelNodes[index].ConnectNextNodes.Add(nextLevelNodes[index]);//正上[中间]的关卡
                                                        //修改逻辑状态
                                                        currentLevelNodes[index].Islinking = true;
                                                        nextLevelNodes[index].Islinked = true;
                                                    }
                                                }
                                            }
                                        }else//如果包含那就连正上，如果自身没连那就随机连接
                                        {
                                            if (!currentLevelNodes[index].ConnectNextNodes.Contains(nextLevelNodes[index]))
                                            {
                                                isLinking = Random.Range(0,2);
                                                if(isLinking == 1)//连接
                                                {
                                                    currentLevelNodes[index].ConnectNextNodes.Add(nextLevelNodes[index]);//正上[中间]的关卡
                                                    //修改逻辑状态
                                                    currentLevelNodes[index].Islinking = true;
                                                    nextLevelNodes[index].Islinked = true;
                                                }
                                            }
                                        }
                                    }
                                    else//正上的[正上是最后储备，必须连接，所以随机的放在前面]
                                    {
                                        if(!currentLevelNodes[index].ConnectNextNodes.Contains(nextLevelNodes[index]))//如果不包含没连接的话
                                        {
                                            currentLevelNodes[index].ConnectNextNodes.Add(nextLevelNodes[index + isLinkingLevelNode]);
                                            //修改逻辑状态
                                            currentLevelNodes[index].Islinking = true;
                                            nextLevelNodes[index + isLinkingLevelNode].Islinked = true;
                                            //强制让他连接正上方中间的
                                        }
                                    }
                                }
                            }
                            else//中间,避免交叉
                            {//连接左边询问同级上一个关卡 连接右边询问同级下一个关卡是否连接
                                for (int isLinkingLevelNode = -1; isLinkingLevelNode < 2; isLinkingLevelNode++)
                                {
                                    if (isLinkingLevelNode == -1)//左边
                                    {
                                        if (!currentLevelNodes[index + isLinkingLevelNode].ConnectNextNodes.Contains(nextLevelNodes[index]))//如果同级上一个关卡没有连接中间的
                                        {
                                            isLinking = Random.Range(0, 2);//随机连接
                                            if (isLinking == 1)//连接
                                            {
                                                currentLevelNodes[index].ConnectNextNodes.Add(nextLevelNodes[index + isLinkingLevelNode]);//将左边添加进要连接的列表里
                                                //修改逻辑状态
                                                currentLevelNodes[index].Islinking = true;
                                                nextLevelNodes[index + isLinkingLevelNode].Islinked = true;
                                            }
                                            // else//不连接就去连正上的[如果自身没有连接的话] 
                                            // {
                                            //     if (!currentLevelNodes[index].ConnectNextNodes.Contains(nextLevelNodes[index]))
                                            //     {
                                            //         currentLevelNodes[index].ConnectNextNodes.Add(nextLevelNodes[index]);//正上[中间]的关卡
                                            //         //修改逻辑状态
                                            //         currentLevelNodes[index].Islinking = true;
                                            //         nextLevelNodes[index].Islinked = true;
                                            //     }
                                            // }
                                        }
                                        // else//包含那就连接正上
                                        // {
                                        //     if (!currentLevelNodes[index].ConnectNextNodes.Contains(nextLevelNodes[index]))
                                        //     {
                                        //         currentLevelNodes[index].ConnectNextNodes.Add(nextLevelNodes[index]);//正上[中间]的关卡
                                        //         //修改逻辑状态
                                        //         currentLevelNodes[index].Islinking = true;
                                        //         nextLevelNodes[index].Islinked = true;
                                        //     }
                                        // }
                                    }
                                    else if (isLinkingLevelNode == 1)//右边 [要有最后储备]
                                    {
                                        if (!currentLevelNodes[index + isLinkingLevelNode].ConnectNextNodes.Contains(nextLevelNodes[index]))//如果同级下一个关卡没有连接中间的
                                        {
                                            isLinking = Random.Range(0, 2);//随机连接
                                            if (isLinking == 1)//连接
                                            {
                                                currentLevelNodes[index].ConnectNextNodes.Add(nextLevelNodes[index + isLinkingLevelNode]);//将右边添加进要连接的列表里
                                                //修改逻辑状态
                                                currentLevelNodes[index].Islinking = true;
                                                nextLevelNodes[index + isLinkingLevelNode].Islinked = true;
                                            }
                                            else//不连接就去连正上的[如果自身没有连接的话] 
                                            {
                                                if (!currentLevelNodes[index].ConnectNextNodes.Contains(nextLevelNodes[index]))
                                                {
                                                    currentLevelNodes[index].ConnectNextNodes.Add(nextLevelNodes[index]);//正上[中间]的关卡
                                                    //修改逻辑状态
                                                    currentLevelNodes[index].Islinking = true;
                                                    nextLevelNodes[index].Islinked = true;
                                                }
                                            }
                                        }else//如果包含那连接正上[如果中间没被连接的话]
                                        {
                                            if (!currentLevelNodes[index].ConnectNextNodes.Contains(nextLevelNodes[index]))
                                            {
                                                currentLevelNodes[index].ConnectNextNodes.Add(nextLevelNodes[index]);//正上[中间]的关卡
                                                //修改逻辑状态
                                                currentLevelNodes[index].Islinking = true;
                                                nextLevelNodes[index].Islinked = true;
                                            }
                                        }
                                    }
                                    else//正上的
                                    {
                                        //再给一次机会随机是否连接
                                        isLinking = Random.Range(0, 2);
                                        if (isLinking == 1)//连接
                                        {
                                            currentLevelNodes[index].ConnectNextNodes.Add(nextLevelNodes[index + isLinkingLevelNode]);
                                            //修改逻辑状态
                                            currentLevelNodes[index].Islinking = true;
                                            nextLevelNodes[index + isLinkingLevelNode].Islinked = true;
                                        }
                                        //不连接会强制让他连接正上方中间的
                                    }
                                }
                            }
                        }
                        //[没有主动连接,没有被连接][状态调整为未激活消失]
                        if (currentLevelNodes[index].Islinking == false && currentLevelNodes[index].Islinked == false)
                        {
                            currentLevelNodes[index].IsActivated = false;//双非不激活显示
                        }
                    }
                }
                else//第一级情况[没主动连接,没有被连接] [主动连接,没有被连接]->不用操作
                {
                    for (int index = 0; index < original_Level[level].Count; index++)
                    {
                        //将激活状态调整为不激活
                        if (currentLevelNodes[index].Islinking == false && currentLevelNodes[index].Islinked == false)
                        {
                            currentLevelNodes[index].IsActivated = false;
                        }
                    }
                }
            }
            else//确保倒数第二级关全部连接倒数第一关Boss关
            {
                
                //检测倒数第二级内的关卡是否被连接
                for(int index = 0;index < original_Level[level].Count; index++)
                {
                    //没被连接[概率很小]那就也别连接Boss关了
                    if(currentLevelNodes[index].Islinked == false)
                    {
                        //调整逻辑状态
                        currentLevelNodes[index].Islinking = false;
                        currentLevelNodes[index].IsActivated = false;
                    }
                    else if(currentLevelNodes[index].Islinked == true)//被连接
                    {
                        currentLevelNodes[index].ConnectNextNodes.Add(nextLevelNodes[0]);//添加的是预设好的Boss关 列表里的唯一一个
                        //设置逻辑状态
                        currentLevelNodes[index].Islinking = true;
                        nextLevelNodes[0].Islinked = true;
                    }
                }
            }
        }
        //--------------------------随机关卡种类分配------------------------------------
        //------------列关卡种类限制-----------
        int row0_Limit_JY = 1;
        int row0_Limit_SP = 1;
        int row1_Limit_JY = 1;
        int row1_Limit_SP = 1;
        int row2_Limit_JY = 1;
        int row2_Limit_SP = 1;
        //------------列当前关卡种类数量
        int row0_current_JY = 0;
        int row0_current_SP = 0;
        int row1_current_JY = 0;
        int row1_current_SP = 0;
        int row2_current_JY = 0;
        int row2_current_SP = 0;
        int pbb_XG = 100;//小怪初始的概率
        int pbb_JY = 0;
        int pbb_Special = 0;
        //-----关卡种类字符串-----
        string xg = "XG";//小怪
        string jy = "JY";
        string boss = "Boss";
        string blackMarket = "BlackMarket";
        string ruin = "Ruin";
        string supply = "Supply";

        for(int level = 0;level < original_Level.Count;level++)//关卡级循环[全部都需要]
        {
            List<LevelNode> currentLevelNodes = original_Level[level];//拿到当前级的关卡
            if(level == original_Level.Count - 1)//单独处理Boss关
            {
                currentLevelNodes[0].levelType = boss;
            }else
            {
                //到规定的层数修改关卡种类数量限制
                if(level % 5 == 0 && level != 0)
                {
                    row0_Limit_JY += 1;
                    row1_Limit_JY += 1;
                    row2_Limit_JY += 1;
                }
                if(level % 3 == 0 && level != 0)
                {
                    row0_Limit_SP += 1;
                    row1_Limit_SP += 1;
                    row2_Limit_SP += 1;
                }
                //计算概率
                pbb_XG = pbb_XG - level * 10;
                pbb_JY = pbb_JY + level * 7;
                pbb_Special = pbb_Special + level * 3;
                for (int row = 0; row < currentLevelNodes.Count; row++)
                {
                    //分成三列[0,1,2]
                    if (row == 0)//第1列
                    {
                        //进行抽关卡
                        int random = Random.Range(0, 100);
                        if (random >= 0 && random < pbb_JY && row0_current_JY < row0_Limit_JY)//精英
                        {
                            currentLevelNodes[row].levelType = jy;
                            //修改当前限制
                            row0_current_JY += 1;
                        }
                        else if (random >= pbb_JY && random < pbb_JY + pbb_Special && row0_current_SP < row0_Limit_SP)//特殊关卡
                        {
                            int random_SP = Random.Range(0, 3);
                            if (random_SP == 0)//遗迹
                            {
                                currentLevelNodes[row].levelType = ruin;
                            }
                            else if (random_SP == 1)//补给
                            {
                                currentLevelNodes[row].levelType = supply;
                            }
                            else if (random_SP == 2)//黑市
                            {
                                currentLevelNodes[row].levelType = blackMarket;
                            }
                            //修改当前限制
                            row0_current_SP += 1;
                        }
                        else//剩下的情况全当小怪处理
                        {
                            currentLevelNodes[row].levelType = xg;
                        }
                    }
                    else if (row == 1)//第2列
                    {
                        //进行抽关卡
                        int random = Random.Range(0, 100);
                        if (random >= 0 && random < pbb_JY && row1_current_JY < row1_Limit_JY)//精英
                        {
                            currentLevelNodes[row].levelType = jy;
                            //修改当前限制
                            row1_current_JY += 1;
                        }
                        else if (random >= pbb_JY && random < pbb_JY + pbb_Special && row1_current_SP < row1_Limit_SP)//特殊关卡
                        {
                            int random_SP = Random.Range(0, 3);
                            if (random_SP == 0)//遗迹
                            {
                                currentLevelNodes[row].levelType = ruin;
                            }
                            else if (random_SP == 1)//补给
                            {
                                currentLevelNodes[row].levelType = supply;
                            }
                            else if (random_SP == 2)//黑市
                            {
                                currentLevelNodes[row].levelType = blackMarket;
                            }
                            //修改当前限制
                            row1_current_SP += 1;
                        }
                        else//剩下的情况全当小怪处理
                        {
                            currentLevelNodes[row].levelType = xg;
                        }
                    }
                    else if (row == 2)//第3列
                    {
                        //进行抽关卡
                        int random = Random.Range(0, 100);
                        if (random >= 0 && random < pbb_JY && row2_current_JY < row2_Limit_JY)//精英
                        {
                            currentLevelNodes[row].levelType = jy;
                            //修改当前限制
                            row2_current_JY += 1;
                        }
                        else if (random >= pbb_JY && random < pbb_JY + pbb_Special && row2_current_SP < row2_Limit_SP)//特殊关卡
                        {
                            int random_SP = Random.Range(0, 3);
                            if (random_SP == 0)//遗迹
                            {
                                currentLevelNodes[row].levelType = ruin;
                            }
                            else if (random_SP == 1)//补给
                            {
                                currentLevelNodes[row].levelType = supply;
                            }
                            else if (random_SP == 2)//黑市
                            {
                                currentLevelNodes[row].levelType = blackMarket;
                            }
                            //修改当前限制
                            row2_current_SP += 1;
                        }
                        else//剩下的情况全当小怪处理
                        {
                            currentLevelNodes[row].levelType = xg;
                        }
                    }
                }
            }
        }
        Debug.Log("生成完毕");
        return original_Level;//返回最终值
    }
}


