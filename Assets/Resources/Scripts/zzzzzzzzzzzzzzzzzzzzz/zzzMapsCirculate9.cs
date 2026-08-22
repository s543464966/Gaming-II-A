using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class zzzMapsCirculate : MonoBehaviour
{
    public GameObject maincamera;
    float groundwidth = 20.48f;
    float mapwidth;
    int groundnum = 3;
    
    // Start is called before the first frame update
    void Start()
    {
        mapwidth = groundnum * groundwidth;
    }

    // Update is called once per frame
    void Update()
    {
        Vector3 groundposition = transform.position;
        if(maincamera.transform.position.x > transform.position.x + mapwidth / 2 )
        {
            groundposition.x += mapwidth;
            transform.position = groundposition;
        }
        else if (maincamera.transform.position.x < transform.position.x - mapwidth / 2 )
        {
         groundposition.x -= mapwidth;
            transform.position = groundposition;
        }
        if(maincamera.transform.position.y > transform.position.y + mapwidth / 2 )
        {
            groundposition.y += mapwidth;
            transform.position = groundposition;
        }
        else if (maincamera.transform.position.y < transform.position.y - mapwidth / 2 )
        {
         groundposition.y -= mapwidth;
            transform.position = groundposition;
        }
    }
}
