using System;
using System.Collections;
using System.Collections.Generic;
using System.Reflection;
using DG.Tweening;
using TMPro;
using UnityEngine;

public class Fight_Effect : MonoBehaviour
{
    //模块：Initial
    List<GameObject> fightingMonsterObjList;
    List<GameObject> fightingHeroObjList;
    // [HideInInspector] public Card Card; //卡牌数据
    // [HideInInspector] public C_FightAbility_T C_FightAbility_T;
    // [HideInInspector] public RuntimeAnimatorController RuntimeAnimatorController;    //加载动画器即可
    // [HideInInspector] public CC_Skill SC_skill;   //获取技能脚本
    // public GameObject CardsTimeline;   //时间轴
    // public Manager_FightCardTimeline Manager_FightCardTimeline;   //目标
    // private int activeTweens = 0; // 正在执行的DoTween动画数量
    private int activeAnimations = 0;// 正在执行的Animation动画数量

    // [HideInInspector] public GameObject skill_TX_Prefab;     //技能特效预制体
    [Tooltip("技能特效投射物预制体")] public GameObject EffectsPrefab; //技能特效投射物预制体
                                                             // [HideInInspector] public bool isIgnoreMagic = false;// 响应骰子效果，无视蓝量放技能
                                                             // [HideInInspector] public int ;//无视蓝量释放后恢复蓝量
                                                             // public void Awake()  //技能释放结束
                                                             // {
                                                             //     //获取CardsTimeline物体，通过场景查找的方式
                                                             //     // CardsTimeline = GameObject.Find("CardsTimeline");


    // }
    ////// ----- 初始化 接收SO_Card的各种属性 ----- //////
    // public void Init_FightAbility(Card _Card)  //初始卡牌
    // {
    //     //暂存必要数据
    //     Card = _Card;
    // }

    //模块：Initial - 
    public void Init_Fight_Effect(List<GameObject> _fightingMonsterObjList, List<GameObject> _fightingHeroObjList)
    {
        fightingMonsterObjList = _fightingMonsterObjList;
        fightingHeroObjList = _fightingHeroObjList;
        //清理遗留特效1
        foreach (Transform child in transform)
        {
            Destroy(child.gameObject);
        }
    }


    // ----------------------------------------------------------------------------------------------------------
    //模块：Ability - 战斗能力

