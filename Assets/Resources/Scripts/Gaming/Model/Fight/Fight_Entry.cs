using System.Collections.Generic;
using UnityEngine;
using System.Linq;

public class Fight_Entry : MonoBehaviour
{
    // --- 内部状态 --- (词条容器)
    Dictionary<int, List<Entry>> entryList_Dict = new Dictionary<int, List<Entry>>();

    [Header("模块: 基础通用词条槽 (Common)")]
    [HideInInspector] public List<Entry> entryList_Target_Attack = new List<Entry>(); //攻击目标前
    [HideInInspector] public List<Entry> entryList_Get_Attack = new List<Entry>(); //收到攻击前
    [HideInInspector] public List<Entry> entryList_Target_AfterAttack = new List<Entry>(); //攻击目标后
    [HideInInspector] public List<Entry> entryList_Target_Atk = new List<Entry>(); //失去攻击力后
    [HideInInspector] public List<Entry> entryList_Get_Heal = new List<Entry>(); //获得治疗后
    [HideInInspector] public List<Entry> entryList_Get_Damage = new List<Entry>(); //获得伤害后
    [HideInInspector] public List<Entry> entryList_Get_Shield = new List<Entry>(); //获得护盾后
    [HideInInspector] public List<Entry> entryList_Get_LoseShield = new List<Entry>(); //失去护盾后

    [Header("模块: 专精特化词条槽 (Feature)")]
    [HideInInspector] public List<Entry> entryListReady = new List<Entry>(); //登场
    [HideInInspector] public List<Entry> entryListFirst = new List<Entry>(); //先手
    [HideInInspector] public List<Entry> entryListUndead = new List<Entry>(); //不死
    [HideInInspector] public List<Entry> entryListCrazy = new List<Entry>(); //疯狂
    [HideInInspector] public List<Entry> entryListKill = new List<Entry>(); //击杀
    [HideInInspector] public List<Entry> entryListDeath = new List<Entry>(); //遗言
    [HideInInspector] public List<Entry> entryListDamageAdd = new List<Entry>(); //增伤
    [HideInInspector] public List<Entry> entryListTaunt = new List<Entry>(); //嘲讽
    [HideInInspector] public List<Entry> entryListBurst = new List<Entry>(); //爆发
    [HideInInspector] public List<Entry> entryListDestiny = new List<Entry>(); //命运
    [HideInInspector] public List<Entry> entryListShield = new List<Entry>(); //护盾
    [HideInInspector] public List<Entry> entryListHeal = new List<Entry>(); //治疗
    [HideInInspector] public List<Entry> entryListSummon = new List<Entry>(); //召唤
    [HideInInspector] public List<Entry> entryListGhost = new List<Entry>(); //亡魂
    [HideInInspector] public List<Entry> entryListElement = new List<Entry>(); //元素
    [HideInInspector] public List<Entry> entryListDie = new List<Entry>(); //死亡
    [HideInInspector] public List<Entry> entryListChoice = new List<Entry>(); //抉择
    [HideInInspector] public List<Entry> entryListStarEnergy = new List<Entry>(); //星能
    [HideInInspector] public List<Entry> entryListPollute = new List<Entry>(); //污染
    [HideInInspector] public List<Entry> entryListCurse = new List<Entry>(); //诅咒
    [HideInInspector] public List<Entry> entryListSweep = new List<Entry>(); //横扫
    [HideInInspector] public List<Entry> entryListExecute = new List<Entry>(); //斩杀

    // ==========================================
    // 1. 词条装配与拨切 (Transform)
    // ==========================================

    // //处理SO_Equip
    // if (Card.SO_Equip_List != null)
    // {
    //     foreach (SO_Equip _SO_Equip in Card.SO_Equip_List)
    //     {
    //         //创建词条
    //         if (_SO_Equip.entryType != 0) Fight_Entry.Change_Entry(true, _SO_Equip.entryType, _SO_Equip.entryPriority, C_Ability_T, gameObject);
    //     }
    // }

    // //处理SO_Aurora
    // if (Card.SO_Aurora_List != null)
    // {
    //     foreach (SO_Aurora _SO_Aurora in Card.SO_Aurora_List)
    //     {
    //         //创建词条
    //         if (_SO_Aurora.entryType != 0) _Fight_Entry.Change_Entry(true, _SO_Aurora.entryType, _SO_Aurora.entryPriority, C_Ability_T, gameObject);
    //     }
    // }

