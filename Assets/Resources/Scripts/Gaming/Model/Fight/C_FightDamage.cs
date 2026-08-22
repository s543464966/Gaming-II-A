using System;
using System.Collections;
using System.Collections.Generic;
using TMPro;
using Unity.VisualScripting;
using UnityEngine;

public class C_FightDamage : MonoBehaviour  // 伤害处理中心
{
    //====== 内部状态 ======//
    [HideInInspector] public Card Card; // 卡牌实体数据
    [HideInInspector] public Fight_Entry Fight_Entry; // 战斗词条总控
    [HideInInspector] public C_FightCard C_FightCard; // 卡牌视觉表现组件
    [HideInInspector] public int rank; // 养成等阶
    [HideInInspector] public float hp; // 当前生命值
    [HideInInspector] public float mana; // 当前法力值
    [HideInInspector] public float hpMax; // 最大生命值
    [HideInInspector] public int manaMax; // 最大法力值
    [HideInInspector] public float atk; // 物理攻击力
    [HideInInspector] public float mtk; // 魔法攻击力
    [HideInInspector] public float dp; // 护盾值
    [HideInInspector] public int manaType; // 法力类型
    [HideInInspector] public int atkCombo; // 连击层数
    [HideInInspector] public int manaCombo; // 施法频次
    private int damage_Offset = 0; // 伤害抵消次数
    private int durationTimes_Curse_Health = 0; // 诅咒扣血持续次数
    private float damage_Curse_extraFactor = 0; // 诅咒易伤系数
    private float treat_extraFactor = 0; // 治疗加成系数

    //====== 战斗显示组件 ======//
    [Header("模块: 战斗显示组件")]
    [Tooltip("用于显示伤害等漂浮数字的预制体")] 
    public GameObject DisplayDamagePrefab; // 漂浮数字对象预制体

    // ==========================================
    // 1. 数据基盘初始化 (Initialize)
    // ==========================================

    /// <summary>
    /// 【核心】初始化战斗承伤数据
    /// 负责: 1.保存组件引用, 2.初始化生命值和攻击力等属性, 3.刷新面板状态
    /// </summary>
    /// <param name="_SO_Card">卡牌配置模板</param>
    /// <param name="_Fight_Entry">词条控制器</param>
    /// <param name="_C_FightCard">卡牌视觉表现组件</param>
    public void Init_FightValue(SO_Card _SO_Card, Fight_Entry _Fight_Entry, C_FightCard _C_FightCard)
    {
        //加载必要组件
        C_FightCard = _C_FightCard;
        Fight_Entry = _Fight_Entry;

        //加载SO_Card数据
        hp = _SO_Card.hpMax;
        hpMax = _SO_Card.hpMax;
        manaMax = _SO_Card.manaMax;
        atk = _SO_Card.atk;

        //这里是仅玩家需要初始化的数据
        if (_C_FightCard.Card != null)
        {
            Card = _C_FightCard.Card;
            hp = Card.hp;
            //加载天赋数据
            //加载装备数据
            // foreach (SO_Equip _SO_Equip in _Card.SO_Equip_List)
            // {
            //     //在这里挨个加载
            // }
            //加载星能数据
            //加载污染数据

        }

        //更新卡牌UI
        C_FightCard.Update_CardUI_HP(hp, hpMax, dp);
        C_FightCard.Update_CardUI_Atk(atk);
        C_FightCard.Update_CardUI_Mana(mana);
    }


    // ==========================================
    // 2. 攻击目标 (Target)
    // ==========================================

    /// <summary>
    /// 对目标造成物理攻击伤害
    /// </summary>
    /// <param name="_target">受击目标对象</param>
    public void ToTarget_Attack_Atk(GameObject _target)
    {
        //触发词条: 攻击目标 - 1
        Fight_Entry.Trigger_Entry(1);
        //计算并处理：攻击
        _target.GetComponent<C_FightDamage>().ToSelf_Damage_Hp(-atk);
        //触发词条: 攻击目标后 - 3
        Fight_Entry.Trigger_Entry(3);
    }

    /// <summary>
    /// 对目标造成魔法攻击伤害
    /// </summary>
    /// <param name="_target">受击目标对象</param>
    public void ToTarget_Attack_Mtk(GameObject _target)
    {
        //触发词条: 攻击目标 - 1
        Fight_Entry.Trigger_Entry(1);
        //计算并处理：攻击
        _target.GetComponent<C_FightDamage>().ToSelf_Damage_Hp(-mtk);
        //触发词条: 攻击目标后 - 3
        Fight_Entry.Trigger_Entry(3);

    }


    // ==========================================
    // 3. 自身接收伤害 (Self Damage)
    // ==========================================

