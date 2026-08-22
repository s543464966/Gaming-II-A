using System.Collections;
using System.Collections.Generic;
using DG.Tweening;
using UnityEngine;
using UnityEngine.UI;

// public class Manager_PlayerDice : MonoBehaviour
// {
    //======骰子配置======//
//     private int dice_NUM;//骰子总共数量
//     public int singleDice_NUM;//单体骰子数量
//     public int groupDice_NUM;//群体骰子数量
//     public GameObject dice_Prefab;//骰子预制体
//     public GameObject dice_Blank_Prefab;    //骰子空白占位符
//     public float spacingMultiplier = 1.5f;  // <- 骰子间距从 1w 改成 1.5w，就设为 1.5
//     [HideInInspector] public List<GameObject> playerAllDices = new List<GameObject>();//玩家所有骰子
//     [HideInInspector] public List<GameObject> blankDicePlaces = new List<GameObject>();//骰子占位符
//     //======随机配置的参数======//
//     private int current_dice_ID = 0;
//     private int current_singleDice_NUM = 0;
//     private int current_groupDice_NUM = 0;
//     private bool isPlayerRound = false;//当前是玩家的回合
//     private bool isNewFirst = false;//  新手首轮
//     //======当前还剩多少骰子======//
//     private int current_dice_NUM = 0;
//     //======骰子的数据SO======//
//     public Sprite[] diceUI;
//     //======保留对方卡牌列表======//
//     [HideInInspector] public List<GameObject> playerFightCard;
//     public Manager_GwDice manager_GwDice;//怪物骰子管理器
//     //======群体效果队列对象======//
//     [HideInInspector] public Manager_ActionQueue manager_ActionQueue;
//     //======数据先计算确定======//
//     void Start()
//     {
//         //dice_NUM = singleDice_NUM + groupDice_NUM;//相加
//         //  更改为获取玩家骰子上限
//         if (CC_Chapter.Instance != null) dice_NUM = CC_Chapter.Instance.playerDiceMax;
//         Debug.Log("玩家骰子上限：" + dice_NUM);
//         //初始化骰子
//         Init_Dice();
//     }
    
//     //======初始化骰子======//
//     private void Init_Dice()
//     {
//         foreach (Transform child in transform)
//         {
//             Destroy(child.gameObject); //先清空残余子对象
//         }

//         AutoChangePlayerDicePlace(); //自动调整玩家骰子