    // //处理SO_Pollution
    // if (Card.SO_Pollution_List != null)
    // {
    //     foreach (SO_Pollution _SO_Pollution in Card.SO_Pollution_List)
    //     {
    //         //创建词条
    //         if (_SO_Pollution.entryType != 0) _Fight_Entry.Change_Entry(true, _SO_Pollution.entryType, _SO_Pollution.entryPriority, C_Ability_T, gameObject);
    //     }
    // }

    // ----------------------------------------------------------------------------------------------------------
    //模块：Change - 变换

    public void Change_Entry(bool _isExit, int _entryType, int _entryPriority, C_Ability_T _C_Ability_T, GameObject _hero)
    {
        List<Entry> targetList = null;

        switch (_entryType) //根据词条类型获得
        {
            case <= 9: targetList = Switch_CommonEntry(_entryType); break;
            case > 9: targetList = Switch_FeatureEntry(_entryType); break;
        }
        if (targetList != null)
        {
            if (_isExit == true) //添加词条
            {
                Creat_EntryTrigger(targetList, _entryType, _entryPriority, _C_Ability_T, _hero);
            }
            else //移除词条
            {
                Destory_EntryTrigger(targetList, _entryType, _entryPriority, _C_Ability_T, _hero);
            }
        }
    }

    List<Entry> Switch_CommonEntry(int _entryType)
    {
        switch (_entryType)
        {
            case 1: return entryList_Target_Attack;
            case 2: return entryList_Get_Attack;
            case 3: return entryList_Target_AfterAttack;
            case 4: return entryList_Target_Atk;
            case 5: return entryList_Get_Heal;
            case 6: return entryList_Get_Damage;
            case 7: return entryList_Get_Heal;
            case 8: return entryList_Get_Shield;
            case 9: return entryList_Get_LoseShield;
        }
        return null;
    }

    List<Entry> Switch_FeatureEntry(int _entryType) //创建或销毁词条
    {
        //根据类型获取对应的列表
        switch (_entryType)
        {
            case 10: return entryListReady;
            case 11: return entryListFirst;
            case 12: return entryListUndead;
            case 13: return entryListCrazy;
            case 14: return entryListKill;
            case 15: return entryListDeath;
            case 16: return entryListDamageAdd;
            case 17: return entryListTaunt;
            case 18: return entryListBurst;
            case 19: return entryListDestiny;
            case 20: return entryListShield;
            case 21: return entryListHeal;
            case 22: return entryListSummon;
            case 23: return entryListGhost;
            case 24: return entryListElement;
            case 25: return entryListDie;
            case 26: return entryListChoice;
            case 27: return entryListStarEnergy;
            case 28: return entryListPollute;
            case 29: return entryListCurse;
            case 30: return entryListSweep;
            case 31: return entryListExecute;
        }
        return null;
    }

    void Creat_EntryTrigger(List<Entry> _entryList, int _entryType, int _entryPriority, C_Ability_T _C_Ability_T, GameObject _cardObj) //创建词条触发器
    {
        //添加词条
        _entryList.Add(new Entry(_entryType, _entryPriority, _cardObj, _C_Ability_T));
        //重新排序
        Sort_EntryTriggerList(_entryList);
    }

    void Destory_EntryTrigger(List<Entry> _entryList, int _entryType, int _entryPriority, C_Ability_T _C_Ability_T, GameObject _cardObj) //销毁词条触发器
    {
        foreach (var _entry in _entryList)
        {
            if (_entry.entryType == _entryType && _entry.entryPriority == _entryPriority && _entry.cardObj == _cardObj)
            {
                //移除词条
                _entryList.Remove(_entry);
                //重新排序
                Sort_EntryTriggerList(_entryList);
                break;
            }
        }
    }

    void Sort_EntryTriggerList(List<Entry> _list) //优先级排序
    {
        if (_list.Count > 1)
        {
            // 使用 LINQ 按照 typyTag 和 typyPriority 排序
            _list = _list.OrderBy(x => x.entryType)
                         .ThenBy(x => x.entryPriority)
                         .ToList();
            // 输出排序后的结果
            for (int i = 0; i < _list.Count; i++)
            {
                Debug.Log($"TriggerSet[{i}] 的 typyTag 值为: {_list[i].entryType}, typyPriority 值为: {_list[i].entryPriority}");
            }
        }
    }


    // ----------------------------------------------------------------------------------------------------------
    //模块：Trigger