    /// <summary>
    /// 自身受到扣血伤害
    /// 负责: 1.判断护盾抵消, 2.扣除剩余护盾或生命值, 3.更新面板显示并触发词条
    /// </summary>
    /// <param name="_damage">扣除的生命数值(负数)</param>
    public void ToSelf_Damage_Hp(float _damage)
    {
        if (_damage < 0) //确保负值
        {
            //触发词条: 收到攻击前 - 2
            Fight_Entry.Trigger_Entry(2);

            // --- 核心护盾抵消逻辑 ---(新增护盾逻辑)
            if (dp > 0) // 如果有护盾
            {
                float remainingDamage = _damage + dp; // 计算抵消后的剩余值，例如 -100 + 30 = -70

                if (remainingDamage >= 0)   //护盾完全抵消
                {
                    // 只扣除护盾，扣除量等于伤害值
                    Sum_Dp(_damage);
                }
                else    //伤害溢出护盾值
                {
                    // 先把护盾清零
                    Sum_Dp(-dp);
                    // 再把剩余的溢出伤害扣除血量
                    Sum_HP(remainingDamage);
                }
            }
            else
            {
                //计算并处理：伤害
                Sum_HP(_damage);
            }

            if (C_FightCard.isDead)
            {
                return;
            }

            // //展示伤害漂浮数字
            // Display_UI_FloatText(_damage, FloatTextType.AtkDamage);

            //统一更新UI
            C_FightCard.Update_CardUI_HP(hp, hpMax, dp);

            //触发词条: 收到伤害后 - 6
            Fight_Entry.Trigger_Entry(6);
        }
    }

    // public void Self_RealDamage(float _damage) //收到真实伤害(负值)
    // {
    //     //判断是否有伤害抵消
    //     // if (damage_Offset > 0)
    //     // {
    //     //     damage_Offset--;
    //     //     Debug.Log("伤害被抵消！！！");
    //     //     return;//如果有伤害抵消直接退出方法，后续代码不执行
    //     // }
    //     if (_damage > 0)
    //     {
    //         UI_Display_GetDamage(-_damage);
    //         if (dp > 0) { Effect_DamageDp(-_damage); }
    //         hp -= _damage;  //生命值
    //         // GetComponent<C_FightCard>().HealthChange(hp / hpMax);

    //         //触发词条: 3 - 收到伤害
    //         Fight_Entry.Trigger_Entry(3);
    //         if (hp <= 0) { Set_Dead(); } //生命值小于等于0则触发死亡
    //     }
    // }

    // ==========================================
    // 4. 自身接收增益 (Healing & Shield)
    // ==========================================

    /// <summary>
    /// 恢复固定生命值
    /// </summary>
    /// <param name="_hp">恢复的生命数值(正数)</param>
    public void ToSelf_Healing_Hp(float _hp)
    { Sum_HP(_hp); }

    /// <summary>
    /// 按当前生命值百分比恢复生命
    /// </summary>
    /// <param name="_hpRatio">生命值恢复比例</param>
    public void ToSelf_Healing_HpRatio(float _hpRatio)
    {
        Sum_HP(hp * _hpRatio);
        //统一更新UI
        C_FightCard.Update_CardUI_HP(hp, hpMax, dp);
    }
    
    /// <summary>
    /// 按最大生命值百分比恢复生命
    /// </summary>
    /// <param name="_hpMaxRatio">最大生命值比例</param>
    public void ToSelf_Healing_HpMaxRatio(float _hpMaxRatio)
    { Sum_HP(hpMax * _hpMaxRatio); }

    /// <summary>
    /// 增加护盾值
    /// </summary>
    /// <param name="_dp">增加的护盾数值</param>
    public void ToSelf_Get_Dp(float _dp)
    {
        Sum_Dp(_dp);    //计算

        //统一更新UI
        C_FightCard.Update_CardUI_HP(hp, hpMax, dp);
    }

    // ==========================================
    // 5. 自身接收星能与属性增减
    // ==========================================

    /// <summary>
    /// 增加或减少当前法力值
    /// </summary>
    /// <param name="_mana">法力变化数值</param>
    public void ToSelf_Get_Mana(float _mana)
    {
        Sum_Mana(_mana);
        //统一更新UI
        C_FightCard.Update_CardUI_Mana(mana);
    }
    
    /// <summary>
    /// 增加或减少物理攻击力
    /// </summary>
    /// <param name="_atk">物理攻击力变化数值</param>
    public void ToSelf_Get_Attack(float _atk)
    {
        Sum_Atk(_atk);
        //统一更新UI
        C_FightCard.Update_CardUI_Atk(atk);
    }


    // ----------------------------------------------------------------------------------------------------------
    //模块：Sum - 计算

