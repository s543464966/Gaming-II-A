using System.Collections;
using UnityEngine;
using DG.Tweening;
using System.Collections.Generic;

public class Ab001 : C_Ability_T //技能0005：治疗/恢复类技能（当前逻辑被注释）//模版
{
    // ----------------------------------------------------------------------------------------------------------
    //模块：Initial - 初始化
    int random_Ratio; //再次释放概率
    float damage_Reduce;  //伤害衰减
    float around_Explore;   //四周爆炸
    public override void Init_Ability() //初始化技能数据
    {
        tx_Skill_Model = Card.SO_Ability.tx_Skill_Model;
        //战斗能力：释放混乱火球，对1个随机目标造成200%攻击力的火焰伤害
        targetType = "Monster";
        targetAxis = "x";
        targetSelf = 0;
        targetNum = 1;
        targetDistance = 0;
        releaseNum = 1;

        //Ability
        skillvalue = 2.0f;

        //加载Fight_Entry词条控制器，并初始化
        // if (Card.SO_Ability.entryType != 0)
        //     Fight_Entry.Change_Entry(true, Card.SO_Ability.entryType, Card.SO_Ability.entryPriority, C_Ability, gameObject);
    }

    public override void Init_AbilitySecrecy() //初始化隐秘之力
    {
        foreach (int _secrecy in Card.secrecyList)
        {
            switch (_secrecy)
            {
                case 1: Init_Securecy_01(); break;
                case 2: Init_Securecy_02(); break;
                case 3: Init_Securecy_03(); break;
                case 4: Init_Securecy_04(); break;
                case 5: Init_Securecy_05(); break;
                case 6: Init_Securecy_06(); break;
                case 7: Init_Securecy_07(); break;
                case 8: Init_Securecy_08(); break;
                case 9: Init_Securecy_09(); break;
                case 10: Init_Securecy_10(); break;
                case 11: Init_Securecy_11(); break;
                case 12: Init_Securecy_12(); break;
                case 13: Init_Securecy_13(); break;
                case 14: Init_Securecy_14(); break;
                case 15: Init_Securecy_15(); break;
            }
        }
    }

    //路线1
    void Init_Securecy_01()
    {
        skillvalue += 0.5f;
    }

    void Init_Securecy_02()
    {
        //skillvalue += 0.2f;
        //  添加{灰烬爆发}词条

    }

    void Init_Securecy_03()
    {
        skillvalue += 1.5f;
    }

    void Init_Securecy_04()
    {
        skillvalue += 2.0f;
    }

    void Init_Securecy_05()
    {
        ;
    }

    //路线2
    void Init_Securecy_06()
    {
        // targetNum += 1;
        //  添加击杀词条
        // if (Card.SO_Ability.entryType != 0)
        //     Fight_Entry.Change_Entry(true, Card.SO_Ability.entryType, Card.SO_Ability.entryPriority, C_Ability, gameObject);
    }

    void Init_Securecy_07()
    {
        targetNum += 1;
    }

    void Init_Securecy_08()
    {
        targetNum += 1;
    }

    void Init_Securecy_09()
    {
        // targetNum += 1;
        //  添加击杀词条

    }

    void Init_Securecy_10()
    {
        ;
    }

    //路线3
    void Init_Securecy_11()
    {
        bool OnOff;
        if (Card.secrecyList[11] == 0) { OnOff = false; } else { OnOff = true; }
        //加载Fight_Entry词条控制器，并初始化
        Fight_Entry.Change_Entry(OnOff, Card.SO_Ability.entryType, Card.SO_Ability.entryPriority, C_Ability, gameObject);

        //  如果不添加词条而是布尔解锁的话，那么就在技能释放后进行判断
        if (Card.secrecyList[11] == 1)
        {
            random_Ratio = 25;
            damage_Reduce = 0.75f;
        }
    }

    void Init_Securecy_12()
    {
        bool OnOff;
        if (Card.secrecyList[12] == 0) { OnOff = false; } else { OnOff = true; }
        //加载Fight_Entry词条控制器，并初始化
        Fight_Entry.Change_Entry(OnOff, Card.SO_Ability.entryType, Card.SO_Ability.entryPriority, C_Ability, gameObject);

        if (Card.secrecyList[12] == 1)
        {
            around_Explore = 0.25f;
        }
    }

    void Init_Securecy_13()
    {
        bool OnOff;
        if (Card.secrecyList[13] == 0) { OnOff = false; } else { OnOff = true; }
        //加载Fight_Entry词条控制器，并初始化
        Fight_Entry.Change_Entry(OnOff, Card.SO_Ability.entryType, Card.SO_Ability.entryPriority, C_Ability, gameObject);

        //  解锁增加释放概率
        if (Card.secrecyList[13] == 1)
        {
            random_Ratio += 25;
            damage_Reduce -= 0.25f;
        }
    }

