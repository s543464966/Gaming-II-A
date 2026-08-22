using UnityEngine;
using System.Collections.Generic;
using TMPro;


public class zzzSkill_Matching : MonoBehaviour  //计算星能并激活星能之力
{
    // private string assetBundlePath = "/Users/shejuntao/Documents/MagicA/MoonStar/Assets/AssetBundles/Starmana";
    // private string assetNamePrefix = "sm_";
    // public Dictionary<int, SO_Skill> scriptableObjectDict = new Dictionary<int, SO_Skill>();
    // public List<SO_Skill> SO_SkillsListPrefarb; // 原始整数列表
    // private Dictionary<int, SO_Skill> SO_SkillsDict; // 原始整数列表
    public GameObject UI_StarmanaValue;
    public GameObject StarmanaCardPrafab;
    public int starmannVar;  //星能变量“编号”
    private int skillId; //星能值
    // private GameObject player; //玩家操控的角色
    // private GameObject weapon;  //玩家操控的角色的主武器
    // private List<int> RandomList; // 随机打乱后的整数列表
    // private List<int> RecoveryList; // 回收已使用的星能卡组


// //初始化
//     void Start()
//     {
//         SO_SkillsDict = new Dictionary<int, SO_Skill>();    //初始化技能字典；
//         // LoadSOSkills();   //初始化所有技能放置入字典中；
//         // player = GameObject.FindGameObjectWithTag("Player");    //获取玩家角色
//         // weapon = player.transform.Find("Weapon").gameObject;    //获取主武器
//         // RandomList = RandomStarmanaList( SD_Player.starmanaList );      //初始化随机卡组，并将玩家的卡组，随机处理
//         // RecoveryList = new List<int>();     //初始化回收卡组
//         // UI_StarmanaValue = GameObject.Find("UI_ButomBar");      //预置,找到提示框
//         // StarmanaAdd(3); //获得3个星能点数
//     }

    // void LoadSOSkills()  
    // {
    //     SO_Skill[] scriptableObjects = Resources.LoadAll<SO_Skill>("Skills");   //将所有预置数据加载起
    //     foreach (var scriptableObject in scriptableObjects) //将所有预置数据放置到字典中，并按照星能变量来放置
    //     {
    //         if (!SO_SkillsDict.ContainsKey(scriptableObject.skillId))
    //         {
    //             SO_SkillsDict.Add(scriptableObject.skillId, scriptableObject);
    //             Debug.Log("加载了一个SO: " + scriptableObject.skillId);
    //         }
    //         else
    //         {
    //             Debug.LogWarning($"Key {scriptableObject.skillId} 该字典空间已存在数据. 已跳过...");
    //         }
    //     }
    // }

    public void SkillMatching(int _skillId)   ////////【接受】!!!这里控制星能之力的使用!!!
    {
        // SO_Skill s = _SO_Skill;
        switch (_skillId)
        {
            //基础星能
            // case 0: StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama0(); break;
            // case 1: StarmanaAdd(s.skillUse); weapon.GetComponent<Weapon>().Starmama1(); break;
            // case 2: StarmanaAdd(s.skillUse); weapon.GetComponent<Weapon>().Starmama2(); break;
            // case 3: StarmanaAdd(s.skillUse); weapon.GetComponent<Weapon>().Starmama3(); break;
            // case 4: weapon.GetComponent<Weapon>().Starmama1(); break;
            // case 5: weapon.GetComponent<Weapon>().Starmama1(); break;
            // case 6: weapon.GetComponent<Weapon>().Starmama1(); break;
            // case 7: starmana += _SO_Skill.skillUse; break;

            // //岩系
            // case 101: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama101();} else StarmanaLow(); break;
            // case 102: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama102(s.starmanabullet);} else StarmanaLow(); break;
            // case 103: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama103(s.starmanaGuarder);} else StarmanaLow(); break;
            // case 1001: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama1001(s.starmanaEffect);} else StarmanaLow(); break;
            // case 1002: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama1002(s.starmanaOnOff);} else StarmanaLow(); break;
            // case 10003: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama10003(s.starmanaGuarder);} else StarmanaLow(); break;

            // //火系
            // case 201: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama201();} else StarmanaLow(); break;
            // case 202: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama202(s.starmanaGuarder);} else StarmanaLow(); break;
            // case 203: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama203(s.starmanabullet);} else StarmanaLow(); break;
            // case 2001: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama2001(s.starmanaEffect);} else StarmanaLow(); break;
            // case 20001: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama20001(s.starmanabullet);} else StarmanaLow(); break;
        
        
            // //风系
            // case 301: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama301();} else StarmanaLow(); break;
            // case 302: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama302();} else StarmanaLow(); break;
            // case 304: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama304(s.starmanabullet);} else StarmanaLow(); break;
            // case 305: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama305(s.starmanaEffect);} else StarmanaLow(); break;
            // case 3001: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama3001();} else StarmanaLow(); break;
            
            //为空
            default: Debug.Log("空，没有对应的星能!") ; break;
        }
        // Debug.Log("当前剩余星能：" + starmana);
        // RecoveryList.Add(s.skillId);    // 已使用过的卡组，在这里回收
    }

    // private List<int> RandomStarmanaList(List<int> _starmanaList)  //将卡组随机处理
    // {
    //     System.Random _random = new System.Random();
    //     List<int> _originalList = new List<int>(_starmanaList);
    //     List<int> _randomList = new List<int>();