    //获取目标：
    // isEnemye-是敌[true]是友[false], 
    // targetAxis-是0,1,2,3,4,5按照前排，后排行，左侧列，中列，右侧列,0是跳过选择所有
    // isSelf-是包含排除自己，排除[true]不排除[false]
    // distance-是判断单个目标使用，1为最近，-1为最远，0跳过。
    //(待改进)可能会有判断数量的需求，这个可以之后再看情况改。
    public GameObject[] Ability_GetTargets(GameObject _selfObj, bool _isEnemy, int _axis, bool _isSelf, int _distance)
    {
        //获取队友，获取 “hero”or“monster”，获取目标位置“all”or“x”or“y”，包含自己“1”or“0”，指定目标“数量” 

        //初始化目标数组
        List<GameObject> targetObjs = new List<GameObject>();

        //判断敌友关系
        if (_selfObj.tag == "Monster")
        {
            if (_isEnemy == false) { targetObjs = fightingMonsterObjList; }
            else { targetObjs = fightingHeroObjList; }
        }
        else if (_selfObj.tag == "Hero")
        {
            if (_isEnemy == false) { targetObjs = fightingHeroObjList; }
            else { targetObjs = fightingMonsterObjList; }
        }

        //判断行列关系
        if (_axis >= 1) //判断向量y为0
        {
            if (_axis == 1) //前排行
            {
                foreach (GameObject _target in targetObjs)
                {
                    if (_target.GetComponent<C_FightCard>().posIndex > 3)
                    { targetObjs.Remove(_target); }
                }
            }
            else if (_axis == 2) //后排行
            {
                foreach (GameObject _target in targetObjs)
                {
                    if (_target.GetComponent<C_FightCard>().posIndex <= 3)
                    { targetObjs.Remove(_target); }
                }
            }
            else if (_axis == 3) //左侧列
            {
                foreach (GameObject _target in targetObjs)
                {
                    if (_target.GetComponent<C_FightCard>().posIndex != 1 || _target.GetComponent<C_FightCard>().posIndex != 4)
                    { targetObjs.Remove(_target); }
                }
            }
            else if (_axis == 4) //中列
            {
                foreach (GameObject _target in targetObjs)
                {
                    if (_target.GetComponent<C_FightCard>().posIndex != 2 || _target.GetComponent<C_FightCard>().posIndex != 5)
                    { targetObjs.Remove(_target); }
                }
            }
            else if (_axis == 5) //右侧列
            {
                foreach (GameObject _target in targetObjs)
                {
                    if (_target.GetComponent<C_FightCard>().posIndex != 3 || _target.GetComponent<C_FightCard>().posIndex != 6)
                    { targetObjs.Remove(_target); }
                }
            }
        }

        //判断是否排除自己，有可能自己不在表里
        if (_isSelf == true && _isEnemy == true)
        {
            //使用动态列表排除自身
            foreach (GameObject _target in targetObjs)
            {
                if (_target == _selfObj)
                {
                    { targetObjs.Remove(_target); }
                }
            }
        }

        //判断是否最近目标
        if (_distance >= 1)
        {
            float minDistance = 9999f;
            GameObject finalTarget = null;
            foreach (GameObject _target in targetObjs)
            {
                float distance = Vector3.Distance(this.transform.position, _target.transform.position);
                if (distance < minDistance)
                {
                    minDistance = distance;
                    finalTarget = _target;
                }
            }
            GameObject[] targetFinal = new GameObject[] { finalTarget };
            return targetFinal;
        }

        //判断是否最远目标
        if (_distance <= -1)
        {
            float maxDistance = 0.01f;
            GameObject finalTarget = null;
            foreach (GameObject _target in targetObjs)
            {
                float distance = Vector3.Distance(this.transform.position, _target.transform.position);
                if (distance > maxDistance)
                {
                    maxDistance = distance;
                    finalTarget = _target;
                }
            }
            GameObject[] targetFinal = new GameObject[] { finalTarget };
            return targetFinal;
        }

        // 返回Targets
        return targetObjs.ToArray();
    }


    public void Ability_CreateEffect(GameObject[] _targetObjs, int _singleCount, float _delayBetween, C_Ability_T _C_Ability_T, RuntimeAnimatorController _RuntimeAnimatorController)
    {
        //根据怪物数，创建对应数量的特效
        Coroutine first = StartCoroutine(CreateTX_Missile(_singleCount, _delayBetween, _C_Ability_T, _RuntimeAnimatorController, _targetObjs));
        List<Coroutine> txList = new List<Coroutine>();
        txList.Add(first);
        Debug.Log("技能特效列表长度：" + txList.Count);

        //等待所有特效完成
        StartCoroutine(WaitAllTXCompleted(txList));
    }

    ////// ------ 获取队友 - 目标x次特效，单个目标x次特效间延迟间隔，//技能特效状态极控制器，全部目标 ------ //////
    IEnumerator CreateTX_Missile(int _singleCount, float _delayBetween, C_Ability_T _C_Ability_T, RuntimeAnimatorController _RuntimeAnimatorController, params GameObject[] _targetObjs)
    {
        //赋值特效
        int localSingleCount = _singleCount;
        float localDelayBetween = _delayBetween;
        // RuntimeAnimatorController localController = _skillTX_AniController;
        //调用主协程
        return TX_Missile_Targets(localSingleCount, localDelayBetween, _C_Ability_T, _RuntimeAnimatorController, _targetObjs);
    }

