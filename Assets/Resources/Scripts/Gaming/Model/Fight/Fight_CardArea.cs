using System.Collections;
using System.Collections.Generic;
using DG.Tweening;
using UnityEngine;
using UnityEngine.UI;

public class Fight_CardArea : MonoBehaviour
{
    //模块：外部调用，群体骰子交互动画播放

    private Image blinkImage;
    private Sequence blinkSequence; //闪烁动画序列
    private float originalAlpha; //原始透明度
    private bool isMakeBlink_SelectableArea = false; //可选择区域是否激活正在播放动画
    private bool isRayHide_UnselectableArea = false; //不可选择区域是否进行激活区域遮挡
    private void Awake()
    {
        blinkImage = GetComponent<Image>();
        originalAlpha = blinkImage.color.a; //保存原始透明度
    }
    //模块：外部调用，可被选择的区域进行闪烁动画播放
    public void PlaySelectableUI()    //重复调用激活不同状态
    {
        if (isMakeBlink_SelectableArea == false)
        {
            isMakeBlink_SelectableArea = true;
            StartAreaBlink();   //执行闪烁动画
        }
        else
        {
            isMakeBlink_SelectableArea = false;
            StopAreaBlink();    //取消闪烁动画
        }
    }
    //开始区域执行闪烁动画
    private void StartAreaBlink()
    {
        blinkSequence?.Kill();  //先把已有的动画给停掉
        blinkImage.color = new Color(blinkImage.color.r, blinkImage.color.g, blinkImage.color.b, originalAlpha);
        //  激活显示自己
        gameObject.SetActive(true);
        //创建闪烁动画序列
        blinkSequence = DOTween.Sequence()
            .Append(blinkImage.DOFade(0.3f, 0.4f))
            .Append(blinkImage.DOFade(originalAlpha, 0.4f))
            .SetLoops(-1, LoopType.Yoyo);
    }
    //停止区域闪烁动画
    private void StopAreaBlink()
    {
        blinkSequence?.Kill();
        blinkSequence = null;
        //  隐藏自己
        gameObject.SetActive(false);

        blinkImage.DOKill();    //停止所有动画
        var c = blinkImage.color;
        blinkImage.color = new Color(c.r, c.g, c.b, originalAlpha); //恢复原始透明度
    }
    //模块：外部调用，不可被选择的区域进行遮挡并停止对象的光线检测
    public void PlayUnselectableUI(List<GameObject> _hideCardObjList)   //传入需要遮挡光线检测的卡牌对象列表
    {
        if (isRayHide_UnselectableArea == false)
        {
            isRayHide_UnselectableArea = true;
            StartRayHide(_hideCardObjList);   //执行光线遮挡
        }
        else
        {
            isRayHide_UnselectableArea = false;
            StopRayHide(_hideCardObjList);    //取消光线遮挡
        }
    }
    //激活区域及卡牌的光线遮挡
    private void StartRayHide(List<GameObject> _hideCardObjList)
    {
        //激活区域遮挡
        blinkImage.raycastTarget = false;
        //激活区域内所有卡牌的遮挡
        foreach (GameObject card in _hideCardObjList)
        {
            card.GetComponent<CanvasGroup>().blocksRaycasts = false;
        }
    }
    //关闭区域及卡牌的光线遮挡
    private void StopRayHide(List<GameObject> _hideCardObjList)
    {
        //关闭区域遮挡
        blinkImage.raycastTarget = true;
        //关闭区域内所有卡牌的遮挡
        foreach (GameObject card in _hideCardObjList)
        {
            card.GetComponent<CanvasGroup>().blocksRaycasts = true;
        }
    }
}