    //     int i = _originalList.Count;
    //     while (i >= 1)
    //     {
    //         int _n = _random.Next(_originalList.Count);
    //         _randomList.Add(_originalList[_n]);
    //         _originalList.RemoveAt(_n);
    //         i--;
    //     }
    //     return _randomList;
    // }

//抽卡
    // public void StarmanaSortingNum(int _num) //抽取顺序数量的星能，
    // {
    //     // int diceNum = DiceRandom(); //随机骰子中的一个点数
    //     for (int i = 0; i < _num; i++) //抽和点数对应张数的卡
    //     {
    //         int num = RandomList[0]; //这里是确定抽出来的卡
    //         RandomList.RemoveAt(0); //将抽出来的卡移出卡组
    //         if( RandomList.Count <= 0 ) //剩余卡组数为0时重新刷新卡组
    //         {
    //             RandomList = RandomStarmanaList( RecoveryList);  //回收池中的卡组，随机处理
    //         }
    //         // 【调用】展示星能卡牌，并传递星能的SO
    //         StarmanaCardPrafab.GetComponent<SelectStarCards_UIManager>().ReceiveRandomData_StarCard(SO_SkillsDict[num]);
    //     }
    // }

    // public void StarmanaSortingDice() //按照随投资点数，抽取顺序数量的星能
    // {   
    //     int dicenum = UnityEngine.Random.Range(0, 5);
    //     StarmanaSortingNum(dicenum);
    // }


//选卡
    // void StarmanaAddWave() //在6张卡组中随机抽取1张，
    // {
    //     for (int i = 0; i < 6; i++) //抽和点数对应张数的卡
    //     {
    //         // int num = RandomList[0]; //这里是确定抽出来的卡
    //         // RandomList.RemoveAt(0); //将抽出来的卡移出卡组
    //         // if( RandomList.Count <= 0 ) //剩余卡组数为0时重新刷新卡组
    //         // {
    //         //     RandomList = RandomStarmanaList( RecoveryList);  //回收池中的卡组，随机处理
    //         // }

    //         // ////////  【对接】展示卡牌
    //         // StarmanaCardPrafab.GetComponent<SelectStarCards_UIManager>().ReceiveRandomData_StarCard(SO_SkillsDict[num]);
    //         // // Debug.Log( "抽中卡牌：" + s.starmanName);
    //     }
    // }

//使用
    // public void StarmanaPick(SO_Skill _SO_Skill)   ////////  【接受】!!!这里控制星能之力的使用!!!
    // {
    //     SO_Skill s = _SO_Skill;
    //     switch (_SO_Skill.skillId)
    //     {
    //         //基础星能
    //         case 0: StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama0(); break;
    //         // case 1: StarmanaAdd(s.skillUse); weapon.GetComponent<Weapon>().Starmama1(); break;
    //         // case 2: StarmanaAdd(s.skillUse); weapon.GetComponent<Weapon>().Starmama2(); break;
    //         // case 3: StarmanaAdd(s.skillUse); weapon.GetComponent<Weapon>().Starmama3(); break;
    //         // case 4: weapon.GetComponent<Weapon>().Starmama1(); break;
    //         // case 5: weapon.GetComponent<Weapon>().Starmama1(); break;
    //         // case 6: weapon.GetComponent<Weapon>().Starmama1(); break;
    //         case 7: starmana += _SO_Skill.skillUse; break;

    //         //岩系
    //         case 101: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama101();} else StarmanaLow(); break;
    //         case 102: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama102(s.starmanabullet);} else StarmanaLow(); break;
    //         case 103: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama103(s.starmanaGuarder);} else StarmanaLow(); break;
    //         case 1001: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama1001(s.starmanaEffect);} else StarmanaLow(); break;
    //         case 1002: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama1002(s.starmanaOnOff);} else StarmanaLow(); break;
    //         case 10003: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama10003(s.starmanaGuarder);} else StarmanaLow(); break;

    //         //火系
    //         case 201: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama201();} else StarmanaLow(); break;
    //         case 202: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama202(s.starmanaGuarder);} else StarmanaLow(); break;
    //         case 203: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama203(s.starmanabullet);} else StarmanaLow(); break;
    //         case 2001: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama2001(s.starmanaEffect);} else StarmanaLow(); break;
    //         case 20001: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama20001(s.starmanabullet);} else StarmanaLow(); break;
        
        
    //         //风系
    //         case 301: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama301();} else StarmanaLow(); break;
    //         case 302: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama302();} else StarmanaLow(); break;
    //         case 304: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama304(s.starmanabullet);} else StarmanaLow(); break;
    //         case 305: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama305(s.starmanaEffect);} else StarmanaLow(); break;
    //         case 3001: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama3001();} else StarmanaLow(); break;
            
    //         //为空
    //         default: Debug.Log("空，没有对应的星能!") ; break;
    //     }
    //     Debug.Log("当前剩余星能：" + starmana);
    //     RecoveryList.Add(s.skillId);    // 已使用过的卡组，在这里回收
    // }

    // public void StarmanaDiscount()  //【提供】!!!这里分解星能之力!!!
    // {
    //     Debug.Log("星能之力分解成功");
    //     starmana += 1;
    // }

    // public void StarmanaAdd(int _skillUse) //这里需要加一个性能不足的判断条件，能量不足时，需要变灰展示；
    // {
    //     starmana += _skillUse;
    //     // UI_StarmanaValue.GetComponentInChildren<TextMeshProUGUI>().text = $"{starmana}";
    //     Debug.Log("当前剩余星能：" + starmana);
    // }

    // public int ReadStarmanaValue()  //获得星能值
    // {
    //     return starmana;
    // }

    // public void StarmanaLow() //这里需要加一个性能不足的判断条件，能量不足时，需要变灰展示；
    // {
    //     Debug.Log("星能不足");
    // }
}