    public void Trigger_Entry(int _entryType) //通知触发效果的所有卡牌轮流执行效果
    {
        if (!entryList_Dict.ContainsKey(_entryType) || entryList_Dict[_entryType] == null || entryList_Dict[_entryType].Count == 0) return;

        List<Entry> currentEntryList = entryList_Dict[_entryType];
        // 使用倒序遍历或者创建一个副本进行遍历，以防止在遍历过程中修改集合导致的问题
        List<Entry> listCopy = new List<Entry>(currentEntryList);

        foreach (Entry _trigger in listCopy)
        {
            if (_trigger.cardObj != null)
            {
                switch (_entryType)
                {
                    //CommonEntry
                    case 1: Entry_TargetAttack(_trigger.cardObj); break; //攻击前
                    case 2: Entry_GetAttack(_trigger.cardObj); break; //被攻击
                    case 3: Entry_TargetAfterAttack(_trigger.cardObj, _trigger.entryPriority); break; //攻击后
                    case 4: Entry_GetDamage(_trigger.cardObj, _trigger.entryPriority); break;
                    case 5: Entry_GetAtk(_trigger.cardObj); break;
                    case 6: Entry_TargetAtk(_trigger.cardObj); break;
                    case 7: Entry_GetHeal(_trigger.cardObj); break;
                    case 8: Entry_GetShield(_trigger.cardObj); break;
                    case 9: Entry_GetLoseShield(_trigger.cardObj); break;
                    //FeatureEntry
                    case 10: Entry_Ready(_trigger.cardObj); break;
                    case 11: Entry_First(_trigger.cardObj); break;
                    case 12: Entry_Undead(_trigger.cardObj); break;
                    case 13: Entry_Crazy(_trigger.cardObj); break;
                    case 14: Entry_Kill(_trigger.cardObj, _trigger.entryPriority); break;
                    case 15: Entry_Death(_trigger.cardObj); break;
                    case 16: Entry_DamageAdd(_trigger.cardObj); break;
                    case 17: Entry_Taunt(_trigger.cardObj); break;
                    case 18: Entry_Burst(_trigger.cardObj); break;
                    case 19: Entry_Destiny(_trigger.cardObj); break;
                    case 20: Entry_Shield(_trigger.cardObj); break;
                    case 21: Entry_Heal(_trigger.cardObj); break;
                    case 22: Entry_Summon(_trigger.cardObj); break;
                    case 23: Entry_Ghost(_trigger.cardObj); break;
                    case 24: Entry_Element(_trigger.cardObj); break;
                    case 25: Entry_Die(_trigger.cardObj); break;
                    case 26: Entry_Choice(_trigger.cardObj); break;
                    case 27: Entry_StarEnergy(_trigger.cardObj); break;
                    case 28: Entry_Pollute(_trigger.cardObj); break;
                    case 29: Entry_Curse(_trigger.cardObj); break;
                    case 30: Entry_Sweep(_trigger.cardObj); break;
                    case 31: Entry_Execute(_trigger.cardObj); break;
                }
            }
            else
            {
                currentEntryList.Remove(_trigger);
                Debug.Log($"已从列表 {_entryType} 中移除 TriggerSet 原因是 hero 为 null");
            }
        }
        //通知CC_Fight执行下一个骰子效果
    }


    // ----------------------------------------------------------------------------------------------------------
    //模块：Entry - 词条

