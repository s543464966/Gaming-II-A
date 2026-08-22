using System;
using System.Collections;
using System.Collections.Generic;
using DG.Tweening;
using UnityEngine;

public class C_Ability_T : MonoBehaviour
{
    //模块：Initial 
    [HideInInspector] public Card Card;   //获取卡英雄牌SO
    [HideInInspector] public GameObject EffectsPrefab; //技能特效投射物预制体
    [HideInInspector] public C_Ability_T C_Ability;
    [HideInInspector] public RuntimeAnimatorController RuntimeAnimatorController; //战斗能力动画控制器
    [HideInInspector] public List<bool> securecyList; //天赋列表（0-3,4-6,7-9,10-12,13-15,16-18,共计5层，每层3选1，通过索引获取对应天赋，0表示未选择，1表示选择）
    [HideInInspector] public Fight_Entry Fight_Entry; //词条触发器
    [HideInInspector] public Fight_Effect Fight_Effect; //战斗能力目标控制器


    //模块：Ability
    protected int tx_Skill_Model;
    protected string targetType;
    protected string targetAxis;
    protected int targetSelf;
    protected int targetNum;
    protected int targetDistance;
    protected int releaseNum;
    protected float skillvalue;

    //模块：Common - 共用
    [HideInInspector] protected GameObject hero; //技能所属英雄
    [HideInInspector] protected GameObject target; //技能目标


    // ----------------------------------------------------------------------------------------------------------
    //模块：Initial - 初始化

    public void Init_FightAbility(Card _Card, C_Ability_T _C_Ability, Fight_Entry _Fight_Entry, Fight_Effect _Fight_Effect) //初始化技能数据
    {
        //获取必要数据
        Card = _Card;

        //加载能力脚本（具体技能脚本自己）
        C_Ability = _C_Ability;

        //加载：战斗词条
        Fight_Entry = _Fight_Entry;

        //加载：战斗能力目标获取器
        Fight_Effect = _Fight_Effect;
        
        //加载：特效预制体
        // EffectsPrefab = Resources.Load<GameObject>("Skills/EffectsPrefab");

        //加载：战斗能力动画控制器(可以加入属于该技能的所有控制器)
        string pathFolder = "Ability/AbilityCard"; //卡牌能力SO文件夹路径
        string scriptName = Card.SO_Card.skillId;
        string filePath_AbilityAnimatior = $"{pathFolder}/{scriptName}/{scriptName}_Animator";   //拼接动画器路径
        RuntimeAnimatorController = Resources.Load<RuntimeAnimatorController>(filePath_AbilityAnimatior);
        if (RuntimeAnimatorController == null) { Debug.LogError("未找到动画Animator: 请检查名称或文件是否存在"); }

        //初始化技能、隐秘、天赋模块的数据
        Init_Ability();
        Init_AbilitySecrecy();
        Init_AbilityTalent();
    }
    public virtual void Init_Ability() //初始化“战斗能力”数据
    {
        //各自天赋数值
    }

    public virtual void Init_AbilitySecrecy() //初始化“战斗能力隐秘强化”数据
    {

    }

    public virtual void Init_AbilityTalent() //初始化“战斗能力天赋强化”数据
    {
        //各自隐秘技能数值
    }


    // ----------------------------------------------------------------------------------------------------------
    //模块：Ability - 能力

    public virtual void Ability_Release() //战斗能力释放
    {
        //各自技能重新维护
    }

    public virtual void Ability_Hit(GameObject _target,ModifierKey _modifierKey, float _value) //战斗能力命中[参数(目标，数值类型，数值)]
    {
        //各自技能重新维护
    }
    protected virtual IEnumerator Ability_Sequence()   //具体技能释放顺序
    {
        yield break;
    }
    // ----------------------------------------------------------------------------------------------------------
    //模块：Entry - 词条

    public virtual void Entry_Release(int _entryType) //触发战斗词条
    {
        //各自技能重新维护
    }

    // public virtual void Add_ListEntryToTrigger(List<int> entryList, Fight_Entry _fight_Entry) //添加词条列表到触发器
    // {
    // }

    // public virtual void Add_EntryToTrigger(Fight_Entry _fight_Entry) //添加单个词条到触发器
    // {
    //     Debug.LogError("调用错误, 基类Add_EntryToTrigger被调用, 请在子类中重写此方法");
    // }

    // public virtual void Sub_EntryFromTrigger(Fight_Entry _fight_Entry) //从触发器移除词条
    // {
    //     Debug.LogError("调用错误, 基类Sub_Entry被调用, 请在子类中重写此方法");
    // }

    // ----------------------------------------------------------------------------------------------------------
    //模块：Common - 共用

    protected void LoadA(string _skillId)
    {
        //加载：战斗能力动画控制器
        string pathFolder = "Skills/SkillsCard"; //技能SO文件夹路径
        string scriptName = _skillId;
        string filePath_AbilityAnimatior = $"{pathFolder}/{scriptName}/{scriptName}_Animator";   //拼接动画器路径
        RuntimeAnimatorController = Resources.Load<RuntimeAnimatorController>(filePath_AbilityAnimatior);
        // if (RuntimeAnimatorController == null) { Debug.LogError("未找到动画Animator: 请检查名称或文件是否存在"); }
    }

    protected void SetSpeed() //设置特效飞行速度与轨迹
    {
        float basicSpeed = 1200f; // 基础飞行速度
        Vector2 direction = target.transform.position - transform.position; //计算方向
        float targetAngle = Mathf.Atan2(direction.y, direction.x) * Mathf.Rad2Deg; //计算角度
        transform.rotation = Quaternion.Euler(0, 0, targetAngle); //设置旋转

        DG.Tweening.Sequence childSequence = DOTween.Sequence(); //创建动画序列
        Debug.Log("成功创建特效实例");
        GetComponent<Animator>().SetTrigger("isAttacking"); //触发攻击动画

        //  移动到目标
        float distance = Vector3.Distance(transform.position, target.transform.position); // 计算移动距离
        float time = distance / basicSpeed; //计算飞行时间
        Tween moveTween = transform.DOMove(target.transform.position, time)//由慢到快，较强加速感
            .SetEase(Ease.InCubic);
        childSequence.Append(moveTween);

        //  动画完成后回调
        childSequence.OnComplete(() =>
        {
            GetComponent<Animator>().SetTrigger("isAttacked"); //触发受击动画
        });

    }
    protected void SetPositon() //设置特效位置
    {
        transform.position = target.transform.position;
    }
}
