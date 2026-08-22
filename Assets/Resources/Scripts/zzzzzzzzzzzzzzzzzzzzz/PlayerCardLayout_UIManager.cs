using System.Collections;
using System.Collections.Generic;
using System.Linq;
using DG.Tweening;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

public class PlayerCardLayout_UIManager : MonoBehaviour
{
    [Header("Grid Settings")]
    private int rows;//行数
    private int columns;//列数
    private Vector2 cardSize;
    //======控制的按钮======//
    public Button playButton;
    public Button returnButton;
    public Button settingButton;
    public Button changeTeamButton;
    private const float FADE_DURATION = 0.6f;
    //保存玩家卡牌列表
    [Header("占位符位置")]public List<GameObject> blankAllCard = new List<GameObject>();//所有白卡
    private List<Vector2> playerFightCard_Pos = new List<Vector2>();//保存位置
    private List<GameObject> playerFightCard;//玩家出战卡牌
    private List<GameObject> playerAllCard;//玩家所有卡牌
    private List<GameObject> gwAllCard;//怪物卡牌引用
    //======关联的脚本======//
    // public Init_FightingCard init_FightingCard;//初始化的脚本
    // private Manager_PlayerDice manager_PlayerDice;
    // private Manager_GwDice manager_GwDice;
    //======ui检测======//
    private GraphicRaycaster graphicRaycaster;
    [Header("CardPrefab")]
    public GameObject blankCard_prefab;//占位白卡预制体
    // private void Awake()
    // {
    //     graphicRaycaster = GetComponentInParent<GraphicRaycaster>();
    //     //隐藏的按钮
    //     Color newColor = settingButton.GetComponent<Image>().color;
    //     newColor.a = 0f;
    //     settingButton.GetComponent<Image>().color = newColor;
    // }
    // void Start()
    // {
    //     //拿取骰子管理器
    //     // manager_PlayerDice = init_FightingCard.manager_PlayerDice;
    //     // manager_GwDice = init_FightingCard.manager_GwDice;
    //     // //获取玩家出战卡牌
    //     // playerFightCard = init_FightingCard.playerFightCard;
    //     // playerAllCard = init_FightingCard.playerAllCards;
    //     // gwAllCard = init_FightingCard.gwAllCard;//拿到怪物卡牌列表
    //     // //获得预制体的尺寸
    //     // cardSize = init_FightingCard.fightingCard_prefab.GetComponent<RectTransform>().sizeDelta;
    //     // blankCard_prefab.GetComponent<RectTransform>().sizeDelta = cardSize;//修改白卡尺寸
    //     // //获取出战位行列
    //     // rows = init_FightingCard.player_rows;
    //     // columns = init_FightingCard.player_columns;
    //     //  摆放卡牌
    //     // ArrangeCards();
    // }
    // void ArrangeCards()
    // {
    //     //  定义起始索引
    //     int blankCard_Index = 0;
    //     //计算对应位置
    //     for (int i = 0; i < rows; i++)
    //     {
    //         for (int j = 0; j < columns; j++)
    //         {
    //             GameObject blankCard = blankAllCard[blankCard_Index];
    //             //给占位白卡初始化行列位置
    //             // blankCard.GetComponent<BlankCard>().blankCard_Row = i;
    //             // blankCard.GetComponent<BlankCard>().blankCard_Column = j;
    //             Vector2 card_Pos = blankCard.transform.position;
    //             playerFightCard_Pos.Add(card_Pos);
    //             Debug.Log(card_Pos);
    //             //  索引自增
    //             blankCard_Index++;
    //         }
    //     }
    //     //将玩家出战卡牌转移过来并更新位置
    //     for (int i = 0; i < playerFightCard.Count; i++) 
    //     {
    //         if (playerFightCard[i] == null) continue;//注意位置
    //         playerFightCard[i].transform.parent = transform;//调整父对象为操作区
    //         playerFightCard[i].transform.position = playerFightCard_Pos[i];
    //         //更新实例卡牌的记录初始位置
    //         playerFightCard[i].GetComponent<C_Interaction>().originPos = playerFightCard_Pos[i];
    //         playerFightCard[i].GetComponent<C_Interaction>().AutoModifyCardFightState();
    //     }
    //     //给玩家所有卡牌给上白卡列表
    //     foreach (GameObject card in playerAllCard)
    //     {
    //         card.GetComponent<C_Interaction>().blankCards = blankAllCard;
    //     }
    // }
    //======按钮功能======//
    // public void PlayTheGame()   //响应玩家在对局中点击开始对战按钮
    // {
    //     //避免一张出战卡牌都没有
    //     int validFightCards = playerFightCard.Count(card => card != null);// 统计有效卡牌数量（非null的元素）
    //     if (validFightCards == 0)
    //     {
    //         Debug.Log("请放置出战卡牌!");
    //         return;
    //     }
    //     //将出战卡牌禁用响应操作脚本,调整子对象顺序
    //     int indexChild = blankAllCard.Count;
    //     for (int i = 0; i < playerFightCard.Count; i++)
    //     {
    //         if (playerFightCard[i] == null) continue;
    //         if (playerFightCard[i].GetComponent<C_Interaction>() != null)
    //         {
    //             playerFightCard[i].transform.SetSiblingIndex(indexChild);
    //             playerFightCard[i].GetComponent<C_Interaction>().isStart = true;//游戏开始后不能被响应
    //             indexChild++;
    //         }
    //     }
    //     //将玩家卡牌和怪物卡牌赋予[初始位置]
    //     foreach (GameObject gwCard in gwAllCard)
    //     {
    //         gwCard.GetComponent<C_Fight>().originPos = gwCard.transform.position;
    //     }
    //     foreach (GameObject playerCard in playerFightCard)
    //     {
    //         if (playerCard == null) continue;
    //         //赋予初始位置信息
    //         playerCard.GetComponent<C_Fight>().originPos = playerCard.transform.position;
    //         //模拟鼠标点击赋予[行列值]
    //         Vector2 screenPosition = RectTransformUtility.WorldToScreenPoint(null, playerCard.transform.position);
    //         // 创建 PointerEventData
    //         PointerEventData eventData = new PointerEventData(EventSystem.current)
    //         {
    //             position = screenPosition
    //         };
    //         // 存储所有被击中的 UI 元素
    //         List<RaycastResult> results = new List<RaycastResult>();
    //         graphicRaycaster.Raycast(eventData, results);
    //         GameObject firstOtherUI = results
    //         .Where(r => r.gameObject != playerCard)
    //         .Select(r => r.gameObject)
    //         .FirstOrDefault();
    //         // if (firstOtherUI.GetComponent<BlankCard>())
    //         // {
    //         //     //赋予行列值
    //         //     playerCard.GetComponent<C_Fight>().row = firstOtherUI.GetComponent<BlankCard>().blankCard_Row;
    //         //     playerCard.GetComponent<C_Fight>().column = firstOtherUI.GetComponent<BlankCard>().blankCard_Column;
    //         // }
    //     }
    //     //为出战卡组更新最新的出战队伍数据
    //     UpdateFightCardData();
    //     //将所有白卡隐身
    //     foreach (GameObject blankCard in blankAllCard)
    //     {
    //         blankCard.SetActive(false);
    //     }
    //     //隐身自己
    //     Sequence button = ButtonFadeOutTween();
    //     button.OnComplete(() =>
    //     {
    //         //隐藏按钮
    //         playButton.gameObject.SetActive(false);
    //         returnButton.gameObject.SetActive(false);
    //         changeTeamButton.gameObject.SetActive(false);
    //         //调用骰子管理器运行
    //         Sequence sequence = manager_PlayerDice.BlankDiceFadeInTween();
    //         sequence.OnComplete(() =>
    //         {
    //             //  执行骰子机制系统
    //             manager_GwDice.RandomDice();
    //             //manager_PlayerDice.RandomDice();
    //         });
    //     });
    // }
    //返回按钮
    // public void ReturnHome()
    // {
    //     //先触发跳转场景，然后马上调整关卡页面实例canvas顺序
    //     if (Loading_UIManager.Instance != null) Loading_UIManager.Instance.OnLoadScene("Home");
    //     //调整关卡页面canvas顺序
    //     if(Chapter_UI.Instance != null)Chapter_UI.Instance.AddCanvasOrder();
    // }
    //======更新最新的出战卡牌队伍数据======//
    // private void UpdateFightCardData()
    // {
    //     if (CC_Card.Instance == null) return;
    //     //清空出战卡组
    //     CC_Card.Instance.playerFightCard_Data.Clear();
    //     //提取对战卡牌实例挂载的卡牌数据[保留位置==未处理容量]
    //     for (int i = 0; i < playerFightCard.Count; i++)
    //     {
    //         if (playerFightCard[i] == null)
    //         {
    //             CC_Card.Instance.playerFightCard_Data.Add(null);
    //             continue;
    //         }
    //         //提取实例上挂载的数据
    //         Card cardData = playerFightCard[i].GetComponent<C_Fight>().heroCard;
    //         //加入到出战列表里
    //         CC_Card.Instance.playerFightCard_Data.Add(cardData);
    //     }
    //     Debug.Log("出战卡牌更新并确认完毕");
    // }
    // //======按钮淡出动画======//
    // private Sequence ButtonFadeOutTween()
    // {
    //     //制作序列动画
    //     Sequence allfade = DOTween.Sequence();
    //     //动画制作
    //     Tween playbutton = playButton.GetComponent<Image>().DOFade(0f, FADE_DURATION)
    //         .SetEase(Ease.InQuad);
    //     Tween returnbutton = returnButton.GetComponent<Image>().DOFade(0f, FADE_DURATION)
    //         .SetEase(Ease.InQuad);
    //     Tween changeTeambutton = changeTeamButton.GetComponent<Image>().DOFade(0f, FADE_DURATION)
    //         .SetEase(Ease.InQuad);
    //     Tween settingbutton = settingButton.GetComponent<Image>().DOFade(1f, FADE_DURATION)
    //         .SetEase(Ease.InQuad);
    //     allfade.Join(playbutton);
    //     allfade.Join(returnbutton);
    //     allfade.Join(changeTeambutton);
    //     allfade.Join(settingbutton);
    //     return allfade;
    // }
}