    //配套主协程
    IEnumerator TX_Missile_Targets(int _singleCount, float _delayBetween, C_Ability_T _C_Ability_T, RuntimeAnimatorController _RuntimeAnimatorController, params GameObject[] _targetObjs)
    {
        //对这些目标
        int totalTarget = _targetObjs.Length;
        var coroutines = new List<Coroutine>(totalTarget);

        //使用局部变量避免覆盖
        int localSingleCount = _singleCount;
        float localDelayBetween = _delayBetween;
        // RuntimeAnimatorController RuntimeAnimatorController = _RuntimeAnimatorController;

        //对每个目标启动协程
        foreach (GameObject _target in _targetObjs)
        {
            // if (_releaseMission == 1)
            // {
            coroutines.Add(StartCoroutine(TX_Missile_Single(_target, localSingleCount, localDelayBetween, _C_Ability_T, _RuntimeAnimatorController)));
            Debug.Log("触发了几目标特效 " + coroutines.Count);
            // }
            // else if (_releaseMission == 0)
            // {
            //     coroutines.Add(StartCoroutine(TX_Instant_Single(target, localSingleCount, localDelayBetween, localController)));
            // }
        }
        //等待所有协程完成
        foreach (var coroutine in coroutines)
        {
            yield return coroutine;
        }
        // 所有动画完成后继续执行
        Debug.Log("所有动画播放完毕，继续主逻辑");
        // 后续代码...
        // if (GetComponent<C_Damage>().mana < GetComponent<C_Damage>().manaMax)
        // {
        //     //不用回调，只需要回蓝然后再询问
        //     //获得蓝量
        //     gameObject.GetComponent<C_Damage>().SumMana(IgnoreMagic_AddMagic);
        //     //执行完检查是否满蓝，满蓝就放技能
        //     gameObject.GetComponent<FightCard>().Ability();
        //     // isIgnoreMagic = false;//无视触发完毕
        //     Debug.Log("所有动画播放完毕，继续主逻辑，再次释放技能");
        // }
        // else
        // {
        //     gameObject.GetComponent<FightCard>().NotifyActionCompleted();   //发布动作完成通知
        // }
    }

    //子协程，处理单个目标特效
    IEnumerator TX_Missile_Single(GameObject _target, int singleCount, float delayBetween, C_Ability_T _C_Ability_T, RuntimeAnimatorController skillTX_AniController)
    {
        // 使用局部变量避免覆盖
        int localSingleCount = singleCount;
        float localDelayBetween = delayBetween;
        RuntimeAnimatorController localController = skillTX_AniController;

        //主动画序列
        Sequence sequence = DOTween.Sequence();
        //循环添加技能动画动作
        for (int i = 0; i < localSingleCount; i++)
        {
            // 触发单个飞行物的动画
            sequence.AppendCallback(() => ConfigureSingleTX_Missle(_target, _C_Ability_T, localController));
            activeAnimations++; // 增加计数器

            //  添加间隔[最后一个不用加]
            if (i != localSingleCount - 1)
            {
                sequence.AppendInterval(localDelayBetween);
            }
        }
        //等待所有动画执行完毕
        yield return new WaitUntil(() => activeAnimations == 0);
    }

