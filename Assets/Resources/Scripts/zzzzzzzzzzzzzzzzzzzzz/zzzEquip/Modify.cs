using UnityEngine;

public class Modify : MonoBehaviour
{
    //获取初始化组件:
    [Tooltip("设定武器OS数据")] public SO_Equip modify_SO_Data;
    private Transform weapon;
    // private Transform player;
    // private Rigidbody2D rigidBody;

    protected virtual void Start() //测试使用。通过UI触发时无需碰撞。
    {
        GetComponent<Rigidbody2D>();
    }

    // private void OnTriggerEnter2D(Collider2D other) //测试使用。暂时使用碰撞的方式，来安装
    // {
    //     if (other.gameObject.layer == LayerMask.NameToLayer("Player")) //判断是否是角色
    //     {
    //         other.GetComponent<CC_Player>().ModifyAdd(gameObject);
    //     }
    // }

    public void SetParent()
    {
        weapon = transform.parent;
    }

    public void Data_DeviceToWeapon() //数据传递。将改件的属性加到武器上
    {
        // weapon.gameObject.GetComponent<zzzzCC_Attack>().atkCont += modify_SO_Data.atkCont;
        // weapon.gameObject.GetComponent<zzzzCC_Attack>().atkDivide += modify_SO_Data.atkDivide;
        // weapon.gameObject.GetComponent<zzzzCC_Attack>().atkPierce += modify_SO_Data.atkPierce;
        // weapon.gameObject.GetComponent<zzzzCC_Attack>().atkCrit += modify_SO_Data.atkCrit;
        // weapon.gameObject.GetComponent<zzzzCC_Attack>().atkCritDamage += modify_SO_Data.atkCritDamage;
        // weapon.gameObject.GetComponent<zzzzCC_Attack>().bullet += modify_SO_Data.bullet;
        // weapon.gameObject.GetComponent<zzzzCC_Attack>().atkPlus += modify_SO_Data.atkPlus;
        // weapon.gameObject.GetComponent<zzzzCC_Attack>().bulletGapPlus += modify_SO_Data.bulletGapPlus;
    }
}