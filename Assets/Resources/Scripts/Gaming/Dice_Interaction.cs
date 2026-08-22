using System.Collections;
using System.Collections.Generic;
using UnityEngine.EventSystems;
using UnityEngine;
using UnityEngine.UI;
using DG.Tweening;

public class Dice_Interaction : MonoBehaviour, IBeginDragHandler, IDragHandler, IPointerUpHandler, IPointerDownHandler
{
    //====== 必要数据 ======//
    private GameData GameData => DBCC_DataBase.Instance.GameData; // GameData别名[因为单例原因]
    public enum DiceState { Idle, Dragging } // 枚举型状态机明确状态流转: 静止, 拖拽
    private DiceState currentState = DiceState.Idle; // 初始化起始状态
    private GraphicRaycaster graphicRaycaster; // 射线组件

    [Header("模块: 核心组件")]
    [Tooltip("战斗模块")] public CC_Fight CC_Fight; // 战斗模块

    //====== 临时数据 ======//
    [Header("模块: 临时数据")]
    [Tooltip("是否运行被玩家操控")] public bool isPlayerControl = false; // 是否运行被玩家操控
    
    // --- 内部状态 --- (临时与状态数据)
    private GameObject targetObj; // 骰子拖拽目标对象, 可能是卡牌或者大区域
    [HideInInspector] private Vector2 startPos; // 开始位置
    private Quaternion startQua; // 开始旋转
    // public bool isUsed = false;//是否被使用

    // --- 内部状态 --- (玩家骰子相关)
    // [HideInInspector]public Manager_PlayerDice manager_PlayerDice;
    private Dice currentDice; // 操控的骰子

    // --- 内部状态 --- (动画控制)
    private Tween _moveTween; // 移动动画
    private Tween _scaleTween; // 缩放动画
    private Tween _rotateTween; // 旋转动画
    // private Tween _fadeTween;
    private const float MOVE_DURATION = 0.35f; // 交换动画持续时间
    private const float SCALE_DURATION = 0.4f; // 放缩动画持续时间
    private const float Rotate_DURATION = 0.4f; // 扭转动画持续时间
                                               // private const float FADE_DURATION = 0.5f;//消淡动画持续时间



    // ==========================================
    // 1. 初始化 (Initial)
    // ==========================================
    
    /// <summary>
    /// 【核心】初始化骰子交互组件
    /// 负责: 加载必要组件
    /// </summary>
    /// <param name="_GraphicRaycaster">射线检测组件</param>
    /// <param name="_CC_Fight">战斗控制模块</param>
    public void Init_DiceInteraction(GraphicRaycaster _GraphicRaycaster, CC_Fight _CC_Fight)
    {
        //加载必要组件
        graphicRaycaster = _GraphicRaycaster;
        CC_Fight = _CC_Fight;

    }


    // ==========================================
    // 2. 更新态 (Update)
    // ==========================================
    
    /// <summary>
    /// 更新骰子在空白位置的坐标与旋转
    /// 负责: 缓存骰子的停泊坐标与角度
    /// </summary>
    /// <param name="_startPos">初始位置</param>
    /// <param name="_startQua">初始旋转</param>
    public void Update_DiceInBlankPos(Vector2 _startPos, Quaternion _startQua)
    {
        startPos = _startPos;
        startQua = _startQua;
    }


    // ==========================================
    // 3. 交互方法 (Interaction)
    // ==========================================
    
    /// <summary>
    /// 玩家操控: 点击时触发
    /// 负责: 获取当前操控骰子的类型并判断是否允许反馈
    /// </summary>
    /// <param name="eventData">指针事件数据</param>
    public void OnPointerDown(PointerEventData eventData) // 玩家操控: 点击时
    {
        //后续可以在骰子的脚本里封装成返回骰子类型和启动动画
        currentDice = GetComponent<C_FightDice>().dice;//获取当前操控骰子的类型
        if (currentState != DiceState.Idle) return;
        //if (isPlayerControl == false) return;
        if (GameData.Sys_User.isAutoPlay == true || CC_Fight.isHeroAction == false) return;

        // 点击反馈
        // KillTween(_scaleTween);
        // //开始对战后都支持点击，点击会显示当前骰子的一些信息，比如当前面值，效果等，通常是文字信息，从Dice及SO_Dice里获取相关的数据，展示期间需要暂停游戏
        // _scaleTween = transform.DOScale(1.1f, SCALE_DURATION)
        //     .SetEase(Ease.OutBack);
    }

