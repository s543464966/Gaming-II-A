// using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class LevelNode//每个小关卡Node类属性
{
    //逻辑位置信息
    public int Level;//关卡所在的等级
    public int Index;//关卡所在该等级中的索引位置
    //逻辑状态
    public bool Islinked = false;//自身是否被上一级连接
    public bool Islinking = false;//自身是否连接下一级
    public bool IsActivated = true;//用于UI显示 是否激活[默认都为激活]

    //此关卡被分配要连接下一级关卡的列表
    public List<LevelNode> ConnectNextNodes = new List<LevelNode>();
    //先用字符串来替代关卡SO
    public string levelType;
    
    //对应关卡地图里的UI对象
    public GameObject UI_Instance;
    //关卡种类ScriptObject
    
}