    void Init_Securecy_14()
    {
        bool OnOff;
        if (Card.secrecyList[14] == 0) { OnOff = false; } else { OnOff = true; }
        //加载Fight_Entry词条控制器，并初始化
        Fight_Entry.Change_Entry(OnOff, Card.SO_Ability.entryType, Card.SO_Ability.entryPriority, C_Ability, gameObject);

        // 能够暴击
    }

    void Init_Securecy_15()
    {
        ;
    }

    //----------------------------------------------------------------------------------------------------------
    //模块：Ability - 能力

    public override void Ability_Release()
    {
        // 启动该技能具体释放顺序
        StartCoroutine(Ability_Sequence());

        // //1.获取技能目标
        // GameObject[] targets = Fight_Effect.Ability_GetTargets(gameObject, false, 0, true, -1);

        // //2.创建特效实例
        // Fight_Effect.Ability_CreateEffect(targets, releaseNum, 1, C_Ability, RuntimeAnimatorController);

        // //  解锁判断是否会再次释放
        // if (Card.secrecyList[11] == 1)
        // {
        //     int random = Random.Range(0, 100);
        //     if (random < random_Ratio)   //再次释放
        //     {
        //         //1.获取技能目标
        //         GameObject[] targets_1 = Fight_Effect.Ability_GetTargets(gameObject, false, 0, true, -1);

        //         //2.创建特效实例
        //         Fight_Effect.Ability_CreateEffect(targets_1, releaseNum, 1, C_Ability, RuntimeAnimatorController);
        //     }
        //     // 把伤害挂到特效上，这样实现伤害记录下来
        // }

    }

    public override void Ability_Hit(GameObject _targetObj,ModifierKey _modifierKey,float _value) //初始化特效
    {
        //处理当前技能伤害
        //float damage = GetComponent<C_FightDamage>().atk * skillvalue;

        //  每个具体实现做数值判断
        if (_modifierKey == ModifierKey.Damage)
        {
            //转为造成伤害
            _value = _value * -1.0f;
            _targetObj.GetComponent<C_FightDamage>().ToSelf_Damage_Hp(_value);
        }
        //解锁特效命中后寻找目标四周的卡牌造成伤害
        // if (Card.secrecyList[12] == 1)
        // {
        //     //获取四周目标
        //     GameObject[] targets = Fight_Effect.Ability_GetTargets(_targetObj, false, 0, false, -1);

        //     //计算所造成的伤害引起四周造成的爆炸伤害
        //     float damage = _damage * around_Explore;
        //     foreach(GameObject target in targets)
        //     {
        //         target.GetComponent<C_FightDamage>().ToSelf_Damage_Hp(damage);
        //     }
        // }
    }

    protected override IEnumerator Ability_Sequence()   //具体实现技能释放顺序
    {
        Debug.Log("Ability_Sequence start");
        //1.获取技能目标
        GameObject[] targets = Fight_Effect.Ability_GetTargets(gameObject, true, 0, false, -1);
        //处理当前技能效果
        float damage = GetComponent<C_FightDamage>().atk * skillvalue;
        Debug.Log("Before Prepare");
        //2.创建特效实例
        Dictionary<GameObject, List<GameObject>> txs = Fight_Effect.Prepare_EffectsForTargets(releaseNum, damage,ModifierKey.Damage, C_Ability, RuntimeAnimatorController, tx_Skill_Model, targets);
        Debug.Log("After Prepare");
        Debug.Log("Before PlayPreparedEffects");
        //3.执行特效
        Coroutine lastCoroutine = StartCoroutine(Fight_Effect.PlayPreparedEffects(txs,1f));
        
        //  解锁判断是否会再次释放
        // if (Card.secrecyList[11] == 1)
        // {
        //     //等待0.5s后
        //     yield return new WaitForSeconds(0.5f);

        //     int random = Random.Range(0,100);
        //     if(random < random_Ratio)   //再次释放
        //     {
        //         //处理当前技能效果
        //         damage = damage * damage_Reduce;
        //         //2.创建特效实例
        //         txs = Fight_Effect.Prepare_EffectsForTargets(releaseNum, damage, C_Ability, RuntimeAnimatorController, tx_Skill_Model, targets);
        //         //3.执行特效
        //         lastCoroutine = StartCoroutine(Fight_Effect.PlayPreparedEffects(txs, 1f));
        //     }
        // }
        yield return lastCoroutine;
        Debug.Log("After PlayPreparedEffects");
        //彻底完成后再通知该技能完成
        GetComponent<C_FightCard>().Notify_ActionCompleted();
    }
}