    /// <summary>
    /// 玩家操控: 开始拖拽时触发
    /// 负责: 1.校验是否允许拖拽, 2.更新为拖拽状态, 3.根据骰子面值展示可交互区域的变亮/变暗UI
    /// </summary>
    /// <param name="eventData">指针事件数据</param>
    public void OnBeginDrag(PointerEventData eventData) // 玩家操控: 开始拖拽时
    {
        //仅在空闲状态下响应
        if (currentState != DiceState.Idle) return;
        //仅在玩家操控状态下响应(待改进)还需要判断当前是玩家回合--->(已修改)
        if (GameData.Sys_User.isAutoPlay == true || CC_Fight.isHeroAction == false) return;
        RotateTween_Dice(Quaternion.identity);  //恢复角度到默认值

        //更新骰子状态
        currentState = DiceState.Dragging;
        transform.SetAsLastSibling();
        int diceCurrentFace = GetComponent<C_FightDice>().diceCurrentFace;
        //（待改进）开始拖拽时，需要根据投资类型，来展示可接受卡牌或区域的变化UI，同时让不可接受的卡牌变暗
        switch (diceCurrentFace)
        {
            case int n when n >= 0 && n <= 10:
                //单体选择，己方
                CC_Fight.Notify_AllHeroCard_OptionalUI(true);
                CC_Fight.Notify_AllMonsterCard_OptionalUI(false);
                break;
            case int n when n >= 21 && n <= 30:
                //群体瞬发选择，己方
                CC_Fight.Notify_AllHeroArea_OptionalUI(true);
                CC_Fight.Notify_AllMonsterArea_OptionalUI(false);
                break;
            case int n when n >= 100 && n <= 110:
                //群体轮动选择，己方
                CC_Fight.Notify_AllHeroArea_OptionalUI(true);
                CC_Fight.Notify_AllMonsterArea_OptionalUI(false);
                break;
            case int n when n >= 10 && n <= 20: //(待改进)区间需要确定好避免区间重叠造成冲突
                //单体选择，敌方
                CC_Fight.Notify_AllHeroCard_OptionalUI(false);
                CC_Fight.Notify_AllMonsterCard_OptionalUI(true);
                break;
            case int n when n >= 61 && n <= 70:
                //群体瞬发选择，敌方
                CC_Fight.Notify_AllHeroCard_OptionalUI(false);
                CC_Fight.Notify_AllMonsterCard_OptionalUI(true);
                break;
            default:
                //群体轮动选择，敌方
                CC_Fight.Notify_AllHeroArea_OptionalUI(false);
                CC_Fight.Notify_AllMonsterArea_OptionalUI(true);
                break;
        }
    }

    /// <summary>
    /// 玩家操控: 拖拽中触发
    /// 负责: 实时更新骰子的物理位置, 并检测此时悬停的目标卡牌
    /// </summary>
    /// <param name="eventData">指针事件数据</param>
    public void OnDrag(PointerEventData eventData) // 玩家操控: 拖拽中
    {
        //仅在拖拽状态下响应
        if (currentState != DiceState.Dragging) return;
        //仅在玩家操控状态和玩家回合下才能操控
        if (GameData.Sys_User.isAutoPlay == true || CC_Fight.isHeroAction == false) return;

        // 实时更新位置
        RectTransformUtility.ScreenPointToWorldPointInRectangle(
            GetComponent<RectTransform>(),
            eventData.position,
            eventData.pressEventCamera,
            out Vector3 worldPos
        );
        transform.position = worldPos;

        // 检测拖拽目的
        Drag_DetectCard(eventData);
    }

