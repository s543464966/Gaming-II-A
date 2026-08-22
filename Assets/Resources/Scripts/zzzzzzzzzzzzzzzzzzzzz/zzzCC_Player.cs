
using System.Collections;
using System.Net;
using UnityEngine;
using UnityEngine.SceneManagement;

//处理中心：玩家操控角色相关的交互中心：包括：角色移动，各类装备拆卸

public class zzzCC_Player : MonoBehaviour
{
    private float moveSpeed = 4f; // 设定当前的移动方向
    // private float moveSpeedImprove = 1f;
    private Vector2 moveDirection; // 存储当前的移动方向
    private Rigidbody2D rb;
    private Vector2 moveInput;

    [Tooltip("获取用于切换的Weapon")]
    // public GameObject[] Weapon;//Weapon切换
    private int WeaponNum;//Weapon切换，记录当前Weapon
    public GameObject device;//Weapon切换

    // private int hp;

    Animator animator;
    SpriteRenderer spriteRenderer;

    private void Awake()
    {
        rb = GetComponent<Rigidbody2D>();
        animator = GetComponent<Animator>();
        spriteRenderer = GetComponent<SpriteRenderer>();
        // Weapon[0].SetActive(true);  //Weapon切换，激活默认Weapon
    }
        
    void FixedUpdate()
    {
        // 施加速度并移动角色
        if (Input.touchCount > 0) 
        {
            Touch touch = Input.GetTouch(0);
            moveDirection = touch.deltaPosition.normalized * -1f;
        } 
        else 
        {
            // 获取用户输入
            float horizontalInput = Input.GetAxis("Horizontal");
            float verticalInput = Input.GetAxis("Vertical");

            // 计算移动方向并Normal化
            moveDirection = new Vector2(horizontalInput, verticalInput).normalized;
        }
        MoveCharacter(moveDirection); //操控移动
    }

    void MoveCharacter(Vector2 moveDirection) //操控移动
    {
        Vector2 currentPosition = transform.position; //获取当前位置
        Vector2 newPosition = currentPosition + moveDirection * moveSpeed * Time.deltaTime; //计算新的位置
        transform.position = newPosition; //移动角色
    }

    public void ModifyAdd(GameObject _modify) 
    {
        Component CC_Attack = transform.GetComponentInChildren<zzzzCC_Attack>(); //寻找角色的子物：武器
        if(CC_Attack != null){
            _modify.transform.SetParent(CC_Attack.gameObject.transform); //改件变为武器的子物体
            _modify.GetComponent<Collider2D>().isTrigger = false;  //临时测试，关闭碰撞
            _modify.GetComponent<Modify>().SetParent(); //改件需要同步父物体Weapon和祖父物体Player
            _modify.GetComponent<Modify>().Data_DeviceToWeapon(); //改件的属性数值加到武器上
        }
    }

    public void StarmanaAdd(GameObject _starmanaPick) 
    {
        Component weapon = transform.GetComponentInChildren<zzzzCC_Attack>(); //寻找角色的子物：武器
        if (weapon != null){
            _starmanaPick.transform.SetParent(weapon.gameObject.transform); //改件变为武器的子物体
            _starmanaPick.GetComponent<Collider2D>().isTrigger = false;  //临时测试，关闭碰撞
            // _starmanaPick.GetComponent<FightStarmana>().StarmanaNum();
        }

    }

    void OnFire(){
        animator.SetTrigger("swordAttack");
    }

    void OnDamage(){
        animator.SetTrigger("isDamage");
    }

    void OnDie(){
        animator.SetTrigger("isDead");
    }

    
    private void OnDestroy(){
        Destroy(gameObject);
    }

//在这里选择并触发对应的技能
    public void EndtoStar()
    {
        SceneManager.LoadScene(SceneManager.GetActiveScene().name);
    }

    // public void SkillPick(SO_Skill _SO_Skill)   ////////  【接受】!!!这里控制星能之力的使用!!!
    // {
    //     SO_Skill s = _SO_Skill;
    //     switch (_SO_Skill.skillId)
    //     {
    //         //基础星能
    //         case 0: StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama0(); break;
    //         // case 1: StarmanaAdd(s.skillUse); weapon.GetComponent<Weapon>().Starmama1(); break;
    //         // case 2: StarmanaAdd(s.skillUse); weapon.GetComponent<Weapon>().Starmama2(); break;
    //         // case 3: StarmanaAdd(s.skillUse); weapon.GetComponent<Weapon>().Starmama3(); break;
    //         // case 4: weapon.GetComponent<Weapon>().Starmama1(); break;
    //         // case 5: weapon.GetComponent<Weapon>().Starmama1(); break;
    //         // case 6: weapon.GetComponent<Weapon>().Starmama1(); break;
    //         case 7: starmana += _SO_Skill.skillUse; break;

    //         //岩系
    //         case 101: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama101();} else StarmanaLow(); break;
    //         case 102: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama102(s.starmanabullet);} else StarmanaLow(); break;
    //         case 103: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama103(s.starmanaGuarder);} else StarmanaLow(); break;
    //         case 1001: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama1001(s.starmanaEffect);} else StarmanaLow(); break;
    //         case 1002: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama1002(s.starmanaOnOff);} else StarmanaLow(); break;
    //         case 10003: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama10003(s.starmanaGuarder);} else StarmanaLow(); break;

    //         //火系
    //         case 201: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama201();} else StarmanaLow(); break;
    //         case 202: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama202(s.starmanaGuarder);} else StarmanaLow(); break;
    //         case 203: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama203(s.starmanabullet);} else StarmanaLow(); break;
    //         case 2001: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama2001(s.starmanaEffect);} else StarmanaLow(); break;
    //         case 20001: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama20001(s.starmanabullet);} else StarmanaLow(); break;
        
        
    //         //风系
    //         case 301: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama301();} else StarmanaLow(); break;
    //         case 302: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama302();} else StarmanaLow(); break;
    //         case 304: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama304(s.starmanabullet);} else StarmanaLow(); break;
    //         case 305: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama305(s.starmanaEffect);} else StarmanaLow(); break;
    //         case 3001: if(starmana >= Mathf.Abs(s.skillUse)) {StarmanaAdd(s.skillUse); weapon.GetComponent<CC_Attack>().Starmama3001();} else StarmanaLow(); break;
            
    //         //为空
    //         default: Debug.Log("空，没有对应的星能!") ; break;
    //     }
    //     Debug.Log("当前剩余星能：" + starmana);
    //     RecoveryList.Add(s.skillId);    // 已使用过的卡组，在这里回收
    // }
}