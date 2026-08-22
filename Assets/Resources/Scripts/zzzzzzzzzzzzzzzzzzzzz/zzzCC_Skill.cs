using System.Collections;
using System.Collections.Generic;
using DG.Tweening;
using UnityEngine;
using UnityEngine.UI;

public class zzzCC_Skill : MonoBehaviour
{
    // [HideInInspector] public SO_Skill SO_Skill_Data;   //技能SO数据
    // [HideInInspector] public  RuntimeAnimatorController runtimeAnimatorController;    //加载动画器即可
    // public float atk;   //攻击
    // public float mtk;   //灵伤
    // public int rank;    //位阶

    // [Tooltip("灵伤比率")] public float mtkRatio;
    // [Tooltip("治疗比率")] public float hpRatio;
    // [Tooltip("护盾比率")] public float dpRatio;
    // [Tooltip("攻击提升")] public float atkRatio;
    // [Tooltip("灵伤提升")] public float mtkURatio;
    // [Tooltip("释放次数")] public int releaseNum;
    // [Tooltip("目标数")] public int armNum;
    // [Tooltip("范围数")] public int area;

    // public float skillrate_damage;//技能伤害倍率
    // public float skillrate_shield;//技能护盾倍率
    // public float skillrate_treat;//技能治疗倍率
    // public float skillrate_attack;//技能提升攻击力倍率
    // public GameObject parterner;    //队友
    // public GameObject target;   //目标
    // public GameObject[] targets;   //全部目标
    // public GameObject CardsTimeline;   //时间轴
    // public Manager_FightCardTimeline Manager_FightCardTimeline;   //目标
    // //======特效协程模块参数======//
    // private int activeTweens = 0; // 正在执行的DoTween动画数量
    // private int activeAnimations = 0;// 正在执行的Animation动画数量
    // private CC_Skill usingSkill;//瞬发使用的技能脚本
    // //
    // [HideInInspector] public GameObject skill_TX_Prefab;     //技能特效预制体
    // [HideInInspector] public GameObject skill_TX_Missile_Prefab;     //技能特效投射物预制体
    // [HideInInspector] public bool isIgnoreMagic = false;// 响应骰子效果，无视蓝量放技能
    // [HideInInspector] public int IgnoreMagic_AddMagic;//无视蓝量释放后恢复蓝量
    // public void Awake()  //技能释放结束
    // {
    //     //在场景中寻找CardsTimeline这个物体
    //     CardsTimeline = GameObject.Find("CardsTimeline");
    //     //Debug.Log("技能释放结束");
    //     skill_TX_Prefab = Resources.Load<GameObject>("UI/TXPrefabs/Skill_TX_Prefab");
    //     skill_TX_Missile_Prefab = Resources.Load<GameObject>("UI/TXPrefabs/Skill_TX_Missile_Prefab");
    // }

    // ////// -----通用技能初始化方法----- //////
    
    // public virtual void Start()  //通用初始化
    // {
    //     InitialLoad();
    // }
    // public virtual void InitialLoad()  //加载技能数据
    // {
    //     //获取技能数据的路径, 通过技能脚本的类型名称来获取对应的SO_Skill数据
    //     string folder = "Skills";
    //     string scriptName = this.GetType().Name;
    //     string filePath_Skill = $"{folder}/{scriptName}";   //拼接技能SO路径
    //     string filePath_SkillAnimatior = $"{folder}/{scriptName}/{scriptName}_Animatior";   //拼接动画器路径

    //     //加载技能数据
    //     SO_Skill_Data = Resources.Load<SO_Skill>(filePath_Skill);
    //     // Debug.Log(SO_Skill_Data.name);

    //     //加载动画器
    //     runtimeAnimatorController = Resources.Load<RuntimeAnimatorController>(filePath_SkillAnimatior);
    //     // Debug.Log(runtimeAnimatorController.name);
    // }

    // public virtual void UseSkill()  //使用技能
    // {
    //     //子类来具体实现
    // }



    // public virtual void OnAnimationEnd() //部分技能效果结束后减少计数器
    // {

    // }

    // // public void SkillEnd()  //技能释放结束
    // // {
    // //     Manager_FightCardTimeline.GetComponent<Manager_FightCardTimeline>().SkillCompleted();
    // //     Debug.Log("技能释放结束");
    // // }
    
    
    // ////// -----  特效的一些公用方法  ----- //////
    
    //     public float GetBetweenDistance(GameObject targetA, GameObject targetB)      //获得两者之间的距离
    //     {
    //         float distance = Vector3.Distance(targetA.transform.position, targetB.transform.position);
    //         return distance;
    //     }
    //     public float GetFlightTime(float distance)    //获得飞行时间  
    //     {   //固定速度，近快远慢
    //         float basicSpeed = 1200f;//基准速度可调
    //         float time = distance / basicSpeed;
    //         return time;
    //     }
    