    /// <summary>
    /// 玩家操控: 结束拖拽时触发
    /// 负责: 1.恢复所有骰子UI状态, 2.如果有合法目标则触发最终效果, 3.无目标则还原位置到基座
    /// </summary>
    /// <param name="eventData">指针事件数据</param>
    public void OnPointerUp(PointerEventData eventData) // 玩家操控: 结束拖拽时
    {
        //结束拖拽时，需要恢复所有骰子的UI显示状态，并根据拖拽目的，来通知Fighting执行对应的骰子效果，如果没有对应的接受对象，则复位
        if (currentState != DiceState.Dragging)
        {
            // // 打断动画
            // KillTween(_scaleTween);
            // _scaleTween = transform.DOScale(1f, SCALE_DURATION)
            //     .SetEase(Ease.OutBack);
            return;
        }
        //判断当前状态是否为idle
        if (currentState == DiceState.Idle)
        {
            // 显示骰子信息UI
            return;
        }
        // // 重置缩放
        // KillTween(_scaleTween);
        // _scaleTween = transform.DOScale(1f, SCALE_DURATION)
        //     .SetEase(Ease.OutBack);
        //通过拖拽目标，来执行对应的骰子效果
        int diceCurrentFace = GetComponent<C_FightDice>().diceCurrentFace;
        switch (diceCurrentFace)
        {
            case int n when n >= 0 && n <= 10:
                //单体选择，己方
                CC_Fight.Notify_AllHeroCard_OptionalUI(true);
                CC_Fight.Notify_AllMonsterCard_OptionalUI(false);

                //骰子动画

                //通知CC_Fight，执行对应的骰子效果及更新骰子使用情况。
                //GetComponent<C_Dice>().SetFindIntentionList(targetObj);

                break;
            case int n when n >= 21 && n <= 30:
                //群体瞬发选择，己方
                CC_Fight.Notify_AllHeroArea_OptionalUI(true);
                CC_Fight.Notify_AllMonsterArea_OptionalUI(false);
                //GetComponent<C_Dice>().SetFindIntentionList(null);
                break;
            case int n when n >= 100 && n <= 110:
                //群体轮动选择，己方
                CC_Fight.Notify_AllHeroArea_OptionalUI(true);
                CC_Fight.Notify_AllMonsterArea_OptionalUI(false);
                //GetComponent<C_Dice>().SetFindIntentionList(null);
                break;
                // case int n when (n >= 10 && n <= 20):
                //     //单体选择，敌方
                //     CC_Fight.Notify_AllHeroCard_OptionalUI();
                //     CC_Fight.Notify_AlllMonsterCard_OptionalUI();
                //     break;
                // case int n when (n >= 61 && n <= 70):
                //     //群体瞬发选择，敌方
                //     CC_Fight.Notify_AllHeroCard_OptionalUI();
                //     CC_Fight.Notify_AlllMonsterCard_OptionalUI();
                //     break;
                // default:
                //     //群体轮动选择，敌方
                //     CC_Fight.Notify_AllHeroArea_OptionalUI();
                //     CC_Fight.Notify_AllMonsterArea_OptionalUI();
                //     break;
        }
        // 执行操作目的或复位
        // Debug.Log("测试，看一下是否找到正确的对象：" + targetObj.name);
        if (targetObj != null)
        {

            // StartCoroutine(PerformPurpose());
            //通过拖拽目标，来执行对应的骰子效果
            //int diceCurrentFace = GetComponent<C_Dice>().diceCurrentFace;
            //（待改进）松手时，需要根据投资类型，复位卡牌的选取状态和UI变化
            //（大改进）这里需要把switch做成一个独立的方法
            // switch (diceCurrentFace)
            // {
            //     case int n when n >= 0 && n <= 10:
            //         //单体选择，己方
            //         CC_Fight.Notify_AllHeroCard_OptionalUI(true);
            //         CC_Fight.Notify_AllMonsterCard_OptionalUI(false);

            //         //骰子动画

            //通知CC_Fight，执行对应的骰子效果及更新骰子使用情况。
            GetComponent<C_FightDice>().Manual_FindList_Intention(targetObj);

            //         break;
            //     case int n when n >= 21 && n <= 30:
            //         //群体瞬发选择，己方
            //         CC_Fight.Notify_AllHeroArea_OptionalUI(true);
            //         CC_Fight.Notify_AllMonsterArea_OptionalUI(false);
            //         GetComponent<C_Dice>().SetFindIntentionList(null);
            //         break;
            //     case int n when n >= 100 && n <= 110:
            //         //群体轮动选择，己方
            //         CC_Fight.Notify_AllHeroArea_OptionalUI(true);
            //         CC_Fight.Notify_AllMonsterArea_OptionalUI(false);
            //         GetComponent<C_Dice>().SetFindIntentionList(null);
            //         break;
            //         // case int n when (n >= 10 && n <= 20):
            //         //     //单体选择，敌方
            //         //     CC_Fight.Notify_AllHeroCard_OptionalUI();
            //         //     CC_Fight.Notify_AlllMonsterCard_OptionalUI();
            //         //     break;
            //         // case int n when (n >= 61 && n <= 70):
            //         //     //群体瞬发选择，敌方
            //         //     CC_Fight.Notify_AllHeroCard_OptionalUI();
            //         //     CC_Fight.Notify_AlllMonsterCard_OptionalUI();
            //         //     break;
            //         // default:
            //         //     //群体轮动选择，敌方
            //         //     CC_Fight.Notify_AllHeroArea_OptionalUI();
            //         //     CC_Fight.Notify_AllMonsterArea_OptionalUI();
            //         //     break;
            // }

            // C_Dice dice = GetComponent<C_Dice>();//获取当前骰子的脚本
            // Sequence moveSequence = dice.Auto_DiceMoveToIntention(gameObject, targetObj);//执行移动到target的动画
            // //位移动画完成后调用intention方法，同时把自己重置初始状态
            // moveSequence.OnComplete(() =>
            // {
            //     transform.localScale = Vector3.one;
            //     transform.position = dice.dicePos;
            //     dice.SetFindIntentionList(targetObj);
            // });
        }
        else
        {
            ReturnToOrigin();
            RotateTween_Dice(startQua); //恢复初始旋转角度值
        }

        currentState = DiceState.Idle;
    }



