// using System;
using System.Collections;
using System.Collections.Generic;
using TMPro;
using UnityEngine;

public class zzzFighting_RushMonster : MonoBehaviour   //刷怪
{
    //初始化
        [HideInInspector] public zzzSkill_Matching Fighting_StarmanaSelect; //预置, 星能之力控制器
        [HideInInspector] public GameObject player;
        [HideInInspector] public GameObject bossHp; //预置 Boss血条
        [HideInInspector] public GameObject tipsRushMonster; //预置 刷怪提示框
        // private Dictionary<string,SO_Gate> SO_GateDict;
        // private SO_Gate gateData;
        private int monsterNum = 2;
        private float gateTime = 10;  //关卡时间min
        private int gateWave = 1; //关卡刷怪次数
        private int waveRushTime = 40;    //波数刷怪时间
        private float waveStopTime = 10; //波数停止刷怪
        private float timer_Wave; //一波刷怪周期计时器
        private float timer_Rush; //计时器
        private bool advanceRush = false;   //判断是否允许提前刷怪
        private bool bossRush = false;  //判断是否已经刷出Boss
    
    void Awake()
    {
        // SO_GateDict = new Dictionary<string, SO_Gate>();
        Fighting_StarmanaSelect = FindObjectOfType<zzzSkill_Matching>(); //预置, 星能之力控制器
        bossHp = GameObject.Find("UI_BossHp"); //预置,找到血条
        tipsRushMonster = GameObject.Find("UI_Tips"); //预置,找到提示框
    }

    void Start()
    {
        gateTime = gateTime * 60; //设定时间分钟变秒
        player = GameObject.FindGameObjectWithTag("Player");
        LoadSO();
    }

    void LoadSO()
    {
        // SO_Gate[] SO_Gates = Resources.LoadAll<SO_Gate>("Gate");   //将所有预置数据加载起
        // foreach (var SO_Gate in SO_Gates) //将所有预置数据放置到字典中，并按照星能变量来放置
        // {
        //     if (SO_Gate.gateId == "fight01")
        //     {
        //         // SO_GateDict.Add(SO_Gate.gateID, SO_Gate);
        //         gateData = SO_Gate;
        //         Debug.Log("加载了一个SO_Gate: " + SO_Gate.gateId);
        //     }
        //     else
        //     {
        //         Debug.LogWarning($"Key {SO_Gate.gateId} 关卡不匹配. 已跳过...");
        //     }
        // }
        // Debug.Log("已完成所有SO加载.");
    }

    void Update()
    {
        if (gateTime > 0 )  
        {
            gateTime -= Time.deltaTime; //关卡倒计时
            if (timer_Wave > 0)   //判断是否暂停刷怪；
            {
                timer_Wave -= Time.deltaTime;
            }
            else
            {
                //刷新变量
                    timer_Wave = waveRushTime + waveStopTime;
                    timer_Rush = waveRushTime;
                //刷怪
                    StartCoroutine(ShowTips()); //刷怪提示
                    // Fighting_StarmanaSelect.StarmanaAdd(3); //获得3个星能点数
                    if(timer_Wave >= 1) StartCoroutine(MonsterWaveRush( 2f ,timer_Rush));    //控制刷怪

                    if(bossRush == false && gateWave >= 2)   //刷Boss，在第b波刷Boss
                    {
                        Create_MonsterBossRush(new Vector2(0,7.5f));    //在特定位置召唤Boss
                        bossRush = true;    //控制Boss只刷1次
                        bossHp.GetComponent<Canvas>().enabled = true;   //开启Boss血条
                    }

                //按照骰子点数获得对应数量的星能卡片
                    ////// 【调用】需要游戏暂停，并调用摇骰子的功能。
                    // Fighting_StarmanaSelect.GetComponent<Skill_Select>().StarmanaSortingNum(1);
                    // Fighting_StarmanaSelect.GetComponent<Skill_Select>().StarmanaSortingDice(); 

                //刷新变量
                    if(gateWave % 2 == 0) {monsterNum += 2;}  //每波怪物比上一次+2
                    gateWave += 1;  //刷怪波数 +1  
            }
        }
        else
        {
            Debug.Log("时间到，成功顶住怪物进攻，游戏胜利!"); //时间到，游戏胜利束
            //【对接】胜利，成功坚持X分钟,关卡结束的弹窗
        }
        
        if (Input.GetKeyDown(KeyCode.Alpha0))   //临时用与测试
        {
            AdvanceRushWave();
        }
    }