    //配置单个飞行物特效参数//
    void ConfigureSingleTX_Missle(GameObject _targetObj, C_Ability_T _C_Ability_T, RuntimeAnimatorController _RuntimeAnimatorController)
    {
        //  实例化特效
        GameObject effectsPrefab = Instantiate(EffectsPrefab, gameObject.transform);
        Type C_FightEffect = _targetObj.GetComponent<C_FightEffect>().GetType();
        // SC_Skill = Assembly.GetExecutingAssembly().GetType(Card.SO_Skill.skillId);


        //加载相关技能脚本
        effectsPrefab.AddComponent(C_FightEffect);

        //设置技能脚本
        // _C_Ability_T.Init_Effect(_C_Effect_T, _targetObj);
        // _C_Effect_T.Init_Effect(_C_Ability_T, _targetObj);
        // tx.GetComponent<CC_Effects>().Skill_Targets = SC_Skill;

        //设置特效所需数据
        // tx.GetComponent<C_Ability_T>().target = _target;
        // tx.GetComponent<C_Ability_T>().SO_Skill = SO_Skill;
        // tx.GetComponent<C_Ability_T>().hero = this.gameObject;

        //调整特效大小
        effectsPrefab.GetComponent<RectTransform>().sizeDelta = new Vector2(120, 120);

        effectsPrefab.transform.position = gameObject.transform.position;
        //调整特效大小

        //给预制体分配对应属性
        // tx.GetComponent<S0001>().target = _target;
        // tx.GetComponent<CC_Skill>().SC_SkillAim = this.GetType();
        effectsPrefab.GetComponent<Animator>().runtimeAnimatorController = _RuntimeAnimatorController;
    }

    ////// ------ 通用特效完成通知协程方法 ------ //////
    public IEnumerator WaitAllTXCompleted(List<Coroutine> allTXoroutines)//传入特效组列表
    {
        foreach (var coroutine in allTXoroutines)
        {
            yield return coroutine;
        }
        // 所有动画完成后继续执行
        // Debug.Log("所有特效完成！！！，使用的对象为：" + self.name);

        // if (GetComponent<C_Damage>().mana < GetComponent<C_Damage>().manaMax)
        // {
        //     //不用回调，只需要回蓝然后再询问
        //     //获得蓝量
        //     gameObject.GetComponent<C_Damage>().Get_Mana(IgnoreMagic_AddMagic);
        //     //执行完检查是否满蓝，满蓝就放技能
        //     gameObject.GetComponent<FightCard>().Ability();
        //     // isIgnoreMagic = false;//无视触发完毕
        // }
        // else
        // {C_FightCard
        // gameObject.GetComponent<C_FightCard>().Notify_ActionCompleted();   //发布动作完成通知
        // }
    }

    //对目标技能减少计数器
    public void ActionSkillEffect_Complate()
    {
        //  动画完成后减少计数器
        activeAnimations--;
        Debug.Log("技能动画结束, 减少1次计数器");
    }

    // Prepare 每个 target 的 effect 列表（每个target有singleCount个预制实例）
    public Dictionary<GameObject, List<GameObject>> Prepare_EffectsForTargets(int _singleCount, float _value, ModifierKey _modifierKey,
        C_Ability_T _C_Ability, RuntimeAnimatorController _RuntimeAnimatorController, int _tx_Skill_Model, params GameObject[] _targets)
    {
        var prepared = new Dictionary<GameObject, List<GameObject>>();
        if (_targets == null)
        {
            Debug.LogError("Prepare_EffectsForTargets: _targets is null!");
            return prepared;
        }
        if (EffectsPrefab == null)
        {
            Debug.LogError("Prepare_EffectsForTargets: EffectsPrefab is null! 请在 Inspector 指定。");
        }
        if (_C_Ability == null)
        {
            Debug.LogError("Prepare_EffectsForTargets: _C_Ability is null!");
        }
        if (_RuntimeAnimatorController == null)
        {
            Debug.LogError("Prepare_EffectsForTargets: _RuntimeAnimatorController is null!");
        }
        //  先创建特效并配置好其属性
        foreach (var _target in _targets)   //对多少个目标
        {
            var list = new List<GameObject>();  //每个目标多少次特效对象
            for (int i = 0; i < _singleCount; i++)
            {
                //  实例化特效
                GameObject effectsPrefab = Instantiate(EffectsPrefab, _C_Ability.transform);
                //Type C_FightEffect = _target.GetComponent<C_FightEffect>().GetType();
                // SC_Skill = Assembly.GetExecutingAssembly().GetType(Card.SO_Skill.skillId);
                var effect = effectsPrefab.GetComponent<C_FightEffect>();
                if (effect == null)
                {
                    Debug.LogError("EffectsPrefab 上没有 C_FightEffect，请检查预制体！");
                    continue;
                }
                //加载相关技能脚本
                //effectsPrefab.AddComponent(C_FightEffect);

                //设置技能脚本
                // _C_Ability_T.Init_Effect(_C_Effect_T, _targetObj);
                // _C_Effect_T.Init_Effect(_C_Ability_T, _targetObj);
                // tx.GetComponent<CC_Effects>().Skill_Targets = SC_Skill;

                //设置特效所需数据
                // tx.GetComponent<C_Ability_T>().target = _target;
                // tx.GetComponent<C_Ability_T>().SO_Skill = SO_Skill;
                // tx.GetComponent<C_Ability_T>().hero = this.gameObject;

                //调整特效大小
                effectsPrefab.GetComponent<RectTransform>().sizeDelta = new Vector2(120, 120);
                //调整位置和父对象(利用传入的技能脚本持有人的位置)
                effectsPrefab.transform.position = _C_Ability.transform.position;
                effectsPrefab.transform.SetParent(transform, false);
                //初始化特效上的特效控制器参数
                effectsPrefab.GetComponent<C_FightEffect>().Init_Effect(_C_Ability, _target, _tx_Skill_Model);
                //给控制特效脚本添加数据
                effectsPrefab.GetComponent<C_FightEffect>().value = _value;   //记录需要传递的数值
                effectsPrefab.GetComponent<C_FightEffect>().modifierKey = _modifierKey; //记录传递数值的类型

                //给预制体分配对应属性
                effectsPrefab.GetComponent<Animator>().runtimeAnimatorController = _RuntimeAnimatorController;
                list.Add(effectsPrefab);
            }
            prepared[_target] = list;
        }
        //返回特效对目标以及对其多少次的记录表
        return prepared;
    }

