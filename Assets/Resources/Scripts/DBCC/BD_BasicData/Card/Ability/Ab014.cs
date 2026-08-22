using System.Collections;
using System.Collections.Generic;
using TMPro;
using UnityEngine;

public class Ability0014 : C_Ability_T //技能0014：天赋增强型技能
{
    // ----------------------------------------------------------------------------------------------------------
    //模块：Initial - 初始化

    public override void Init_Ability() //初始化技能数据
    {
        //战斗能力：在接下来的3次攻击，附带75%攻击力的「灰烬」伤害。立即触发一次攻击。疯狂。
        targetType = "Monster";
        targetAxis = "x";
        targetSelf = 0;
        targetNum = 1;
        targetDistance = 0;
        releaseNum = 1;

        //Ability
        skillvalue = 0.75f;

        //加载Fight_Entry词条控制器，并初始化
        if (Card.SO_Ability.entryType != 0)
            Fight_Entry.Change_Entry(true, Card.SO_Ability.entryType, Card.SO_Ability.entryPriority, C_Ability, gameObject);
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
        skillvalue += 1f;
    }

    void Init_Securecy_03()
    {
        skillvalue += 1.5f;
    }

    void Init_Securecy_04()
    {
        skillvalue += 2f;
    }

    void Init_Securecy_05()
    {
        ;
    }

    //路线2
    void Init_Securecy_06()
    {
        bool OnOff;
        if (Card.secrecyList[06] == 0) { OnOff = false; } else { OnOff = true; }
        //加载Fight_Entry词条控制器，并初始化
        Fight_Entry.Change_Entry(OnOff, Card.SO_Ability.entryType, Card.SO_Ability.entryPriority, C_Ability, gameObject);
    }

    void Init_Securecy_07()
    {
        GetComponent<C_FightDamage>().atkCombo += 1;
    }

    void Init_Securecy_08()
    {
        bool OnOff;
        if (Card.secrecyList[08] == 0) { OnOff = false; } else { OnOff = true; }
        //加载Fight_Entry词条控制器，并初始化
        Fight_Entry.Change_Entry(OnOff, Card.SO_Ability.entryType, Card.SO_Ability.entryPriority, C_Ability, gameObject);
    }

    void Init_Securecy_09()
    {
        GetComponent<C_FightDamage>().atkCombo += 1;;
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
    }

    void Init_Securecy_12()
    {
        bool OnOff;
        if (Card.secrecyList[12] == 0) { OnOff = false; } else { OnOff = true; }
        //加载Fight_Entry词条控制器，并初始化
        Fight_Entry.Change_Entry(OnOff, Card.SO_Ability.entryType, Card.SO_Ability.entryPriority, C_Ability, gameObject);
    }

    void Init_Securecy_13()
    {
        bool OnOff;
        if (Card.secrecyList[13] == 0) { OnOff = false; } else { OnOff = true; }
        //加载Fight_Entry词条控制器，并初始化
        Fight_Entry.Change_Entry(OnOff, Card.SO_Ability.entryType, Card.SO_Ability.entryPriority, C_Ability, gameObject);
    }

    void Init_Securecy_14()
    {
        bool OnOff;
        if (Card.secrecyList[14] == 0) { OnOff = false; } else { OnOff = true; }
        //加载Fight_Entry词条控制器，并初始化
        Fight_Entry.Change_Entry(OnOff, Card.SO_Ability.entryType, Card.SO_Ability.entryPriority, C_Ability, gameObject);
    }

    void Init_Securecy_15()
    {
        ;
    }

    public override void Init_AbilityTalent() //初始化天赋数据
    {
        //各自隐秘技能数值
    }


    // ----------------------------------------------------------------------------------------------------------
    //模块：Ability - 能力

    public override void Ability_Release()
    {
        //1.获取技能目标
        GameObject[] targets = Fight_Effect.Ability_GetTargets(gameObject, false, 0, true, -1);

        //2.创建特效实例
        Fight_Effect.Ability_CreateEffect(targets, releaseNum, 1, C_Ability, RuntimeAnimatorController);
    }

    public override void Ability_Hit(GameObject _targetObj,ModifierKey _modifierKey,float _damage) //初始化特效
    {
        //处理当前技能效果
        float damage = GetComponent<C_FightDamage>().atk * skillvalue;
        GetComponent<C_FightDamage>().ToTarget_Attack_Atk(_targetObj);
    }


    // ----------------------------------------------------------------------------------------------------------
    //模块：Entry - 词条

    public override void Entry_Release(int _entryType) //释放技能
    {
        //各自技能重新维护
        switch (_entryType)
        {
            case 1:
                Entry_Ability_01();
                break;
            case 2:
                Entry_Ability_02();
                break;
        }
    }

    void Entry_Ability_01()
    {

    }

    void Entry_Ability_02()
    {

    }

}
