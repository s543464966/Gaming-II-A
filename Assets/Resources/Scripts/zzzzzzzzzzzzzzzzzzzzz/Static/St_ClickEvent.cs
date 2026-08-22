using System;
using System.Collections;
using UnityEngine;
using UnityEngine.EventSystems;

public static class St_ClickEvent//通知广播点击事件管理器
{
    public static event Action<PointerEventData> OnCurrentSceneClickEvent;//通知点击事件
    public static event Action<PointerEventData> OnCurrentSceneDrag;//通知滑动事件
    public static event Action<PointerEventData> OnCurrentSceneClickUpEvent;//松开事件
    public static event Action<Vector2, float> OnGlobalSwipe;//通知区域点击事件

    public static void TriggerClickEvent(PointerEventData eventData)//给订阅者传递数据
    {
        OnCurrentSceneClickEvent?.Invoke(eventData);
    }

    public static void TriggerDragEvent(PointerEventData delta)
    {
        OnCurrentSceneDrag?.Invoke(delta);
    }

    public static void TriggerClickUpEvent(PointerEventData eventData)
    {
        OnCurrentSceneClickUpEvent?.Invoke(eventData);
    }
    public static void TriggerSwipeEvent(Vector2 delta, float duration)
    {
        OnGlobalSwipe?.Invoke(delta, duration);
    }
}
