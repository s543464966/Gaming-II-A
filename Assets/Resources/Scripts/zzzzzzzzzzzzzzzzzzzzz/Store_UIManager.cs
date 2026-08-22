using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;
public class Store_UIManager : MonoBehaviour
{
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    public void OnFightButton()//跳转Fight场景
    {
        SceneManager.LoadScene("Main interface");
    }

    public void OnEquipButton()//跳转Equip场景
    {
        SceneManager.LoadScene("Equip");
    }

    public void OnStudyButton()//跳转Study场景
    {
        SceneManager.LoadScene("Study");
    }
}
