using System.Collections;
using System.Collections.Generic;
using UnityEngine;
// using DG.Tweening;
using TMPro;

public class zzzDamageFont : MonoBehaviour
{
    private TextMeshProUGUI text;
    private Rigidbody2D rb;

    private void Awake() {
        text = GetComponent<TextMeshProUGUI>();
        rb = GetComponent<Rigidbody2D>();
    }

    private void Start()
    {
        rb.velocity =  new Vector2(0,1);
        Destroy(this.gameObject,0.5f);
    }

    // public void Update() 
    // {
    //     transform.position = new (transform.position.x,transform.position.y + 0.025f,0);
    // }

    public void SetText(string strings, Color colors){
        text.text = strings;
        text.color = colors;
    }
    
}