    // 播放已准备好的特效：并行对多个目标播放，每个目标内部按顺序播放 singleCount 次，shots 之间有 delayBetween
    public IEnumerator PlayPreparedEffects(Dictionary<GameObject, List<GameObject>> prepared, float delayBetween)
    {
        if (prepared == null || prepared.Count == 0) yield break;

        //int pendingTargets = prepared.Count;
        foreach (var kv in prepared)
        {
            // 并行启动每个 target 的播放特效协程
            StartCoroutine(PlayEffectsForSingleTarget(kv.Key, kv.Value, delayBetween));
        }

        // 等待所有特效完毕后才执行后续
        yield return new WaitUntil(() => activeAnimations == 0);    //注意这是成员变量
        Debug.Log("本次生成的所有特效播放完成");
    }

    IEnumerator PlayEffectsForSingleTarget(GameObject target, List<GameObject> effects, float delayBetween)
    {
        foreach (var fx in effects)
        {
            // 记录执行了多少个特效
            activeAnimations++;
            // 执行特效上的控制器
            fx.GetComponent<C_FightEffect>().Set_Action();

            // 每次 shot 之间的视觉延迟
            yield return new WaitForSeconds(delayBetween);
        }
    }
    //======瞬发的特效通用方法======//[协程+Animation]
    //对单个目标x次特效 x 对 1, //单个目标x次特效间延迟间隔,//技能特效状态机控制器,//特效尺寸大小,//要释放技能的技能脚本,//技能释放的目标
    // public IEnumerator CreateTX_Instant(int singleCount, float delayBetween, RuntimeAnimatorController skillTX_AniController, params GameObject[] effectTargets)
    // {
    //     // 使用局部变量避免覆盖
    //     int localSingleCount = singleCount;
    //     float localDelayBetween = delayBetween;
    //     RuntimeAnimatorController localController = skillTX_AniController;
    //     //技能脚本赋值[只有一个技能释放]
    //     // usingSkill = useSkill_Script;
    //     // 返回主协程
    //     return TX_Instant_Targets(localSingleCount, localDelayBetween, localController, effectTargets);
    // }
    // // 修改主协程接收所有参数
    // IEnumerator TX_Instant_Targets(int singleCount, float delayBetween, RuntimeAnimatorController skillTX_AniController, params GameObject[] effectTargets)
    // {
    //     // int totalTarget = effectTargets.Length;
    //     // var coroutines = new List<Coroutine>(totalTarget);
    //     // // 使用局部变量存储参数
    //     // int localSingleCount = singleCount;
    //     // float localDelayBetween = delayBetween;
    //     // // float localDamage = skill_TX_damage;
    //     // RuntimeAnimatorController localController = skillTX_AniController;
    //     // // Vector2 localSize = tx_Size;
    //     // // 对每个目标启动协程
    //     // foreach (GameObject target in effectTargets)
    //     // {
    //     //     coroutines.Add(StartCoroutine(TX_Instant_Single(target, localSingleCount, localDelayBetween, localController)));
    //     // }
    //     // // 等待所有协程完成
    //     // foreach (var coroutine in coroutines)
    //     // {
    //     //     yield return coroutine;
    //     // }
    // }
    // //======特效动画的一些通用方法======//
    // //飞行物的特效通用方法