    void MonsterKeepRush()  //持续刷新
    {
        Vector3 rushPosition = RushArea_Random();
        Create_Monster(rushPosition);   //创建怪物
        // Instantiate(monster, spawnPosition, Quaternion.identity);   //创建怪物
    }

    IEnumerator MonsterWaveRush(float _interval,float _timer_Rush)  //按照波数刷新（间隔，刷新时长）
    {
        //初始变量
        float n = 0;
        float m = 10 + gateWave;
        _interval -= gateWave * 0.05f;
        if(gateWave <= 6) {_interval -= 0.05f;}

        //刷怪
        while(_timer_Rush > 0) 
        {
            
            Create_Monster(RushArea_Random());
            if(n % 5 == 4) 
            {
                Create_MonsterElite(RushArea_Random()); //刷精英怪物，每5次普通怪物刷新时，刷1只精英怪物
                for(int i = 0; i < monsterNum; i++) { Create_Monster(RushArea_Random()); }   //额外刷普通怪物，每X秒刷一波
            }    

            //刷新变量
            n ++;
            _timer_Rush -= _interval;

            //是否能够提前刷怪
            if(n > m)
            {
                //【调用】这里需要提供一个展示提前刷怪的按钮
                advanceRush = true;
            }

            yield return new WaitForSeconds(_interval);
            // monsterNum ++;
        }
    }

    public void AdvanceRushWave()
    {
        if (advanceRush == true)
        {
            timer_Wave = 0; // 强制开始新的刷怪周期
            advanceRush = false;
        }
    }

    Vector2 RushArea_Random()  //根据挂载物体大小来适配刷怪Box区域
    {
        Vector2 rushBoxSize = transform.localScale;
        Vector2 rushBoxCenter = transform.position;
        float randomX = Random.Range(rushBoxCenter.x - rushBoxSize.x / 2f, rushBoxCenter.x + rushBoxSize.x / 2f);
        float randomY = Random.Range(rushBoxCenter.y - rushBoxSize.y / 2f, rushBoxCenter.y + rushBoxSize.y / 2f);
        return new Vector2(randomX, randomY);
    }

    void Create_Monster(Vector3 _rushPosition)  //刷一个普通怪物
    {
        // int n = Random.Range(0,4);
        // int n = 0;  //测试用
        // GameObject _m =  Instantiate(gateData.gateMoster[n], _rushPosition, Quaternion.identity);
        // _m.GetComponent<zzzCC_Monster>().player = player;
        // _m.GetComponent<M_Damage_Monster>().RushWaveImprove(gateWave);
        // Debug.Log("是否刷");
        
    }
    void Create_MonsterElite(Vector3 _rushPosition)  //刷一个精英怪物
    {
        // GameObject _m = Instantiate(gateData.gateMosterElite[0], _rushPosition, Quaternion.identity);
        // _m.GetComponent<zzzCC_Monster>().player = player;
        // _m.GetComponent<C_Damage_Monster>().Fighting_StarmanaSelect = Fighting_StarmanaSelect;
        // _master.GetComponent<M_Damage_Monster>().hp = _master.GetComponent<M_Damage_Monster>().hp * 基础强度 * 难度设置
    }
    void Create_MonsterBossRush(Vector3 _rushPosition)  //刷一个Boss怪物
    {
        // GameObject _m = Instantiate(gateData.gateMosterBoss[0], _rushPosition, Quaternion.identity);
        // _m.GetComponent<C_Damage_Monster>().bossHpRed = bossHp;
    }   

    IEnumerator ShowTips()
    {
        tipsRushMonster.GetComponent<Canvas>().enabled = true;
        tipsRushMonster.GetComponentInChildren<TextMeshProUGUI>().text = $"第{gateWave}波怪物进攻 即将来袭";

        yield return new WaitForSeconds(5);
        tipsRushMonster.GetComponent<Canvas>().enabled = false;
    }

}
