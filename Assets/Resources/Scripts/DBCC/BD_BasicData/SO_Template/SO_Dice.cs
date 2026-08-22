using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu]
public class SO_Dice : ScriptableObject
{
    // 基础设定
    [Tooltip("骰子ID")] public string diceId; //唯一标识
    [Tooltip("骰子名称")] public string diceName; //骰子名称
    [Tooltip("骰子图标")] public Sprite diceSprite; //骰子图标
    [Tooltip("骰子介绍")] public string info; //骰子介绍
    [Tooltip("骰子面数")] public List<int> diceFaceList;  //
    [Tooltip("骰子类型")] public List<Sprite> diceFaceSpriteList;  //
    //骰子面
    // public Sprite diceFaceImage1; //骰子面图片1
    // public Sprite diceFaceImage2; //骰子面图片2
    // public Sprite diceFaceImage3; //骰子面图片3
    // public Sprite diceFaceImage4; //骰子面图片4
    // public Sprite diceFaceImage5; //骰子面图片5
    // public Sprite diceFaceImage6; //骰子面图片6
}