    // ////// -----  获取技能目标  ----- //////
    // /// 
    // //获取最近的队友   
    // public GameObject GetPartnerSingle()    //获取所有队友
    // {
    //     GameObject[] targets = GetTargets("hero", 0, 1, "all" ,1);
    //     GameObject target = targets[0];
    //     return target;
    // }

    // //获取队友总数
    // public int GetPartnerTotalNum()    
    // {
    //     GameObject[] targets = GetTargets("hero", 1, 0, "all" ,0);
    //     return targets.Length;
    // }

    // //根据行列值来寻找目标周围的对象
    // public GameObject[] GetAxisAllHero(string _axis)
    // {
    //     GameObject[] targets = GetTargets("hero", 0, 0, _axis, 0);
    //     // GameObject target = targets[0];
    //     return targets;
    // }
    
    // //获取生命值最低的队友
    // public GameObject GetPartnerHealth_Minimum(GameObject self)
    // {
    //     GameObject[] targets = GameObject.FindGameObjectsWithTag("PlayerCard");
    //     // 使用动态列表排除自身
    //     List<GameObject> excludeList = new List<GameObject>();
    //     foreach (GameObject obj in targets)
    //     {
    //         if (obj != self) excludeList.Add(obj);
    //     }

    //     //如果排除自身的列表为0相当于没有队友
    //     if (excludeList.Count <= 0) return null;

    //     //循环寻找最低生命值的队友
    //     GameObject _partner = null;
    //     float minHp = float.MaxValue;
    //     foreach (GameObject partner in excludeList)
    //     {
    //         float currentHp = partner.GetComponent<C_Damage>().hp;
    //         if (currentHp < minHp)
    //         {
    //             minHp = currentHp;//找到比自己还少的就赋值替代
    //             _partner = partner;
    //         }
    //     }
    //     return _partner;
    // }
    
    // //排除自身获取所有队友
    // public GameObject[] GetPartnerAll(GameObject self)
    // {
    //     GameObject[] partners = GameObject.FindGameObjectsWithTag("PlayerCard");
    //     // 使用动态列表排除自身
    //     List<GameObject> excludeList = new List<GameObject>();
    //     foreach (GameObject obj in partners)
    //     {
    //         if (obj != self) excludeList.Add(obj);
    //     }

    //     //如果List数量为0相当于只有自己没有友军
    //     if (excludeList.Count <= 0) return null;

    //     return excludeList.ToArray();
    // }
    
    // //排除自身获取num个随机的队友
    // public GameObject[] GetPartnerRandom_Exclude(int numRandom, GameObject self)
    // {
    //     GameObject[] targets = GameObject.FindGameObjectsWithTag("PlayerCard");
    //     // 使用动态列表排除自身
    //     List<GameObject> excludeList = new List<GameObject>();
    //     foreach (GameObject obj in targets)
    //     {
    //         if (obj != self) excludeList.Add(obj);
    //     }

    //     // 计算实际需要选择的数量
    //     int numToSelect = Mathf.Min(numRandom, excludeList.Count);//确保实际数量少于技能释放数量无误
    //     if (numToSelect <= 0) return null;//如果只有自身技能释放不了

    //     // 创建可用对象池并进行随机选择
    //     List<GameObject> available = new List<GameObject>(excludeList);
    //     GameObject[] targetsRandom = new GameObject[numToSelect];

    //     for (int i = 0; i < numToSelect; i++)
    //     {
    //         // 随机挑选并确保不重复
    //         int randomIndex = Random.Range(0, available.Count);
    //         targetsRandom[i] = available[randomIndex];
    //         available.RemoveAt(randomIndex);
    //     }
    //     return targetsRandom;
    // }
    
    // //不排除自身和获取num个随机的队友
    // public GameObject[] GetPartnerRandom_Include(int numRandom, GameObject self)
    // {
    //     // 获取所有 PlayerCard 标签的对象
    //     GameObject[] allTargets = GameObject.FindGameObjectsWithTag("PlayerCard");

    //     // 创建排除自身的队友列表
    //     List<GameObject> excludeList = new List<GameObject>();
    //     foreach (GameObject obj in allTargets)
    //     {
    //         if (obj != self)
    //             excludeList.Add(obj);
    //     }

    //     // 确定要选择的队友数量，最多 numRandom，最多不超过队友总数
    //     int numToSelect = Mathf.Min(numRandom, excludeList.Count);

    //     // 创建可用对象池并进行随机选择
    //     List<GameObject> available = new List<GameObject>(excludeList);
    //     List<GameObject> selected = new List<GameObject>();

    //     for (int i = 0; i < numToSelect && available.Count > 0; i++)
    //     {
    //         int randomIndex = Random.Range(0, available.Count);
    //         selected.Add(available[randomIndex]);
    //         available.RemoveAt(randomIndex);
    //     }

    //     // 构建最终结果数组：包含自身 + 随机选择的队友
    //     List<GameObject> result = new List<GameObject>
    // {
    //     self
    // };
    //     result.AddRange(selected);

    //     // 返回数组，确保长度在 [1, 3] 范围内
    //     return result.ToArray();
    // }

