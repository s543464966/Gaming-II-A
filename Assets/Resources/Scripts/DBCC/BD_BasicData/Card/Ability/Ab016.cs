using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Ab016 : C_Ability_T //技能0016：护盾/防御增益技能
{
    // ----------------------------------------------------------------------------------------------------------
    //模块：Initial - 初始化
    int random_Ratio; //再次释放概率
    float damage_Reduce;  //伤害衰减
    float around_Explore;   //四周爆炸
    public override void Init_Ability() //初始化技能数据
    {
        tx_Skill_Model = Card.SO_Ability.tx_Skill_Model;
        //战斗能力：获得60%灵能护盾并使最近的一个敌方消减敌方1点攻击力
        targetType = "Monster";
        targetAxis = "x";
        targetSelf = 0;
        targetNum = 1;
        targetDistance = 0;
        releaseNum = 1;

        //Ability
        skillvalue = 0.6f;
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
    }

    public override void Ability_Hit(GameObject _targetObj,ModifierKey _modifierKey,float _value) //初始化特效
    {
        switch (_modifierKey)
        {
            case ModifierKey.Dp:
                // 语意：类型是护盾，获得 value 点护盾
                _targetObj.GetComponent<C_FightDamage>().ToSelf_Get_Dp(_value);
                break;
            case ModifierKey.Atk:
                // 语意：类型是加攻，增加 value 点攻击力
                _targetObj.GetComponent<C_FightDamage>().ToSelf_Get_Attack(_value);
                break;
        }
    }

    protected override IEnumerator Ability_Sequence()   //具体实现技能释放顺序
    {
        Debug.Log("Ability_Sequence start");
        // 计算获得的护盾值
        float dp = GetComponent<C_FightDamage>().atk * skillvalue;
        Debug.Log("Before Prepare");
        // 创建特效实例
        Dictionary<GameObject, List<GameObject>> txs = Fight_Effect.Prepare_EffectsForTargets(releaseNum, dp, ModifierKey.Dp, C_Ability, RuntimeAnimatorController, tx_Skill_Model, gameObject);
        Debug.Log("After Prepare");
        Debug.Log("Before PlayPreparedEffects");
        // 执行特效
        Coroutine coroutine1 = StartCoroutine(Fight_Effect.PlayPreparedEffects(txs,1f));
        
        // 计算减少的攻击力
        float atk = -1.0f * 1.0f;
        // 最近的一名敌人
        GameObject[] targets = Fight_Effect.Ability_GetTargets(gameObject, true, 0, false, -1);
        // 创建特效实例
        txs = Fight_Effect.Prepare_EffectsForTargets(releaseNum, atk, ModifierKey.Atk, C_Ability, RuntimeAnimatorController, tx_Skill_Model, targets);
        // 执行特效
        Coroutine coroutine2 = StartCoroutine(Fight_Effect.PlayPreparedEffects(txs,1f));
        
        //等待两者动画都完成
        yield return coroutine1;
        yield return coroutine2;
        Debug.Log("After PlayPreparedEffects");
        //彻底完成后再通知该技能完成
        GetComponent<C_FightCard>().Notify_ActionCompleted();
    }
}
