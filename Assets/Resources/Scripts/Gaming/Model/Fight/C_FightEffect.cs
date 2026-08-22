using System;
using DG.Tweening;
using UnityEngine;

public enum ModifierKey  //数值变更钥匙
{
    Damage,         // 伤害 (也就是扣血)
    Hp,        // 治疗 (加血)
    Dp,         // 获得护盾
    Mana,           // 回蓝
    Atk,   // 攻击力变更 (增益传正数，减益传负数)
}
public class C_FightEffect : MonoBehaviour
{
    //挂载必要数据及组件
    [HideInInspector] public C_Ability_T C_Ability_T;
    [HideInInspector] public Type SC_Skill;

    //模块：Common - 共用
    [HideInInspector] protected GameObject hero; //技能所属英雄
    [HideInInspector] protected GameObject target; //技能目标
    [HideInInspector] public int tx_Skill_Model; //技能特效类型

    [HideInInspector] public float value;//保存记录的数值
    [HideInInspector] public ModifierKey modifierKey;//保存数值的变更类型
    // [HideInInspector] public CC_Skill skill_script

    // void Start()
    // {
    //     Vector2 direction = (target.transform.position - transform.position).normalized; //计算方向
    //     SetSpeed(direction.normalized); //设置飞行速度
    // }

    // ----------------------------------------------------------------------------------------------------------
    //模块：Init - 初始化

    public void Init_Effect(C_Ability_T _C_Ability_T, GameObject _target, int _tx_Skill_Model)   //特效初始化
    {
        //  特效的基本参数
        C_Ability_T = _C_Ability_T; //属于哪个技能的特效
        target = _target;   //技能目标
        tx_Skill_Model = _tx_Skill_Model; //技能特效运动模式

        //（待改进）判断特效是否需要飞行
        // Vector2 direction = (target.transform.position - transform.position).normalized; //计算方向
        // SetSpeed(direction.normalized); //设置飞行速度
    }

    // ----------------------------------------------------------------------------------------------------------
    //模块：执行动作
    public void Set_Action()
    {
        switch (tx_Skill_Model)
        {
            case 1:
                Debug.Log("飞行特效");
                Effect_Model_Flight();
                break;
            case 2:
                Debug.Log("瞬发特效");
                Effect_Model_Instant();
                break;
            default:
                Debug.Log("目前还没有这种特效类型");
                break;
        }
    }
    // ----------------------------------------------------------------------------------------------------------
    //模块：Action - 动作
    public void Action_HitTarget()
    {
        // 利用[结构体]存放的特效数值，进行循环(比如一个特效实现回血回蓝)
        //产生效果
        C_Ability_T.Ability_Hit(target, modifierKey, value);
    }

    public void Action_EffectsEnd()
    {
        //通知特效播放结束
        C_Ability_T.Fight_Effect.ActionSkillEffect_Complate();  //调用产生特效的技能脚本上的特效管理器脚本
    }

    public void Action_Destoryself()
    {
        //动画播放结束，销毁自己
        Destroy(gameObject);
    }




    // ----------------------------------------------------------------------------------------------------------
    //模块：Common - 共用特效运动的模式

    private void Effect_Model_Flight() //设置特效飞行速度与轨迹
    {
        float basicSpeed = 30f; // 基础飞行速度
        Vector2 direction = target.transform.position - transform.position; //计算方向
        float targetAngle = Mathf.Atan2(direction.y, direction.x) * Mathf.Rad2Deg; //计算角度
        transform.rotation = Quaternion.Euler(0, 0, targetAngle); //设置旋转

        Sequence childSequence = DOTween.Sequence(); //创建动画序列
        Debug.Log("成功创建特效实例");
        GetComponent<Animator>().SetTrigger("Actived"); //触发攻击动画

        //  控制特效移动到目标
        float distance = Vector3.Distance(transform.position, target.transform.position); // 计算移动距离
        float time = distance / basicSpeed; //计算飞行时间
        Tween moveTween = transform.DOMove(target.transform.position, time)//由慢到快，较强加速感
            .SetEase(Ease.InCubic);
        childSequence.Append(moveTween);

        //  动画完成后回调
        childSequence.OnComplete(() =>
        {
            GetComponent<Animator>().SetTrigger("Hit"); //触发受击动画
        });
    }
    private void Effect_Model_Instant() //瞬发特效
    {
        // 移动到目标位置
        transform.position = target.transform.position;
        // 瞬发特效执行一遍clip，需要在clip上添加好对应的事件方法
        GetComponent<Animator>().SetTrigger("Actived");
    }
    public void SetPositon() //设置特效位置
    {
        transform.position = target.transform.position;
    }
}