    // //排除自身获取轴向方向随机队友
    // public GameObject[] GetAxisPartnerRandom_Exclude(int numRandom, GameObject self, string axis)
    // {
    //     GameObject[] partners = GameObject.FindGameObjectsWithTag("PlayerCard");
        
    //     // 使用动态列表排除自身
    //     List<GameObject> excludeList = new List<GameObject>();
    //     foreach (GameObject obj in partners)
    //     {
    //         if (obj != self) excludeList.Add(obj);
    //     }
    //     if (excludeList.Count == 0) return null;
    //     List<GameObject> axisList = new List<GameObject>();
        
    //     //根据字符串区分行还是列方向
        
    //     if (axis == "x")//判断向量y为0
    //     {
    //         //循环计算向量判断
    //         foreach (GameObject partner in excludeList)
    //         {
    //             Vector2 v2 = partner.transform.position - gameObject.transform.position;
    //             if (v2.y == 0)
    //             {
    //                 axisList.Add(partner);
    //             }
    //         }
    //     }
    //     else if (axis == "y")//判断向量x为0
    //     {
    //         //循环计算向量判断
    //         foreach (GameObject partner in excludeList)
    //         {
    //             Vector2 v2 = partner.transform.position - gameObject.transform.position;
    //             if (v2.x == 0)
    //             {
    //                 axisList.Add(partner);
    //             }
    //         }
    //     }
    //     // 处理后拿到轴方向的队友列表
    //     int numToSelect = Mathf.Min(numRandom, axisList.Count);//确保实际数量少于技能释放数量无误
    //     if (numToSelect <= 0) return null;//如果只有自身技能释放不了

    //     // 复用并进行随机选择
    //     List<GameObject> available = axisList;
    //     GameObject[] partnersRandom = new GameObject[numToSelect];

    //     for (int i = 0; i < numToSelect; i++)
    //     {
    //         // 随机挑选并确保不重复
    //         int randomIndex = Random.Range(0, available.Count);
    //         partnersRandom[i] = available[randomIndex];
    //         available.RemoveAt(randomIndex);
    //     }
    //     return partnersRandom;
    // }
    // public GameObject GetTargetSingle()    //获取最近的目标
    // {
    //     string tag = "monster"; //队友标签
    //     string axis = "all"; //获取所有队友
    //     GameObject[] targets = GetTargets(tag, 0, 1, axis, 1);
    //     GameObject target = targets[0];
    //     return target;
    // }
    //     public GameObject[] GetTargetTotal()     //获取目标清单
    //     {
    //         // GameObject[] targets = GameObject.FindGameObjectsWithTag("GwCard");
    //         string tag = "monster"; //队友标签
    //         string axis = "all"; //获取所有队友
    //         GameObject[] targets = GetTargets(tag, 0, 0, axis ,0);
    //         return targets;
    //     }

    //     public int GetTargetTotalNum()     //获取怪物总数
    //     {
    //         GameObject[] targets = GameObject.FindGameObjectsWithTag("GwCard");
    //         return targets.Length;
    //     }
    //     public GameObject[] GetTargetRandom(int numRandom)//获取num个随机的敌方
    //     {
    //         GameObject[] targets = GameObject.FindGameObjectsWithTag("GwCard");
    //         //计算实际需要选择的数量
    //         int numToSelect = Mathf.Min(numRandom, targets.Length);//确保实际数量少于技能释放数量无误
    //         if (numToSelect <= 0) return null;//如果没有目标技能释放不了

    //         // 创建可用对象池并进行随机选择
    //         List<GameObject> available = new List<GameObject>(targets);
    //         GameObject[] targetsRandom = new GameObject[numToSelect];

    //         for (int i = 0; i < numToSelect; i++)
    //         {
    //             // 随机挑选并确保不重复
    //             int randomIndex = Random.Range(0, available.Count);
    //             targetsRandom[i] = available[randomIndex];
    //             available.RemoveAt(randomIndex);
    //         }
    //         return targetsRandom;
    //     }
        
    //     public GameObject[] GetTarget_Radius(int target_radius, GameObject target_origin)//根据行列值来寻找目标周围的对象[包括自身]
    // {
    //     GameObject[] targets = GameObject.FindGameObjectsWithTag("GwCard");
    //     //循环遍历行列值
    //     int target_row = target_origin.GetComponent<FightCard>().row;
    //     int target_column = target_origin.GetComponent<FightCard>().column;
    //     //总共距离
    //     int distance;
    //     List<GameObject> in_radius = new List<GameObject>();
    //     for (int i = 0; i < targets.Length; i++)
    //     {
    //         int _target_row = targets[i].GetComponent<FightCard>().row;
    //         int _target_column = targets[i].GetComponent<FightCard>().column;
    //         //计算距离
    //         distance = Mathf.Abs(_target_row - target_row) + Mathf.Abs(_target_column - target_column);
    //         if (distance <= target_radius)//包括自己
    //         {
    //             in_radius.Add(targets[i]);
    //         }
    //     }
    //     //将在范围内的对象列表转换成数组
    //     GameObject[] in_radius_targets = in_radius.ToArray();
    //     return in_radius_targets;
    // }

