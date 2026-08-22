using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

public class Playing_UIManager : MonoBehaviour
{
    // Start is called before the first frame update
    //用于暂停的布尔值
    private bool isPause = false;
    //引用暂停界面卡片的对象
    public GameObject pausePanelCard;
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    public void OnPauseButton()
    {
        isPause = !isPause;//取反操作
        pausePanelCard.SetActive(isPause);//实现正常点击开关
    }

    public void OnBackMainButton()
    {
        SceneManager.LoadScene("Main interface");
    }
}
