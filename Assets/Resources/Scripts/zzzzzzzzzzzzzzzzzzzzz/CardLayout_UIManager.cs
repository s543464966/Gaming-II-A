using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class CardLayout_UIManager : MonoBehaviour
{
    //======自身属性======//
    [Header("Grid Settings")]
    public int rows;//行数
    public int columns;//列数
    [Header("Container")]
    //======引用组件=======//
    //怪物小卡牌列表
    //public List<GameObject> GWtlCards = new List<GameObject>();
    // public Init_FightingCard init_FightingCard;
    [Header("占位符位置")] public List<GameObject> blankGwAllCard = new List<GameObject>();//怪物所有白卡
    private List<GameObject> gwAllCard;//怪物卡牌引用
    //private List<Vector2> gwAllCard_LocalPos = new List<Vector2>();//保存位置
    private void Awake()
    {
        //行列值可以让init总控赋值
    }
    void Start()
    {   //获取行列值
        // rows = init_FightingCard.rows;
        // columns = init_FightingCard.columns;

        // gwAllCard = init_FightingCard.gwAllCard;//拿到怪物卡牌列表
        //  摆放卡牌
        ArrangeCards();
        //CalculateSpace();
    }
    void ArrangeCards()
    {
        //  将所有占位符隐藏
        foreach (GameObject gwBlankCard in blankGwAllCard)
        {
            gwBlankCard.SetActive(false);
        }
        //调整怪物卡牌位置参数
        for (int i = 0; i < gwAllCard.Count; i++)
        {
            if (gwAllCard[i] == null) continue;   //防御性
            gwAllCard[i].transform.parent = transform;//调整父对象为操作区
            gwAllCard[i].transform.position = blankGwAllCard[i].transform.position;   //相对坐标
            // //添加canvas组件并做相应设置
            // gwAllCard[i].AddComponent<Canvas>();
            // gwAllCard[i].GetComponent<Canvas>().overrideSorting = true;
            // gwAllCard[i].GetComponent<Canvas>().sortingOrder = 0;                                             
        }
        //===安全访问:检查数量是否足够===//
        int index = 0;
        //初始化卡牌的行列位置信息
        for (int row = 0; row < rows; row++)
        {
            for (int column = 0; column < columns; column++)
            {
                if (index < gwAllCard.Count) // 安全访问[如果实际怪物数量少于位置量时，index访问超过的实际数量索引时直接跳过循环]
                {
                    // gwAllCard[index].GetComponent<C_Fight>().row = row;
                    // gwAllCard[index].GetComponent<C_Fight>().column = column;
                }
                else
                {
                    //Debug.LogError($"卡牌不足！索引{index}超出范围");
                    break;
                }
                index++;
            }
        }
        // //生成对应所需的卡牌实例
        // foreach(Transform child in cardContainer)
        // {
        //     Destroy(child.gameObject);//清除残余实例
        // }
        // // 计算起始位置（左下角，第一行卡片的底部对齐可用区域的下边界）
        // Vector2 startPosition = new Vector2(
        //     -availableWidth / 2 + cardSize.x / 2,  // 左边界开始（与原逻辑一致）
        //     -availableHeight / 2 + cardSize.y / 2   // 下边界开始（原逻辑是顶部，这里改为底部）
        // );
        // // 遍历行列计算卡牌位置
        // for (int i = 0; i < rows; i++)          // i：行索引（0=最下面一行，1=上一行，依此类推）
        // {
        //     for (int j = 0; j < columns; j++)   // j：列索引（0=最左边一列，1=右边一列，依此类推）
        //     {
        //         // // 计算卡牌本地位置（重点修改：垂直方向偏移改为+i，实现向上换行）
        //         // Vector2 cardPosition = startPosition + new Vector2(
        //         //     j * (cardSize.x + spacing.x),  // 水平方向：从左到右
        //         //     i * (cardSize.y + spacing.y)   // 垂直方向：从下到上
        //         // );
        //         //gwAllCard_LocalPos.Add(cardPosition);
        //     }
        // }
    }
    //     void CalculateSpace()//计算自适应
    // {
    //     // //获取空间大小
    //     // float space_init_width = cardContainer.rect.width;
    //     // float space_init_height = cardContainer.rect.height;
    //     // Debug.Log(space_init_height);
    //     // Debug.Log(space_init_width);
    //     // //计算可用空间
    //     // availableWidth = space_init_width - margin * 2;
    //     // availableHeight = space_init_height - margin * 2;
    //     // Debug.Log(availableWidth);
    //     // Debug.Log(availableHeight);
        
    //     // if(columns - 1 >= 0 && rows - 1 >= 0)
    //     // {
    //     //     //计算合适的间隔
    //     //     spacing.x = (availableWidth - columns * cardSize.x) / (columns - 1.0f);
    //     //     spacing.y = (availableHeight - rows * cardSize.y) / (rows - 1.0f);
    //     //     Debug.Log(spacing);
    //     // }
    //     // else
    //     // {
    //     //     Debug.Log("列数行数需要大于1");
    //     // }
    // }
}