    // ////// 获取队友 - 获取 “hero”or“monster”，获取目标位置“all”or“x”or“y”，包含自己“1”or“0”，指定目标“数量”，
    // public GameObject[] GetTargets(string _tagtype, int _myself, int _num, string _axis, int _distance) 
    // {
    //     GameObject[] targets = new GameObject[0]; // 初始化目标数组

    //     if (_tagtype == "hero") { targets = GameObject.FindGameObjectsWithTag("PlayerCard"); }
    //     else if (_tagtype == "monster") { targets = GameObject.FindGameObjectsWithTag("GwCard"); }

    //     if (targets == null || targets.Length <= 0)
    //     {
    //         Debug.LogWarning("没有找到符合条件的目标");
    //         return null; // 如果没有找到目标，返回null
    //     }

    //     Debug.Log("获取目标数：" + targets.Length + "个");

    //     if (_axis == "x")//判断向量y为0
    //     {
    //         //循环计算向量判断
    //         List<GameObject> axisList = new List<GameObject>();
    //         foreach (GameObject target in targets)  //循环计算向量判断
    //         {
    //             Vector2 v0 = target.transform.position - this.transform.position;
    //             if (v0.y == 0)
    //             { axisList.Add(target); }
    //         }
    //         targets = axisList.ToArray();
    //     }
    //     else if (_axis == "y") //判断向量x为0
    //     {
    //         List<GameObject> axisList = new List<GameObject>();
    //         foreach (GameObject target in targets) //循环计算向量判断
    //         {
    //             Vector2 v0 = target.transform.position - this.transform.position;
    //             if (v0.x == 0)
    //             { axisList.Add(target); }
    //         }
    //         targets = axisList.ToArray();
    //     }

    //     // 包含自己？
    //     if (_myself == 1)
    //     {
    //         // 使用动态列表排除自身
    //         List<GameObject> excludeList = new List<GameObject>();
    //         foreach (GameObject obj in targets)
    //         { if (obj != this) excludeList.Add(obj); }
    //         targets = excludeList.ToArray();
    //     }
        
    //     // 寻找距离最近的目标
    //     if( _distance == 1)
    //     {
    //         float minDistance = 9999f;
    //         GameObject closestTarget = null;
    //         foreach (GameObject target in targets)
    //         {
    //             float distance = Vector3.Distance(this.transform.position, target.transform.position);
    //             if (distance < minDistance)
    //             {
    //                 minDistance = distance;
    //                 closestTarget = target;
    //             }
    //         }
    //         targets = new GameObject[] { closestTarget };
    //     }

    //     if (_num != 0 & _num < targets.Length)
    //     {
    //         // Convert array to list for removal
    //         List<GameObject> targetsList = new List<GameObject>(targets);
    //         for (int i = _num - 1; i > 0; i--)
    //         {
    //             if (targetsList.Count == 0) break;
    //             int x = Random.Range(0, targetsList.Count);
    //             if (targetsList.Count <= 0) break;
    //             targetsList.RemoveAt(x);
    //         }
    //         // // 如需更新物体位置（可选）
    //         // for (int i = 0; i < targetsList.Count; i++)
    //         // {
    //         //     targetsList[i].transform.position = new Vector3(i * 2, 0, 0);
    //         // }
    //         targets = targetsList.ToArray();
    //     }
    //     if (targets.Length <= 0)
    //     {
    //         Debug.LogWarning("没有找到符合条件的目标");
    //         return null; // 如果没有找到目标，返回null
    //     }
    //     Debug.Log("获取目标数：" + targets.Length + "个");
    //     // 返回Targets
    //     return targets;
    // }

    // //====== New === 飞行物的特效通用方法======//[协程+DoTween]
    // //一个目标攻击几次 //单个目标x次特效间延迟间隔，//伤害数值，//技能特效状态机控制器，//攻击几个目标 
    // public IEnumerator CreateTX_Missile(int singleCount, float delayBetween, float skill_TX_damage, RuntimeAnimatorController skillTX_AniController, params GameObject[] effectTargets)
    // {
    //     // 使用局部变量避免覆盖
    //     int localSingleCount = singleCount;
    //     float localDelayBetween = delayBetween;
    //     float localDamage = skill_TX_damage;
    //     RuntimeAnimatorController localController = skillTX_AniController;
    //     // Vector2 localSize = tx_Size;

    //     // 返回主协程
    //     return TX_Missile_Targets(localSingleCount, localDelayBetween, localDamage, localController, effectTargets);
    // }
    //     // 修改主协程接收所有参数
    // IEnumerator TX_Missile_Targets(int singleCount, float delayBetween, float skill_TX_damage, RuntimeAnimatorController skillTX_AniController, params GameObject[] effectTargets)
    // {
    //     int totalTarget = effectTargets.Length;
    //     var coroutines = new List<Coroutine>(totalTarget);