    // // 调整角度
    // // if (_releaseMission == 1)
    // // {

    // //加载相关技能脚本
    // // AddSkillScript(tx);
    // //调整特效大小
    // // tx.GetComponent<RectTransform>().sizeDelta = new Vector2(120, 120);
    // // //给预制体分配对应属性
    // // tx.GetComponent<CC_Skill>().target = _target;
    // // // tx.GetComponent<CC_Skill>().damage = damage;

    // // tx.GetComponent<Animator>().runtimeAnimatorController = animController;
    // // }
    // // Vector2 direction = _target.transform.position - tx.transform.position;
    // // float targetAngle = Mathf.Atan2(direction.y, direction.x) * Mathf.Rad2Deg;
    // // tx.transform.rotation = Quaternion.Euler(0, 0, targetAngle);
    // // Vector2 direction = target.transform.position - tx.transform.position;
    // // float targetAngle = Mathf.Atan2(direction.y, direction.x) * Mathf.Rad2Deg - 90f;
    // // Tween rotateTween = tx.transform.DORotate(new Vector3(0, 0, targetAngle), moveDuration / 5)
    // //  .SetEase(Ease.InOutSine);
    // // childSequence.Append(rotateTween);
    // // 让特效修改为飞行动画状态
    // // 创建局部 Sequence 控制单个飞行物的动画
    // // -------下方是飞行动画
    // //     DG.Tweening.Sequence childSequence = DOTween.Sequence();
    // //     Debug.Log("成功创建特效实例");
    // //     tx.GetComponent<Animator>().SetTrigger("isAttacking");
    // //     //  移动到目标
    // //     float distance = GetBetweenDistance(gameObject, _target);// 计算移动距离和飞行时间
    // //     float time = GetFlightTime(distance);
    // //     Tween moveTween = tx.transform.DOMove(_target.transform.position, time)//由慢到快，较强加速感
    // //         .SetEase(Ease.InCubic);
    // //     childSequence.Append(moveTween);
    // //     //  动画完成后减少计数器
    // //     childSequence.OnComplete(() =>
    // //     {
    // //         activeTweens--;
    // //         // 减少透明度
    // //         tx.GetComponent<Image>().DOFade(0f, time / 3);
    // //         // 让特效修改为结束状态
    // //         tx.GetComponent<Animator>().SetTrigger("isAttacked");
    // //     });

