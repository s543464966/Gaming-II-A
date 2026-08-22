using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public static class Manager_Talent
{
    // Start is called before the first frame update
    //用字典的键值对来对应保存英雄和英雄所激活的天赋，键---英雄[string];值---所激活的天赋[list]
    private static Dictionary<string, List<Example_SO_Talent>> hero_Talent = new Dictionary<string, List<Example_SO_Talent>>();//英雄天赋数据库
    
    //天赋点数 首先  还是要先判断名字有没有激活保存的记录       天赋上这样就可以有[所需消耗天赋点]多少了；
    //        然后  进一步的根据该英雄的点数来判断能不能点该天赋
    public static void AddHeroTalent(string name, Example_SO_Talent talent)//外部激活天赋接口
    {
        if (hero_Talent.ContainsKey(name))//首先判断该英雄是否在天赋数据库里有激活情况[相对于该英雄有没有开户]
        {
            hero_Talent[name].Add(talent);//如果有的话就给他的天赋列表里保存新激活的天赋[开户了相对于前面就已经有激活过天赋了]

        }
        else//如果该英雄还未有激活的天赋
        {
            List<Example_SO_Talent> talents = new List<Example_SO_Talent>();//新建一个value列表来保存
            talents.Add(talent);//将该激活天赋保存进所对应的列表里
            hero_Talent.Add(name, talents);//再给字典里记录好该英雄的名字与天赋所绑定
        }
    }
    public static bool IsOnlyTalentActivated(string name,Example_SO_Talent talent)//查询该英雄是否激活该天赋的外部接口[防止重复加点] //加载天赋的时候，调用仓库 如果有就给亮，没有给暗
    {

        //首先判断传入的英雄名所对应的天赋列表里有没有所传入的天赋
        if (hero_Talent.ContainsKey(name))//判断该英雄在天赋字典库里开户了没[开户了至少有一个激活的天赋]
        {
            //如果开户了的话就开找[因为开户了才有的找，不然要👇要判断null]
            List<Example_SO_Talent> talents = hero_Talent[name];//先获得所对应的列表//通过传入的[string]英雄键值访问字典获得对应的Value列表

            //通过循环判断是否该列表里记录了该天赋
            foreach (Example_SO_Talent example_SO_Talent in talents)
            {
                //如果列表里有该激活的天赋 那么返回true代表已经激活过了
                if (talent == example_SO_Talent)
                {
                    return true;
                }
            }
        }
        //如果啥都没有的话就返回false代表还没激活是可激活状态
        return false;
    }

    //外部调用接口获取最新天赋字典数据库
    public static Dictionary<string, List<Example_SO_Talent>> GetAllHeroTalents()
    {
        return hero_Talent;
    }

    //外部调用接口输入英雄名Key进行逻辑清零对应的Value天赋列表
    public static void ClearTalentList(string name)
    {
        if(hero_Talent.ContainsKey(name))
        {
            hero_Talent[name].Clear();//如果天赋字典库里开了户，可以调用值列表的清除方法置零
            Debug.Log("置零了");
        }
        else
        {
            //如果没有则[这里是给重置天赋设置的，并且没有点天赋（开了户）]
        }
    }
}