    //     // 使用局部变量避免覆盖
    //     int localSingleCount = singleCount;
    //     float localDelayBetween = delayBetween;
    //     float localDamage = skill_TX_damage;
    //     RuntimeAnimatorController localController = skillTX_AniController;
    //     // Vector2 localSize = tx_Size;

    //     // 对每个目标启动协程
    //     foreach (GameObject target in effectTargets)
    //     {
    //         coroutines.Add(StartCoroutine(TX_Missile_Single(target,
    //                                                     localSingleCount,
    //                                                     localDelayBetween,
    //                                                     localDamage,
    //                                                     localController)));
    //     }

    //     // 等待所有协程完成
    //     foreach (var coroutine in coroutines)
    //     {
    //         yield return coroutine;
    //     }
    //     // 这里不再有后续逻辑，只作为协程结束点
    // }
    //     // 子协程接收所有必要参数
    //     IEnumerator TX_Missile_Single(GameObject _target, int singleCount, float delayBetween, float skill_TX_damage, RuntimeAnimatorController skillTX_AniController)
    //     {
    //         // 使用局部变量避免覆盖
    //         int localSingleCount = singleCount;
    //         float localDelayBetween = delayBetween;
    //         float localDamage = skill_TX_damage;
    //         RuntimeAnimatorController localController = skillTX_AniController;
    //         // Vector2 localSize = tx_Size;

    //         Sequence sequence = DOTween.Sequence();

    //         for (int i = 0; i < localSingleCount; i++)
    //         {
    //             // 传递所有参数给配置方法
    //             sequence.AppendCallback(() => ConfigureSingleTX_Missle(
    //                 _target,
    //                 localDamage,
    //                 localController
    //                 // localSize
    //             ));
    //             activeTweens++; // 增加计数器

    //             if (i != localSingleCount - 1)
    //             {
    //                 sequence.AppendInterval(localDelayBetween);
    //             }
    //         }

    //         yield return new WaitUntil(() => activeTweens == 0);
    //     }
    //     private void ConfigureSingleTX_Missle(GameObject _target,
    //                                     float damage,
    //                                     RuntimeAnimatorController animController
    //                                 )
    //     {
    //         // 创建局部 Sequence 控制单个飞行物的动画
    //         Sequence childSequence = DOTween.Sequence();
    //         //  实例化特效
    //         GameObject tx = Instantiate(skill_TX_Missile_Prefab, gameObject.transform);
    //         tx.transform.position = gameObject.transform.position;
    //         //调整特效大小
    //         tx.GetComponent<RectTransform>().sizeDelta = new Vector2(120, 120);
    //         //给预制体分配对应属性
    //         tx.GetComponent<CC_Skill>().target = _target;
    //         // tx.GetComponent<CC_Skill>().damage = damage;
    //         tx.GetComponent<Animator>().runtimeAnimatorController = animController;
    //         // 调整角度
    //         Vector2 direction = _target.transform.position - tx.transform.position;
    //         float targetAngle = Mathf.Atan2(direction.y, direction.x) * Mathf.Rad2Deg;
    //         tx.transform.rotation = Quaternion.Euler(0, 0, targetAngle);

    //         tx.GetComponent<Animator>().SetTrigger("isAttacking");
    //         //  移动到目标
    //         float distance = GetBetweenDistance(gameObject, _target);// 计算移动距离和飞行时间
    //         float time = GetFlightTime(distance);
    //         Tween moveTween = tx.transform.DOMove(_target.transform.position, time)//由慢到快，较强加速感
    //             .SetEase(Ease.InCubic);
    //         childSequence.Append(moveTween);
    //         //  动画完成后减少计数器
    //         childSequence.OnComplete(() =>
    //         {
    //             activeTweens--;
    //             // 减少透明度
    //             tx.GetComponent<Image>().DOFade(0f, time / 3);
    //             // 让特效修改为结束状态
    //             tx.GetComponent<Animator>().SetTrigger("isAttacked");
    //         });
    //     }



    // //======飞行物的特效通用方法======//[协程+DoTween]
    // //一个目标攻击几次 //单个目标x次特效间延迟间隔，//伤害数值，//技能特效状态机控制器，//攻击几个目标 
    // // public IEnumerator CreateTX_Missile( int singleCount, float delayBetween, float skill_TX_damage, RuntimeAnimatorController skillTX_AniController, params GameObject[] effectTargets)
    // // {
    // //     // 使用局部变量避免覆盖
    // //     int localSingleCount = singleCount;
    // //     float localDelayBetween = delayBetween;
    // //     float localDamage = skill_TX_damage;
    // //     RuntimeAnimatorController localController = skillTX_AniController;
    // //     // Vector2 localSize = tx_Size;

    // //     // 返回主协程
    // //     return TX_Missile_Targets(localSingleCount, localDelayBetween, localDamage, localController, effectTargets);
    // // }
    // //     // 修改主协程接收所有参数
    // // IEnumerator TX_Missile_Targets(int singleCount, float delayBetween, float skill_TX_damage, RuntimeAnimatorController skillTX_AniController, params GameObject[] effectTargets)
    // // {
    // //     int totalTarget = effectTargets.Length;
    // //     var coroutines = new List<Coroutine>(totalTarget);

