using System.Collections;
using System.Collections.Generic;
using System.Reflection;
using TMPro;
using Unity.Mathematics;
using Unity.VisualScripting;
using UnityEngine;

public class BulletRflec : MonoBehaviour
{
    [Tooltip("子弹飞行速度")]
    public float fadeSpeed;

    private LineRenderer line;

    private float alpha;


    void Awake()
    {
        line = GetComponent<LineRenderer>();
        alpha = line.endColor.a;
    }

    public void OnEnable() {
        line.endColor = new Color(line.endColor.r,line.endColor.g,line.endColor.b,line.endColor.a);
        StartCoroutine(Fade());
    }

    IEnumerator Fade()
    {
        while(line.endColor.a>0)
        {
            line.endColor = new Color(line.endColor.r,line.endColor.g,line.endColor.b,line.endColor.a-fadeSpeed);
            yield return new WaitForFixedUpdate();
        }
        Destroy(gameObject);
    }
}