    // public void Sum_Value(int _valueType, float _value) //更新数据
    // {
    //     switch (_valueType)
    //     {
    //         case 1: Sum_Atk(_value); break; //计算并处理：攻击力
    //         case 2: Sum_HP(_value); break; //计算并处理：生命值
    //         case 3: Sum_HpMax(_value); break; //计算并处理：生命上限
    //         case 4: Sum_Mana(_value); break; //计算并处理：能量
    //         case 5: Sum_ManaMax(_value); break; //计算并处理：能量上限
    //         case 6: Sum_Dp(_value); break; //计算并处理：护盾
    //     }
    //     //(待改进) 更新卡牌UI数据
    // }

    void Sum_HP(float _hp) //计算生命值，获得为+，消耗为-
    {
        hp = Mathf.Clamp(hp += _hp, 0, hpMax); ;

        //展示漂浮数字
        if (_hp < 0) { Display_UI_FloatText(_hp, FloatTextType.AtkDamage); Debug.Log("遭受伤害: " + _hp); }
        else if (_hp > 0) { Display_UI_FloatText(_hp, FloatTextType.Healing); Debug.Log("恢复生命: " + _hp); }

        //更新UI
        //C_FightCard.Update_CardUI_HP(hp, hpMax, dp);

        if (hp <= 0)
        {
            C_FightCard.Set_DeadState_Fight();
            C_FightCard.CC_Fight.SafeDestroy(gameObject);
            return;
        }
        // // 卡牌存活才做动画
        // C_FightCard.Hit_FeedbackAction();
    }

    /// <summary>
    /// 计算额外生命上限
    /// </summary>
    /// <param name="_hpMax">生命上限增量数值</param>
    /// <returns>计算后的最大生命值</returns>
    float Sum_HpMax(float _hpMax)
    {
        //生命上限变更
        hpMax += _hpMax;

        return hpMax;
    }

    /// <summary>
    /// 计算护盾值增减
    /// </summary>
    /// <param name="_dp">护盾变化数值(正为获得，负为消耗)</param>
    /// <returns>计算后的当前护盾值</returns>
    float Sum_Dp(float _dp)
    {
        dp += _dp;

        //展示漂浮数字(可以添加一个护盾的漂浮字体)
        if (_dp < 0) { Display_UI_FloatText(_dp, FloatTextType.AtkDamage); Debug.Log("护盾损失: " + _dp); }
        else if (_dp > 0) { Display_UI_FloatText(_dp, FloatTextType.Healing); Debug.Log("获得护盾: " + _dp); }

        if (dp < 0) { dp = 0; } // 护盾最低为0
        return dp;
    }

    /// <summary>
    /// 计算法力值增减
    /// </summary>
    /// <param name="_mana">法力变化数值(正为获得，负为消耗)</param>
    void Sum_Mana(float _mana)
    {
        // int ma = (int)_mana;
        mana = Mathf.Clamp(mana += _mana, 0, manaMax);
        //C_FightCard.Update_CardUI_Mana(mana);
    }

    /// <summary>
    /// 计算法力上限增量
    /// </summary>
    /// <param name="_manaMax">法力上限增加数值</param>
    void Sum_ManaMax(float _manaMax)
    {
        manaMax += (int)_manaMax;
        if (mana >= manaMax) { mana = manaMax; }
        // C_FightCard.Update_CardUI_Mana(mana);
    }

    /// <summary>
    /// 计算物理攻击力增减
    /// </summary>
    /// <param name="_atk">物理攻击力变化数值</param>
    void Sum_Atk(float _atk)
    {
        //展示漂浮数字(可以添加一个护盾的漂浮字体)
        if (_atk < 0)
        {
            //Display_UI_FloatText(_dp, FloatTextType.AtkDamage);
            Debug.Log("减少攻击力: " + _atk);
        }
        else if (_atk > 0)
        {
            //Display_UI_FloatText(_dp, FloatTextType.Healing); 
            Debug.Log("增加攻击力: " + _atk);
        }
        atk += _atk;
        //C_FightCard.Update_CardUI_Atk(atk);
    }

    /// <summary>
    /// 计算魔法攻击力增量
    /// </summary>
    /// <param name="_mtk">魔法攻击力变化数值</param>
    void Sum_Mtk(float _mtk)
    {
        mtk += _mtk;
    }


    // ----------------------------------------------------------------------------------------------------------  
    //模块：Set - 设置

    // public virtual void Set_Dead()  //触发死亡
    // {
    //     //调用实例卡牌总控
    //     GetComponent<C_FightCard>().CC_Fight.SafeDestroy(gameObject);
    // }

    public void Set_Damage_Offset(int _num_Offset)//增加伤害抵消的次数
    {
        damage_Offset = damage_Offset + _num_Offset;
        Debug.Log("触发伤害减免" + this.name);
    }
    
