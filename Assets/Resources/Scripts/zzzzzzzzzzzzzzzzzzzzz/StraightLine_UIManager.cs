using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using DG.Tweening;
using UnityEngine.UI;

public class StraightLine_UIManager : MonoBehaviour
{
    public RectTransform starCard_Prefab;//引用星能卡牌预制体的Rect组件
    private RectTransform selfRect;//直线提示线的Rect组件
    private Sequence fadeSequence;//fade循环动画序列
    //--------------------渐变循环参数---------
    public float fadeDuration = 1f;//渐变持续时间
    public float startAlpha = 0.2f;//初始透明度
    public float endAlpha = 0.6f;//结束透明度（最大透明度）
    private void Awake() {
        selfRect = gameObject.GetComponent<RectTransform>();
    }

    public void FollowFinger_X(Vector2 fingerPos)
    {
        selfRect.position = new Vector2(fingerPos.x,selfRect.position.y);//修改X轴跟随变化
    }

    public void StartFading()
    {
        gameObject.SetActive(true);
        // 如果存在现有的闪烁序列，先杀死它
        if (fadeSequence != null)
        {
            fadeSequence.Kill();
        }

        // 创建一个新的闪烁序列
        fadeSequence = DOTween.Sequence();

        // 启动透明度的非线性闪烁效果,设定从 startAlpha 到 endAlpha 循环
        fadeSequence.Append(gameObject.GetComponent<Image>().DOFade(endAlpha, fadeDuration)
            .SetEase(Ease.InOutQuad))//透明度从 startAlpha 到 endAlpha 过渡
            .Append(gameObject.GetComponent<Image>().DOFade(startAlpha, fadeDuration)
            .SetEase(Ease.InOutQuad))//透明度从 endAlpha 到 startAlpha 过渡
            .SetLoops(-1, LoopType.Yoyo);//循环闪烁
    }

    //停止闪烁非线性透明度变为0并禁用提示线
    public void StopFading()
    {
        //停止当前闪烁动画
        if (fadeSequence != null)
        {
            fadeSequence.Kill();
        }
        // 使用 DoTween 非线性过渡至透明度 0
        gameObject.GetComponent<Image>().DOFade(0f, fadeDuration)
            .OnComplete(() => {
                // 完全透明后禁用提示线的激活状态
                gameObject.SetActive(false);
            })
            .SetEase(Ease.InOutQuad);  // 非线性缓动效果
    }
}