    // //     // 使用局部变量避免覆盖
    // //     int localSingleCount = singleCount;
    // //     float localDelayBetween = delayBetween;
    // //     float localDamage = skill_TX_damage;
    // //     RuntimeAnimatorController localController = skillTX_AniController;
    // //     // Vector2 localSize = tx_Size;

    // //     // 对每个目标启动协程
    // //     foreach (GameObject target in effectTargets)
    // //     {
    // //         coroutines.Add(StartCoroutine(TX_Missile_Single(target,
    // //                                                     localSingleCount,
    // //                                                     localDelayBetween,
    // //                                                     localDamage,
    // //                                                     localController)));
    // //     }

    // //     // 等待所有协程完成
    // //     foreach (var coroutine in coroutines)
    // //     {
    // //         yield return coroutine;
    // //     }
    // //     // 这里不再有后续逻辑，只作为协程结束点
    // // }
    // //     // 子协程接收所有必要参数
    // //     IEnumerator TX_Missile_Single(GameObject _target, int singleCount, float delayBetween, float skill_TX_damage, RuntimeAnimatorController skillTX_AniController)
    // //     {
    // //         // 使用局部变量避免覆盖
    // //         int localSingleCount = singleCount;
    // //         float localDelayBetween = delayBetween;
    // //         float localDamage = skill_TX_damage;
    // //         RuntimeAnimatorController localController = skillTX_AniController;
    // //         // Vector2 localSize = tx_Size;

    // //         Sequence sequence = DOTween.Sequence();

    // //         for (int i = 0; i < localSingleCount; i++)
    // //         {
    // //             // 传递所有参数给配置方法
    // //             sequence.AppendCallback(() => ConfigureSingleTX_Missle(
    // //                 _target,
    // //                 localDamage,
    // //                 localController
    // //                 // localSize
    // //             ));
    // //             activeTweens++; // 增加计数器

    // //             if (i != localSingleCount - 1)
    // //             {
    // //                 sequence.AppendInterval(localDelayBetween);
    // //             }
    // //         }

    // //         yield return new WaitUntil(() => activeTweens == 0);
    // //     }
    // //     private void ConfigureSingleTX_Missle(GameObject _target,
    // //                                     float damage,
    // //                                     RuntimeAnimatorController animController
    // //                                 )
    // //     {
    // //         // 创建局部 Sequence 控制单个飞行物的动画
    // //         Sequence childSequence = DOTween.Sequence();
    // //         //  实例化特效
    // //         GameObject tx = Instantiate(skill_TX_Missile_Prefab, gameObject.transform);
    // //         tx.transform.position = gameObject.transform.position;
    // //         //调整特效大小
    // //         tx.GetComponent<RectTransform>().sizeDelta = new Vector2(120, 120);
    // //         //给预制体分配对应属性
    // //         tx.GetComponent<CC_Skill>().target = _target;
    // //         tx.GetComponent<CC_Skill>().damage = damage;
    // //         tx.GetComponent<Animator>().runtimeAnimatorController = animController;
    // //         // 调整角度
    // //         Vector2 direction = _target.transform.position - tx.transform.position;
    // //         float targetAngle = Mathf.Atan2(direction.y, direction.x) * Mathf.Rad2Deg;
    // //         tx.transform.rotation = Quaternion.Euler(0, 0, targetAngle);