//         //将实体骰子实例出来
//         for (int i = 0; i < dice_NUM; i++)
//         {
//             GameObject dice = Instantiate(dice_Prefab, gameObject.transform);//分配父对象
//             playerAllDices.Add(dice);//加入骰子里
//             dice.transform.position = blankDicePlaces[i].transform.position;//赋予位置
//             dice.GetComponent<PlayerDice>().originPos = dice.transform.position;//同步初始位置
//             dice.GetComponent<PlayerDice>().playerFightCard = playerFightCard;
//             dice.GetComponent<PlayerDice>().manager_ActionQueue = manager_ActionQueue;  //分配群体效果队列管理器
//             //分配脚本引用
//             dice.GetComponent<C_PlayerDice>().manager_PlayerDice = gameObject.GetComponent<Manager_PlayerDice>();
//         }
//         //调整透明度为0
//         foreach (Transform child in transform)
//         {
//             Color newColor = child.GetComponent<Image>().color;
//             newColor.a = 0f;
//             child.GetComponent<Image>().color = newColor;
//         }
//     }










    
//     //======自适应调整玩家骰子占位======//
//     private void AutoChangePlayerDicePlace()
//     {
//         RectTransform container = transform as RectTransform;   //自身
//         float itemWidth = dice_Blank_Prefab.GetComponent<RectTransform>().rect.width;   //获取预制体宽度
//         float slotWidth = itemWidth * spacingMultiplier; // <- 关键：每个格子的宽度（中心步进）
//         int count = dice_NUM;   //获取玩家骰子上限
//         // 奇数/偶数分别处理
//         if (count % 2 == 1)
//         {
//             // n = 3 -> idx: -1,0,1 -> x = idx * slotWidth => -w, 0, +w
//             int half = count / 2;
//             for (int i = 0; i < count; i++)
//             {
//                 int idx = i - half;
//                 float anchoredX = idx * slotWidth;
//                 //  生成实例
//                 GameObject diceBlank = Instantiate(dice_Blank_Prefab, container);
//                 RectTransform rt = diceBlank.GetComponent<RectTransform>(); //调整位置
//                 if (rt != null)
//                 {
//                     // 保证缩放正常（防止预制体带奇怪缩放）
//                     rt.localScale = Vector3.one;
//                     rt.anchoredPosition = new Vector2(anchoredX, 0f);
//                 }
//                 blankDicePlaces.Add(diceBlank.gameObject);
//             }
//         }
//         else
//         {
//             // n = 2 -> idx: -1,0 -> x = (idx + 0.5) * slotWidth => -0.5w, +0.5w
//             int half = count / 2;
//             for (int i = 0; i < count; i++)
//             {
//                 int idx = i - half;
//                 float anchoredX = (idx + 0.5f) * slotWidth;
//                 //  生成实例
//                 GameObject diceBlank = Instantiate(dice_Blank_Prefab, container);
//                 RectTransform rt = diceBlank.GetComponent<RectTransform>(); //调整位置
//                 if (rt != null)
//                 {
//                     // 保证缩放正常（防止预制体带奇怪缩放）
//                     rt.localScale = Vector3.one;
//                     rt.anchoredPosition = new Vector2(anchoredX, 0f);
//                 }
//                 blankDicePlaces.Add(diceBlank.gameObject);
//             }
//         }
//     }
//     //======随机分配======//
//     public void Init_Dice( List<int> _diceType)
//     {
//         //每次大随机时重置---下一轮
//         current_singleDice_NUM = 0;
//         current_groupDice_NUM = 0;
//         current_dice_ID = 0;    //玩家骰子固定位置ID
//         isPlayerRound = false;
//         //  更改为区分新手关卡
//         if (CC_Chapter.Instance != null)
//         {
//             if (!CC_Chapter.Instance.isCompleted_NewLevel && !isNewFirst)
//             {
//                 isNewFirst = true;  //  新手关卡首轮玩家骰子为0
//                 CloseLimit();   //  直接执行玩家回合并跳过
//                 return;
//             }
//             else
//             {
//                 current_dice_NUM = playerAllDices.Count;    //玩家现有骰子数
//             }
//         }
//         //循环分配 + 动画后续分配确认好后再播放
//         while (current_dice_ID < current_dice_NUM)
//         {
//             //======需要维护======//
//             int type = Random.Range(0, 2);
//             if (type == 0)//随机单体骰子
//             {
//                 if (current_singleDice_NUM < singleDice_NUM)
//                 {
//                     //这里是类型为单体的骰子
//                     playerAllDices[current_dice_ID].GetComponent<PlayerDice>().player_dice.Target = TargetType.Single;
//                     //需要维护类型的范围
//                     int effect = Random.Range(0, 3);
//                     if (effect == 0)//单体攻击
//                     {
//                         playerAllDices[current_dice_ID].GetComponent<PlayerDice>().player_dice.Effect = EffectType.Single_Attack;
//                         playerAllDices[current_dice_ID].GetComponent<Image>().sprite = diceUI[0];
//                     }
//                     else if (effect == 1)//单体技能
//                     {
//                         playerAllDices[current_dice_ID].GetComponent<PlayerDice>().player_dice.Effect = EffectType.Single_Skill;
//                         playerAllDices[current_dice_ID].GetComponent<Image>().sprite = diceUI[1];
//                     }
//                     else if (effect == 2)//单体恢复
//                     {
//                         playerAllDices[current_dice_ID].GetComponent<PlayerDice>().player_dice.Effect = EffectType.Single_Recover;
//                         playerAllDices[current_dice_ID].GetComponent<Image>().sprite = diceUI[2];
//                     }
//                     //配置完一个单体骰子要增加单体骰子配置数量
//                     current_singleDice_NUM++;
//                     current_dice_ID++;
//                 }
//             }
//             else if (type == 1)//随机群体骰子
//             {
//                 if (current_groupDice_NUM < groupDice_NUM)
//                 {
//                     //这里是类型为群体的骰子
//                     playerAllDices[current_dice_ID].GetComponent<PlayerDice>().player_dice.Target = TargetType.Group;
//                     //需要维护类型的范围
//                     int effect = Random.Range(0, 3);
//                     if (effect == 0)//群体攻击
//                     {
//                         playerAllDices[current_dice_ID].GetComponent<PlayerDice>().player_dice.Effect = EffectType.Group_Attack;
//                         playerAllDices[current_dice_ID].GetComponent<Image>().sprite = diceUI[3];
//                     }
//                     else if (effect == 1)//群体集火
//                     {
//                         playerAllDices[current_dice_ID].GetComponent<PlayerDice>().player_dice.Effect = EffectType.Group_Focus;
//                         playerAllDices[current_dice_ID].GetComponent<Image>().sprite = diceUI[4];
//                     }
//                     else if (effect == 2)//群体恢复
//                     {
//                         playerAllDices[current_dice_ID].GetComponent<PlayerDice>().player_dice.Effect = EffectType.Group_Recover;
//                         playerAllDices[current_dice_ID].GetComponent<Image>().sprite = diceUI[5];
//                     }
//                     //配置完一个单体骰子要增加单体骰子配置数量
//                     current_groupDice_NUM++;
//                     current_dice_ID++;
//                 }
//             }
//         }
//         //利用洗牌算法打乱
//         for (int i = 0; i < current_dice_NUM; i++) // 遍历所有骰子类型
//         {
//             // 从当前索引 i 到列表末尾随机选一个索引 j
//             int j = Random.Range(i, playerAllDices.Count);
//             // 交换位置 i 和 j 的元素
//             (playerAllDices[i], playerAllDices[j]) = (playerAllDices[j], playerAllDices[i]);
//         }
//         //洗完后应用位置并打开骰子能够使用
//         for (int i = 0; i < current_dice_NUM; i++)
//         {
//             playerAllDices[i].transform.position = blankDicePlaces[i].transform.position;
//             playerAllDices[i].GetComponent<PlayerDice>().originPos = playerAllDices[i].transform.position;
//             playerAllDices[i].GetComponent<C_PlayerDice>().isUsed = false;
//         }
//         //恢复全部骰子的透明度
//         Sequence reFade = DOTween.Sequence();
//         foreach (GameObject dice in playerAllDices)
//         {
//             Image dice_ui = dice.GetComponent<Image>();
//             Tween fade_Tween = dice_ui.DOFade(1f, 1.0f).SetEase(Ease.OutQuad);
//             reFade.Join(fade_Tween);
//         }
//         reFade.OnComplete(() =>
//         CloseLimit());//关闭使用骰子的限制
//     }
//     //======使用骰子「关闭限制」======//
//     public void CloseLimit()
//     {
//         if (current_dice_NUM == 0)
//         {
//             //如果是最后一个执行完再执行就到怪物的回合
//             manager_GwDice.GwUseDice(); //调用怪物的使用
//             isPlayerRound = false;
//             return;
//         }
//         isPlayerRound = true;//玩家可以使用骰子时为玩家的回合
//         //开放权限给玩家操控骰子
//         foreach (GameObject playerdice in playerAllDices)
//         {
//             if (playerdice.GetComponent<C_PlayerDice>().isUsed == false)//被使用过的不做操作
//             {
//                 //允许控制
//                 playerdice.GetComponent<C_PlayerDice>().isPlayerControl = true;
//             }
//         }
//     }
//     //======不能使用骰子「开启限制」======//
//     public void OpenLimit()
//     {
//         //关闭权限不给玩家操控骰子
//         foreach (GameObject playerdice in playerAllDices)
//         {
//             if (playerdice.GetComponent<C_PlayerDice>().isUsed == false)//被使用过的不做操作
//             {
//                 //不允许控制
//                 playerdice.GetComponent<C_PlayerDice>().isPlayerControl = false;
//             }
//         }
//     }
//     //======外部动作执行完毕调用======//
//     public void CardActionCompleted()
//     {
//         if (isPlayerRound == true)
//         {
//             //完成相当于该骰子使用掉了
//             current_dice_NUM--;
//             Debug.Log("当前是玩家的回合，玩家骰子剩余："+current_dice_NUM);
//             //再次开放权限给玩家
//             CloseLimit();
//         }
//     }
//     //======玩家和怪物的骰子占位符淡入动画======//
//     public Sequence BlankDiceFadeInTween()
//     {
//         //制作序列动画
//         Sequence allfade_in = DOTween.Sequence();
//         //所有占位符
//         foreach (GameObject blankDice in blankDicePlaces)
//         {
//             Tween fade_in = blankDice.GetComponent<Image>().DOFade(1.0f, 0.3f)
//                 .SetEase(Ease.InQuad);
//             allfade_in.Join(fade_in);
//         }
//         foreach (GameObject blankDice in manager_GwDice.blankDicePlaces)
//         {
//             Tween fade_in = blankDice.GetComponent<Image>().DOFade(1.0f, 0.3f)
//                 .SetEase(Ease.InQuad);
//             allfade_in.Join(fade_in);
//         }
//         return allfade_in;
//     }
// }
