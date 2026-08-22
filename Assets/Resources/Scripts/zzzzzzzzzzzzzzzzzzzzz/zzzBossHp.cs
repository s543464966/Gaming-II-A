using UnityEngine;

public class zzzBossHp: MonoBehaviour //接口
{
    private GameObject canvas;

    private void Awake() {
        canvas = GameObject.Find("BossHpBG/BossHpRed");
    }

    public void SetHP(Vector3 _length)
    {
        canvas.GetComponent<RectTransform>().localScale = _length;
    }
}