    // //         tx.GetComponent<Animator>().SetTrigger("isAttacking");
    // //         //  移动到目标
    //         // float distance = GetBetweenDistance(gameObject, _target);// 计算移动距离和飞行时间
    //         // float time = GetFlightTime(distance);
    // //         Tween moveTween = tx.transform.DOMove(_target.transform.position, time)//由慢到快，较强加速感
    // //             .SetEase(Ease.InCubic);
    // //         childSequence.Append(moveTween);
    // //         //  动画完成后减少计数器
    // //         childSequence.OnComplete(() =>
    // //         {
    // //             activeTweens--;
    // //             // 减少透明度
    // //             tx.GetComponent<Image>().DOFade(0f, time / 3);
    // //             // 让特效修改为结束状态
    // //             tx.GetComponent<Animator>().SetTrigger("isAttacked");
    // //         });
    // //     }
    // //======瞬发的特效通用方法======//[协程+Animation]
    // public IEnumerator CreateTX_Instant(int singleCount,//对单个目标x次特效 x 对
    // float delayBetween,//单个目标x次特效间延迟间隔
    //                                     float skill_TX_damage,//伤害数值
    //                                     RuntimeAnimatorController skillTX_AniController,//技能特效状态机控制器
    //                                     Vector2 tx_Size,//特效尺寸大小
    //                                     CC_Skill useSkill_Script,//要释放技能的技能脚本
    //                                     params GameObject[] effectTargets//技能释放的目标
    //                                     )
    // {
    //     // 使用局部变量避免覆盖
    //     int localSingleCount = singleCount;
    //     float localDelayBetween = delayBetween;
    //     float localDamage = skill_TX_damage;
    //     RuntimeAnimatorController localController = skillTX_AniController;
    //     Vector2 localSize = tx_Size;
    //     //技能脚本赋值[只有一个技能释放]
    //     usingSkill = useSkill_Script;
    //     // 返回主协程
    //     return TX_Instant_Targets(localSingleCount,localDelayBetween,localDamage,localController,localSize,effectTargets);
    // }
    //     // 修改主协程接收所有参数
    //     IEnumerator TX_Instant_Targets(int singleCount,float delayBetween,float skill_TX_damage,RuntimeAnimatorController skillTX_AniController,Vector2 tx_Size,params GameObject[] effectTargets)
    //     {
    //         int totalTarget = effectTargets.Length;
    //         var coroutines = new List<Coroutine>(totalTarget);
    //         // 使用局部变量存储参数
    //         int localSingleCount = singleCount;
    //         float localDelayBetween = delayBetween;
    //         float localDamage = skill_TX_damage;
    //         RuntimeAnimatorController localController = skillTX_AniController;
    //         Vector2 localSize = tx_Size;
    //         // 对每个目标启动协程
    //         foreach (GameObject target in effectTargets)
    //         {
    //             coroutines.Add(StartCoroutine(TX_Instant_Single(target,localSingleCount,localDelayBetween,localDamage,localController,localSize)));
    //         }
    //         // 等待所有协程完成
    //         foreach (var coroutine in coroutines)
    //         {
    //             yield return coroutine;
    //         }
    //     }
    //     // 子协程接收所有必要参数
    //     IEnumerator TX_Instant_Single(GameObject _target,int singleCount,float delayBetween,float skill_TX_damage,RuntimeAnimatorController skillTX_AniController,Vector2 tx_Size)
    //     {
    //         // 使用局部变量
    //         int localSingleCount = singleCount;
    //         float localDelayBetween = delayBetween;
    //         float localDamage = skill_TX_damage;
    //         RuntimeAnimatorController localController = skillTX_AniController;
    //         Vector2 localSize = tx_Size;
    //         //启用序列
    //         Sequence sequence = DOTween.Sequence();
    //         for (int i = 0; i < localSingleCount; i++)
    //         {
    //             // 传递所有参数给配置方法
    //             sequence.AppendCallback(() => ConfigureSingleTX_Instant(
    //                 _target,
    //                 localDamage,
    //                 localController,
    //                 localSize
    //             ));
    //             activeAnimations++; // 增加计数器

    //             if (i != localSingleCount - 1)
    //             {
    //                 sequence.AppendInterval(localDelayBetween);
    //             }
    //         }

    //         yield return new WaitUntil(() => activeAnimations == 0);
    //     }
    //     private void ConfigureSingleTX_Instant(GameObject _target,
    //                                     float damage,
    //                                     RuntimeAnimatorController animController,
    //                                     Vector2 size)
    //     {
    //         //  实例化特效
    //         GameObject tx = Instantiate(skill_TX_Missile_Prefab, gameObject.transform);
    //         tx.transform.position = gameObject.transform.position;
    //         //调整特效大小
    //         tx.GetComponent<RectTransform>().sizeDelta = size;
    //         //给预制体分配对应属性
    //         tx.GetComponent<CC_Skill>().target = _target;
    //         // tx.GetComponent<CC_Skill>().damage = damage;
    //         tx.GetComponent<SkillTX_UIManager>().skill_script = usingSkill;
    //         tx.GetComponent<Animator>().runtimeAnimatorController = animController;
    //         // 调整角度
    //     }
    //     //======通用特效完成通知协程方法======//
    //     public IEnumerator WaitAllTXCompleted(List<Coroutine> allTXoroutines, GameObject self)//传入特效组列表
    //     {
    //         foreach (var coroutine in allTXoroutines)
    //         {
    //             yield return coroutine;
    //         }
    //         // 所有动画完成后继续执行
    //         Debug.Log("特效完成！！！，使用的对象为：" + self.name);

