using System.Collections;
using System.Collections.Generic;
using DG.Tweening;
using UnityEngine;
using UnityEngine.UI;

//======休整点关卡UI管理器======//
public class Rest_UIManager : MonoBehaviour
{
    // public SO_Level levelSOData; //关卡SO数据类
    private List<Card> fightCardsData;
    //======休整点关卡配置======//
    public int rows;//行数
    public int columns;//列数
    public int margin;//边缘有限空间
    float availableWidth;//可用宽度
    float availableHeight;
    private Vector2 cardSize;
    private Vector2 spacing = new Vector2(0, 0);//计算间隔
    private List<Vector2> playerFightCard_Local = new List<Vector2>();//保存位置
    private List<GameObject> playerRestCard = new List<GameObject>();  //对战卡牌
    //======休整点相关基本UI======//
    public GameObject restCardPrefab;   //休整点卡牌预制体
    public GameObject restBtn;  //休整回血按钮
    public GameObject nextLevelBtn; //下一关按钮
    public GameObject returnBtn;    //返回按钮
    public RectTransform cardContainer;//存放卡牌的容器
    void Awake()
    {
        //获得预制体的尺寸
        cardSize = restCardPrefab.GetComponent<RectTransform>().sizeDelta;
        //拿到出战卡牌数据类
        // fightCardsData = CC_Card.Instance.playerFightCard_Data;
    }
    void Start()
    {
        //激活后将出战卡牌展示
        DisplayFightCard();
    }
    //======将出战卡组展示出来======//
    private void DisplayFightCard()
    {
        CalculateSpace();
        ArrangeCards();
        //同步UI===在FightCard里hp应该读取数据Card的 
        foreach (GameObject restCard in playerRestCard)
        {
            float currentHealth = restCard.GetComponent<C_FightCard>().Card.hp;
            float maxHealth = restCard.GetComponent<C_FightCard>().Card.maxHP;
            float currentHealthRatio = currentHealth / maxHealth;
            // restCard.GetComponent<C_FightCard>().HealthChange(currentHealthRatio);
        }
    }
    void CalculateSpace()
    {
        //获取容器空间大小
        float space_init_width = cardContainer.rect.width;
        float space_init_height = cardContainer.rect.height;
        Debug.Log(space_init_height);
        Debug.Log(space_init_width);
        //计算可用空间
        availableWidth = space_init_width - margin * 2;
        availableHeight = space_init_height - margin * 2;
        Debug.Log(availableWidth);
        Debug.Log(availableHeight);

        if (columns - 1 >= 0 && rows - 1 >= 0)
        {
            //计算合适的间隔
            spacing.x = (availableWidth - columns * cardSize.x) / (columns - 1.0f);
            spacing.y = (availableHeight - rows * cardSize.y) / (rows - 1.0f);
            Debug.Log(spacing);
        }
        else
        {
            Debug.Log("列数行数需要大于1");
        }
    }
    void ArrangeCards()
    {
        //生成对应所需的卡牌实例
        foreach (Transform child in cardContainer)
        {
            Destroy(child.gameObject);//清除残余实例
        }
        // 计算起始位置（左上角）「这是两排的效果」
        Vector2 startPosition = new Vector2(
            -availableWidth / 2 + cardSize.x / 2, // 从左边界开始
            availableHeight / 2 - cardSize.y / 2  // 从顶部开始
        );
        //计算对应位置
        for (int i = 0; i < rows; i++)
        {
            for (int j = 0; j < columns; j++)
            {
                // 计算卡牌位置[本地相对位置]
                Vector2 cardPosition = startPosition + new Vector2(
                    j * (cardSize.x + spacing.x), // 水平偏移
                    -i * (cardSize.y + spacing.y) // 垂直偏移
                );
                playerFightCard_Local.Add(cardPosition);
            }
        }
        //将玩家出战卡牌实例出来并更新位置
        for (int i = 0; i < fightCardsData.Count; i++)
        {
            if (fightCardsData[i] == null) continue;
            GameObject fightCard = Instantiate(restCardPrefab, cardContainer);
            fightCard.transform.localPosition = playerFightCard_Local[i];
            // fightCard.GetComponent<C_FightCard>().card = fightCardsData[i];
            //fightCard.GetComponent<C_FightCard>().Update_FightingCardUI(fightCardsData[i]);
            playerRestCard.Add(fightCard);
        }
    }
    //======确认回血按钮======//
    public void OnRestButton()
    {
        //保留关卡通关数据
        // CC_Chapter.Instance.SetCompletedLevel();
        //更新数据和UI
        UpdateFightCardData();
        //变换按钮
        Sequence btnChange = DOTween.Sequence();
        Tween restBtn_Out = restBtn.GetComponent<Image>().DOFade(0f, 1f).SetEase(Ease.OutQuad);
        btnChange.Join(restBtn_Out);
        foreach (Transform child in restBtn.transform)
        {
            Tween restBtn_Child_Out = child.GetComponent<Image>().DOFade(0f, 1f).SetEase(Ease.OutQuad);
            btnChange.Join(restBtn_Child_Out);
        }
        btnChange.OnComplete(() =>
        {
            restBtn.SetActive(false);
            returnBtn.SetActive(false);
            nextLevelBtn.SetActive(true);
        });
    }
    //======更新出战卡组数据======//
    public void UpdateFightCardData()
    {
        // foreach (GameObject restCard in playerRestCard)
        // {
        //     float getHP = restCard.GetComponent<C_Damage>().hpMax * levelSOData.restLevelHpRatio;
        //     //给每个卡牌数据赋值
        //     restCard.GetComponent<C_Damage>().Get_HP(getHP);
        //     //记录数据
        //     Card cardData = restCard.GetComponent<C_Fight>().cardData;
        //     CC_Card.Instance.ManageCardDataSync_inLevelFight(cardData, restCard.GetComponent<C_Damage>());
        //     Debug.Log(cardData.SO_Card.cardName + ":恢复血量" + getHP + "对战卡牌CCdamage里当前生命值为:" + restCard.GetComponent<C_Damage>().hp
        //                 + "卡牌数据Data里当前生命值为:" + cardData.hp);
        // }
    }
    //======
}
