using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;

//======卡牌运行时动态数据类======//
public class Card
{
    //====== 基础数据 ======//
    public SO_Card SO_Card; // 卡牌基础数据
    public SO_Ability SO_Ability; // 卡牌技能基础数据
    public List<SO_Secrecy> SO_Secrecy; // 卡牌隐秘之力表
    public List<SO_Equip> SO_Equip_List; // 卡牌穿戴的装备表
    public List<SO_Aurora> SO_Aurora_List; // 卡牌星能之力表
    public List<SO_Pollution> SO_Pollution_List; // 卡牌污染表

    //====== 动态数据 ======//
    public float hp; // 动态生命值
    public int mana; // 法力值
    public int posIndex = -1; // 对战位置排序号, -1=不出战, 0=第一个位置, 1=第二个位置...
    public int rank; // 星级
    public int grade; // 等级
    public bool isUnlocked = false; // 是否解锁 (核心状态)
    public List<int> secrecyList = new List<int> { 1 }; // 隐秘之力列表

    // --- 内部状态 --- (临时数据)
    public float maxHP; // 临时最大血量
    public int manaMax; // 临时最大法力

    // --- 内部状态 --- (技能与词条)
    // public List<T_Skill> skill_SCList; // 技能脚本
    List<Entry> entryList; // 词条列表

    // ==========================================
    // 1. 初始化与工厂方法 (Init/Factory)
    // ==========================================

    /// <summary>
    /// 骰子/卡牌创建时, 通过构造函数获取基本数据
    /// 这里负责: 赋值 SO_Card 数据作为基础模板
    /// </summary>
    /// <param name="_SO_Card">卡牌基础设定数据</param>
    public Card(SO_Card _SO_Card)
    {
        SO_Card = _SO_Card;
    }

    /// <summary>
    /// 【核心】初始化英雄卡牌状态
    /// 这里负责: 1.设置为已解锁状态, 2.赋予最大生命值, 3.设置当前血量与对战站位
    /// </summary>
    /// <param name="_hp">初始生命值</param>
    /// <param name="_posIndex">位置索引, -1代表不出战</param>
    public void Init_HeroCard(float _hp, int _posIndex) // 初始化所有非SO的动态数据
    {
        isUnlocked = true; // 调用了这个方法说明肯定解锁了
        maxHP = SO_Card.hpMax;
        hp = _hp;
        posIndex = _posIndex;
        SO_Equip_List = null;
    }

    /// <summary>
    /// 更新英雄卡牌数据
    /// 这里负责: 更新当前血量
    /// </summary>
    /// <param name="_hp">新的生命值</param>
    public void Update_HeroCard(float _hp) // 初始化所有非SO的动态数据
    {
        hp = _hp;
    }
}