    // //瞬发
    // // 子协程接收所有必要参数
    // IEnumerator TX_Instant_Single(GameObject _target, int singleCount, float delayBetween, RuntimeAnimatorController skillTX_AniController)
    // {
    //     // 使用局部变量
    //     // int localSingleCount = singleCount;
    //     // float localDelayBetween = delayBetween;
    //     // // float localDamage = skill_TX_damage;
    //     // RuntimeAnimatorController localController = skillTX_AniController;
    //     // // Vector2 localSize = new Vector2(120, 120); // 特效尺寸大小
    //     // //启用序列
    //     // DG.Tweening.Sequence sequence = DOTween.Sequence();
    //     // for (int i = 0; i < localSingleCount; i++)
    //     // {
    //     //     // 传递所有参数给配置方法
    //     //     sequence.AppendCallback(() => ConfigureSingleTX_Instant(_target, localController));
    //     //     activeAnimations++; // 增加计数器

    //     //     //  添加间隔[最后一个不用加]
    //     //     if (i != localSingleCount - 1)
    //     //     {
    //     //         sequence.AppendInterval(localDelayBetween);
    //     //     }
    //     // }

    //     // yield return new WaitUntil(() => activeAnimations == 0);
    // }
    // //创建特效预制体
    // private void ConfigureSingleTX_Instant(GameObject _target, RuntimeAnimatorController animController)
    // {
    //     //  实例化特效
    //     // GameObject tx = Instantiate(skill_TX_Missile_Prefab, gameObject.transform);

    //     // //加载相关技能脚本
    //     // // AddSkillScript(tx);
    //     // tx.AddComponent(Assembly.GetExecutingAssembly().GetType(skillId));
    //     // tx.GetComponent<CC_Effects>().Skill_Targets = GetComponent<Skill_Targets>();
    //     // tx.transform.position = gameObject.transform.position;
    //     // //调整特效大小
    //     // tx.GetComponent<RectTransform>().sizeDelta = new Vector2(120, 120);
    //     // //给预制体分配对应属性
    //     // tx.GetComponent<CC_Skill>().target = _target;
    //     // // tx.GetComponent<CC_Skill>().damage = damage;

    //     // tx.GetComponent<Animator>().runtimeAnimatorController = animController;
    //     // 调整角度
    // }

    // // 在这里执行后续逻辑
    // if (isIgnoreMagic)
    // {
    //     self.GetComponent<C_Damage>().SumMana(IgnoreMagic_AddMagic);
    //     self.GetComponent<FightCard>().Ability();
    //     isIgnoreMagic = false;
    // }
    // else
    // {
    //     self.GetComponent<FightCard>().NotifyActionCompleted();
    // }


    //======动态给tx对象挂载技能对应的脚本方法======//
    // private void AddSkillScript(GameObject _tx)
    // {
    //     //从SO数据上获取该对象的技能编号
    //     string skillName = skillId;
    //     Type skillScript_Tpye = Assembly.GetExecutingAssembly().GetType(skillName);
    //     if (skillScript_Tpye == null)
    //     {
    //         Debug.LogError($"未找到技能类型: {skillName}");
    //         return;
    //     }
    //     if (skillScript_Tpye != null)
    //     {
    //         //动态添加并保存引用
    //         SC_skill = (CC_Skill)_tx.AddComponent(skillScript_Tpye);
    //         Debug.Log($"技能加载成功: {SC_skill.GetType().Name}");
    //         // SC_skill = (CC_Skill)_tx.AddComponent(Assembly.GetExecutingAssembly().GetType(skillName));
    //     }
    // }
    // public float GetBetweenDistance(GameObject targetA, GameObject targetB)      //获得两者之间的距离
    // {
    //     float distance = Vector3.Distance(targetA.transform.position, targetB.transform.position);
    //     return distance;
    // }
    // public float GetFlightTime(float distance)    //获得飞行时间  
    // {   //固定速度，近快远慢
    //     float basicSpeed = 1200f;//基准速度可调
    //     float time = distance / basicSpeed;
    //     return time;
    // }

    // public void SkillEnd()  //技能释放结束
    // {
    //     Manager_FightCardTimeline.GetComponent<Manager_FightCardTimeline>().SkillCompleted();
    //     Debug.Log("技能释放结束");
    // }
}

//======动画事件回调（由 Animation Event 触发）「只有用animation动画方式需要这个」======//
