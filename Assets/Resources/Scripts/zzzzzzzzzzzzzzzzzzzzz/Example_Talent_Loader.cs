using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class Example_Talent_Loader : MonoBehaviour//挂载在每个天赋对象上的
{
    public Example_SO_Talent specificTalent_SO;//引用一个空SO用来保存特定的天赋SO
    //示例展示天赋SO
    public Image talentImage;//天赋图像

    //引用TalentUICard对象
    public GameObject talentUICard;
    // Start is called before the first frame update
    void Start()
    {
        //修改透明度值 先表示为未激活//后续可以制作0——1来表示暗或亮
        Color color = talentImage.color;
        color.a = color.a /2.0f;
        talentImage.color =color;

        talentImage.sprite = specificTalent_SO.talentSprite;//给游戏内对象换上特定天赋的图像
    }

    // Update is called once per frame
    
    public void OnTalentUICardButton()
    {
        //给talentUICard传talentSO[对象]数据过去 [将自身传过去]
        talentUICard.GetComponent<Example_TalentUICard_UIManager>().ReceiveTalentSOData(gameObject);

        talentUICard.SetActive(true);//将TalentUICard对象激活
    }

}