    // ==========================================
    // 4. 其它检测与重置逻辑
    // ==========================================
    
    /// <summary>
    /// 拖拽检测
    /// 负责: 1.利用射线发射检测碰撞UI, 2.过滤无效目标找到战斗卡牌或区域
    /// </summary>
    /// <param name="eventData">指针事件数据</param>
    private void Drag_DetectCard(PointerEventData eventData)
    {
        var results = new List<RaycastResult>();
        graphicRaycaster.Raycast(eventData, results);

        // // 过滤有效目标
        // var validTarget = results
        //     .Where(r => r.gameObject != gameObject)
        //     .OrderBy(r => Vector2.Distance(r.worldPosition, transform.position))
        //     .FirstOrDefault();//筛选自身后的第一个
        //  先重置
        targetObj = null;
        //过滤无效目标，寻找卡牌或者大区域对象
        foreach (var r in results)
        {

            if (r.gameObject == gameObject) continue; // 跳过自己

            // 判断是否是可交换对象（卡牌）（待改进）--->不用去判断是否是能用的卡牌，在前面做动画显示的时候把不相干的卡牌的raytarget关掉就不会被检测到了(已修改)
            bool isCard = r.gameObject.TryGetComponent(out C_FightCard _);
            //  判断是否为大区域对象
            //bool isFightingArea = r.gameObject.TryGetComponent(out Fight_CardArea _);//（待改进）需要找一下区域的大对象，单独有一个脚本

            Debug.Log("测试：这里是手动查找目标的名字：" + r.gameObject.name);

            if (isCard)//|| isFightingArea)
            {
                targetObj = r.gameObject;
                Debug.Log("测试：这里是手动查找最终确定目标的名字：" + r.gameObject.name);
                break; // 只处理第一个有效目标
            }
        }


        // 赋值拖拽目的[条件检测，比如有些骰子只能作用于某些卡牌上]（待改进）需要改为通过骰子面值来判断
        // if (validTarget.gameObject.GetComponent<Card_Interaction>() != null && currentDice.Effect != EffectType.Group_Focus)//这是友方
        // {
        //     _useTarget = validTarget.gameObject;
        // }
        // else if (validTarget.gameObject.tag == "GwCard" && currentDice.Effect == EffectType.Group_Focus)//群体集火
        // {
        //     _useTarget = validTarget.gameObject;
        // }
        // else
        // {
        //     _useTarget = null;
        // }
    }
    // --- 工具方法 ---
    