    void Entry_TargetAttack(GameObject _obj) //攻击触发
    {
        if (entryList_Target_Attack.Count > 0)
        {
            foreach (var _entry in entryList_Target_Attack)
            {
                if (_entry.cardObj == _obj)
                {
                    //这里是每个种词条的独有特效;
                }
            }
        }
    }
    void Entry_GetAttack(GameObject _obj) //被攻击触发
    {
        //这里是每个种词条的独有特效;
    }
    void Entry_TargetAfterAttack(GameObject _obj, int _entryPriority) //攻击目标后
    {
        //这里是每个种词条的独有特效;
        switch (_entryPriority)
        {
            case 1://每次攻击增加自身1点攻击力
                _obj.GetComponent<C_FightDamage>().ToSelf_Get_Attack(1f);
                break;
            case 2://每次攻击增加自身2点攻击力
                _obj.GetComponent<C_FightDamage>().ToSelf_Get_Attack(2f);
                break;
            case 3://每次攻击增加自身3点攻击力
                _obj.GetComponent<C_FightDamage>().ToSelf_Get_Attack(3f);
                break;
            case 4://每次攻击增加自身5点攻击力
                _obj.GetComponent<C_FightDamage>().ToSelf_Get_Attack(5f);
                break;

        }
    }
    void Entry_GetAtk(GameObject _obj) //受到攻击力触发
    {
        //这里是每个种词条的独有特效;
    }
    void Entry_TargetAtk(GameObject _obj) //失去攻击力触发
    {
        //这里是每个种词条的独有特效;
    }
    void Entry_GetDamage(GameObject _obj, int _entryPriority) //受到伤害触发
    {
        //这里是每个种词条的独有特效;
        switch (_entryPriority)
        {
            case 1:
                foreach (Entry _entry in entryList_Target_AfterAttack)
                {
                    // _entry.cardObj.GetComponent<C_FightDamage>.;
                }
                break;
            case 2:
                _obj.GetComponent<C_FightDamage>().ToSelf_Get_Mana(1f);
                break;
        }
    }
    void Entry_GetHeal(GameObject _obj) //受到治疗触发
    {
        //这里是每个种词条的独有特效;
    }
    void Entry_GetShield(GameObject _obj) //受到护盾触发
    {
        //这里是每个种词条的独有特效;
    }
    void Entry_GetLoseShield(GameObject _obj) //失去护盾触发
    {
        //这里是每个种词条的独有特效;
    }

    //EntryFeature
    void Entry_Ready(GameObject _obj) //登场触发
    {
        //这里是每个种词条的独有特效;
    }
    void Entry_First(GameObject _obj) //先手触发
    {
        //这里是每个种词条的独有特效;
    }
    void Entry_Undead(GameObject _obj) //不死触发
    {
        //这里是每个种词条的独有特效;
    }
    void Entry_Crazy(GameObject _obj) //疯狂触发
    {
        //这里是每个种词条的独有特效;
    }
    void Entry_Kill(GameObject _obj, int _entryPriority) //击杀触发
    {
        //这里是每个种词条的独有特效;
        switch (_entryPriority)
        {
            case 1: //获得当前50%的攻击力
                float currentAtk = _obj.GetComponent<C_FightDamage>().atk;
                _obj.GetComponent<C_FightDamage>().ToSelf_Get_Attack(currentAtk * 0.5f);
                break;
            case 2://获得1点星能值
                _obj.GetComponent<C_FightDamage>().ToSelf_Get_Mana(1f);
                break;
        }
    }
    void Entry_Death(GameObject _obj) //遗言触发
    {
        //这里是每个种词条的独有特效;
    }
    void Entry_DamageAdd(GameObject _obj) //增伤触发
    {
        //这里是每个种词条的独有特效;
    }
    void Entry_Taunt(GameObject _obj) //嘲讽触发
    {
        //这里是每个种词条的独有特效;
    }
    void Entry_Burst(GameObject _obj) //爆发触发
    {
        //这里是每个种词条的独有特效;
    }
    void Entry_Destiny(GameObject _obj) //命运触发
    {
        //这里是每个种词条的独有特效;
    }
    void Entry_Shield(GameObject _obj) //护盾触发
    {
        //这里是每个种词条的独有特效;
    }
    void Entry_Heal(GameObject _obj) //治疗触发
    {
        //这里是每个种词条的独有特效;
    }
    void Entry_Summon(GameObject _obj) //召唤触发
    {
        //这里是每个种词条的独有特效;
    }
    void Entry_Ghost(GameObject _obj) //亡魂触发
    {
        //这里是每个种词条的独有特效;
    }
    void Entry_Element(GameObject _obj) //元素触发
    {
        //这里是每个种词条的独有特效;
    }
    void Entry_Die(GameObject _obj) //死亡触发
    {
        //这里是每个种词条的独有特效;
    }
    void Entry_Choice(GameObject _obj) //抉择触发
    {
        //这里是每个种词条的独有特效;
    }
    void Entry_StarEnergy(GameObject _obj) //星能触发
    {
        //这里是每个种词条的独有特效;
    }
    void Entry_Pollute(GameObject _obj) //污染触发
    {
        //这里是每个种词条的独有特效;
    }
    void Entry_Curse(GameObject _obj) //诅咒触发
    {
        //这里是每个种词条的独有特效;
    }
    void Entry_Sweep(GameObject _obj) //横扫触发
    {
        //这里是每个种词条的独有特效;
    }

    void Entry_Execute(GameObject _obj) //斩杀
    {
        //这里是每个种词条的独有特效;
    }
}