    //         // 在这里执行后续逻辑
    //         if (isIgnoreMagic)
    //         {
    //             self.GetComponent<C_Damage>().SumMana(IgnoreMagic_AddMagic);
    //             self.GetComponent<FightCard>().Ability();
    //             isIgnoreMagic = false;
    //         }
    //         else
    //         {
    //             self.GetComponent<FightCard>().NotifyActionCompleted();
    //         }
    //     }
    //     //======动画事件回调（由 Animation Event 触发）「只有用animation动画方式需要这个」======//
    //     public void ActionSkillEffect()
    //     {
    //         //  动画完成后减少计数器
    //         activeAnimations--;
    //     }
        //======特效动画的一些通用方法======//
        // //飞行物的特效通用方法
        // public void CreateTX_Missile(int singleCount,//对单个目标x次特效 x 对 1
        //                              float delayBetween,//单个目标x次特效间延迟间隔
        //                              float skill_TX_damage,
        //                              RuntimeAnimatorController skillTX_AniController,//技能特效状态极控制器
        //                              Vector2 tx_Size,//特效尺寸大小
        //                              params GameObject[] effectTargets)
        // {
        //     //赋值特效
        //     SingleCount = singleCount;
        //     DelayBetween = delayBetween;
        //     Skill_TX_damage = skill_TX_damage;
        //     SkillTX_AniController = skillTX_AniController;
        //     TX_Size = tx_Size;
        //     //调用主协程
        //     StartCoroutine(TX_Missile_Targets(effectTargets));
        // }
        // //配套主协程
        // IEnumerator TX_Missile_Targets(params GameObject[] effectTargets)
        // {
        //     int totalTarget = effectTargets.Length;//对这些目标
        //     var coroutines = new List<Coroutine>(totalTarget);
        //     //对每个目标启动协程
        //     foreach (GameObject target in effectTargets)
        //     {
        //         coroutines.Add(StartCoroutine(TX_Missile_Single(target)));
        //     }
        //     //等待所有协程完成
        //     foreach (var coroutine in coroutines)
        //     {
        //         yield return coroutine;
        //     }
        //     // 所有动画完成后继续执行
        //     Debug.Log("所有动画播放完毕，继续主逻辑");
        //     // 后续代码...
        //     if (isIgnoreMagic == true)
        //     {
        //         //不用回调，只需要回蓝然后再询问
        //         //获得蓝量
        //         gameObject.GetComponent<C_Damage>().SumMana(IgnoreMagic_AddMagic);
        //         //执行完检查是否满蓝，满蓝就放技能
        //         gameObject.GetComponent<FightCard>().Ability();
        //         isIgnoreMagic = false;//无视触发完毕
        //     }
        //     else
        //     {
        //         gameObject.GetComponent<FightCard>().NotifyActionCompleted();   //发布动作完成通知
        //     }
        // }
        // //子协程，处理单个目标特效
        // IEnumerator TX_Missile_Single(GameObject _target)
        // {
        //     //主动画序列
        //     Sequence sequence = DOTween.Sequence();

        //     //循环添加技能动画动作
        //     for (int i = 0; i < SingleCount; i++)
        //     {
        //         // 触发单个飞行物的动画
        //         sequence.AppendCallback(() => ConfigureSingleTX_Missle(_target));
        //         activeTweens++; // 增加计数器

        //         //  添加间隔[最后一个不用加]
        //         if (i != SingleCount - 1)
        //         {
        //             sequence.AppendInterval(DelayBetween);
        //         }
        //     }
        //     //等待所有动画执行完毕
        //     yield return new WaitUntil(() => activeTweens == 0);
        // }
        // //配置单个飞行物特效参数//
        // private void ConfigureSingleTX_Missle(GameObject _target)
        // {
        //     // 创建局部 Sequence 控制单个飞行物的动画
        //     Sequence childSequence = DOTween.Sequence();
        //     //  实例化特效
        //     GameObject tx = Instantiate(skill_TX_Missile_Prefab, gameObject.transform);
        //     tx.transform.position = gameObject.transform.position;
        //     //调整特效大小
        //     tx.GetComponent<RectTransform>().sizeDelta = TX_Size;
        //     //给预制体分配对应属性
        //     tx.GetComponent<CC_Skill>().target = _target;
        //     tx.GetComponent<CC_Skill>().damage = Skill_TX_damage;
        //     tx.GetComponent<Animator>().runtimeAnimatorController = SkillTX_AniController;
        //     // 调整角度
        //     Vector2 direction = _target.transform.position - tx.transform.position;
        //     float targetAngle = Mathf.Atan2(direction.y, direction.x) * Mathf.Rad2Deg;
        //     tx.transform.rotation = Quaternion.Euler(0, 0, targetAngle);
        //     // Vector2 direction = target.transform.position - tx.transform.position;
        //     // float targetAngle = Mathf.Atan2(direction.y, direction.x) * Mathf.Rad2Deg - 90f;
        //     // Tween rotateTween = tx.transform.DORotate(new Vector3(0, 0, targetAngle), moveDuration / 5)
        //     //  .SetEase(Ease.InOutSine);
        //     // childSequence.Append(rotateTween);
        //     // 让特效修改为飞行动画状态
        //     tx.GetComponent<Animator>().SetTrigger("isAttacking");
        //     //  移动到目标
        //     float distance = GetBetweenDistance(gameObject, _target);// 计算移动距离和飞行时间
        //     float time = GetFlightTime(distance);
        //     Tween moveTween = tx.transform.DOMove(_target.transform.position, time)//由慢到快，较强加速感
        //         .SetEase(Ease.InCubic);
        //     childSequence.Append(moveTween);
        //     //  动画完成后减少计数器
        //     childSequence.OnComplete(() =>
        //     {
        //         activeTweens--;
        //         // 减少透明度
        //         tx.GetComponent<Image>().DOFade(0f, time / 3);
        //         // 让特效修改为结束状态
        //         tx.GetComponent<Animator>().SetTrigger("isAttacked");
        //     });
        // }
}