    /// <summary>
    /// 回到空白位置上
    /// 负责: 执行返回初始坐标的动画
    /// </summary>
    private void ReturnToOrigin() // 回到空白位置上
    {
        KillTween(_moveTween);
        _moveTween = transform.DOMove(startPos, MOVE_DURATION)
            .SetEase(Ease.OutQuad);
    }
    /// <summary>
    /// 骰子旋转动画
    /// 负责: 执行改变旋转角度的动画
    /// </summary>
    /// <param name="_targetQua">目标的四元数</param>
    private void RotateTween_Dice(Quaternion _targetQua)
    {
        KillTween(_rotateTween);
        _rotateTween = transform.DORotateQuaternion(_targetQua, Rotate_DURATION)
            .SetEase(Ease.OutQuad);

        Debug.Log("执行旋转动画" + _targetQua);
    }
    /// <summary>
    /// 打断指定动画
    /// 负责: 停止并清理当前正在播放的Tween动画
    /// </summary>
    /// <param name="tween">要结束的动画对象</param>
    public void KillTween(Tween tween)
    {
        if (tween != null && tween.IsActive())
        {
            tween.Kill();
        }
    }
    //====== 交换动画协程 ======//
    // private IEnumerator PerformPurpose() {
    //     // _currentState = DiceState.Swapping;

    //     // 获取目标属性
    //     bool isTargetRight = _useTarget.TryGetComponent(
    //         out C_Fight targetCard);//尝试获取该对象上是否有该组件
    //     Vector2 targetOrigin = isTargetRight ? 
    //         targetCard.originPos : //获取目标卡牌的世界坐标
    //         (Vector2)gameObject.transform.position;// 给自身位置

    //     // 终止旧动画
    //     KillTween(_moveTween);

    //     // 实行移动后消淡动画
    //     Sequence purposeSequence = DOTween.Sequence();
    //     _moveTween = transform.DOMove(targetOrigin, MOVE_DURATION)
    //         .SetEase(Ease.OutQuad);
    //     _fadeTween = transform.GetComponent<Image>().DOFade(0f,FADE_DURATION)
    //         .SetEase(Ease.OutQuad);
    //     //顺序播放
    //     purposeSequence.Append(_moveTween);
    //     purposeSequence.Append(_fadeTween);
    //     purposeSequence.OnComplete(()=> 
    //     {
    //         isUsed = true;//使用过了
    //         isPlayerControl = false;//不给玩家操控
    //     });

    //     yield return purposeSequence.WaitForCompletion();
    //     //关闭权限
    //     manager_PlayerDice.OpenLimit();
    //     //动画播放完毕后执行这个骰子的效果
    //     gameObject.GetComponent<PlayerDice>().UseDiceEffect(_useTarget);
    //     ReturnToOrigin();
    //     Debug.Log("骰子动画播放完毕！");

    //     // 重置状态
    //     _useTarget = null;
    //     _currentState = DiceState.Idle;
    // }
}