    /// <summary>
    /// 设置额外治疗加成系数
    /// </summary>
    /// <param name="_extraFactor">治疗加成系数</param>
    public void Set_Treat_extraFactor(float _extraFactor)
    {
        treat_extraFactor = treat_extraFactor + _extraFactor;
    }
    
    /// <summary>
    /// 设置诅咒持续扣血的次数
    /// </summary>
    /// <param name="duration">诅咒持续段数</param>
    public void Set_DurationTimes_Curse_Health(int duration)
    {
        durationTimes_Curse_Health = durationTimes_Curse_Health + duration;
    }
    
    /// <summary>
    /// 设置诅咒附加的易伤系数
    /// </summary>
    /// <param name="_extraFactor">易伤增加系数</param>
    public void Set_Damage_Curse_extraFactor(float _extraFactor)
    {
        damage_Curse_extraFactor = damage_Curse_extraFactor + _extraFactor;
    }


    // ----------------------------------------------------------------------------------------------------------
    //模块：Effect - 特效

    //效果所产生的属性变化方法
    // void Effect_Curse_GetRealDamage(float _damage)//[诅咒]期间额外扣血
    // {
    //     if (durationTimes_Curse_Health > 0 && _damage < 0)
    //     {
    //         //计算公式[额外真实伤害]
    //         _damage = _damage * damage_Curse_extraFactor;
    //         // Display_GetDamage(_damage);
    //         // if (dp > 0) { DamageDp(_damage); }
    //         hp += _damage;
    //         GetComponent<C_FightCard>().HealthChange(hp / hpMax);
    //         //[诅咒]期间扣血后减少次数
    //         durationTimes_Curse_Health--;
    //     }
    // }

    ////伤害中心封闭加工工具
    // float Effect_DamageDp(float _damage) //伤害护盾
    // {
    //     if (_damage > dp)    //如果伤害大于护盾,
    //     {
    //         _damage -= dp;  //伤害减去护盾
    //         dp = 0; //护盾清空
    //     }
    //     else //如果伤害小于等于护盾, 将护盾减少
    //     {
    //         dp -= _damage;  //护盾减少
    //         _damage = 0;    //伤害清空
    //     }
    //     GetComponent<C_FightCard>().ShieldChange(dp / hpMax);  //更新护盾显示
    //     return _damage;
    // }

    // ======卡牌安全销毁接口======//



    // ==========================================
    // 8. 漂浮数字动画显示层 (Display)
    // ==========================================

    public enum FloatTextType
    {
        AtkDamage,       // 红字向下
        Healing,         // 绿字向上  
        CriDamage,       // 金字向上
        PoisonDamage     // 紫字向下
    }

    public enum VerticalAlignment
    {
        Above, //向上
        Below //向下
    }

    /// <summary>
    /// 触发对应类型的漂浮数字显示
    /// 负责: 实例化文本并在指定方向展示数字特效
    /// </summary>
    /// <param name="value">显示的具体数值</param>
    /// <param name="textType">漂浮数字类型(伤害/治疗等)</param>
    public void Display_UI_FloatText(float value, FloatTextType textType)
    {
        GameObject floatText = Instantiate(DisplayDamagePrefab, transform);
        TextMeshProUGUI tmp = floatText.GetComponent<TextMeshProUGUI>();

        // 配置不同类型的显示样式
        switch (textType)
        {
            case FloatTextType.AtkDamage:
                ShowTextAtPosition(floatText, value, Color.red, VerticalAlignment.Below);
                break;
            case FloatTextType.Healing:
                ShowTextAtPosition(floatText, value, Color.green, VerticalAlignment.Above);
                break;
            case FloatTextType.CriDamage:
                ShowTextAtPosition(floatText, value, Color.yellow, VerticalAlignment.Above);
                break;
            case FloatTextType.PoisonDamage:
                ShowTextAtPosition(floatText, value, Color.magenta, VerticalAlignment.Below);
                break;
        }
    }

    void ShowTextAtPosition(GameObject _floatText, float value, Color color, VerticalAlignment _alignment)
    {
        RectTransform rectTransform = GetComponent<RectTransform>();
        RectTransform textRectTransform = _floatText.GetComponent<RectTransform>();

        float yDirection = _alignment == VerticalAlignment.Above ? 1 : -1;
        float offsetY = yDirection * (rectTransform.rect.height / 2 + textRectTransform.rect.height / 2);

        Vector2 worldPos = new Vector2(transform.position.x, transform.position.y + offsetY);
        _floatText.transform.position = worldPos;

        TextMeshProUGUI tmp = _floatText.GetComponent<TextMeshProUGUI>();
        tmp.text = Mathf.Abs(value).ToString(); // 取绝对值，显示正数
        tmp.color = color;
    }
}
