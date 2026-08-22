using System.Collections;
using UnityEngine;
using UnityEngine.Networking;

// public class AssetBundleLoader : MonoBehaviour
// {
//     //这个功能暂时没有用
    
//     private string assetBundleUrl = "http://yourserver.com/AssetBundles/yourassetbundle"; // 替换为实际的 AssetBundle URL

//     void Start()
//     {
//         StartCoroutine(DownloadAndCacheAssetBundle(assetBundleUrl));
//     }

//     IEnumerator DownloadAndCacheAssetBundle(string url)
//     {
//         // 创建 UnityWebRequest 并下载 AssetBundle
//         using (UnityWebRequest uwr = UnityWebRequestAssetBundle.GetAssetBundle(url))
//         {
//             yield return uwr.SendWebRequest();

//             if (uwr.result != UnityWebRequest.Result.Success)
//             {
//                 Debug.LogError(uwr.error);
//             }
//             else
//             {
//                 AssetBundle bundle = DownloadHandlerAssetBundle.GetContent(uwr);
//                 if (bundle != null)
//                 {
//                     // 加载 AssetBundle 内的一个资源示例
//                     GameObject prefab = bundle.LoadAsset<GameObject>("YourPrefabName");
//                     if (prefab != null)
//                     {
//                         Instantiate(prefab);
//                     }
//                     else
//                     {
//                         Debug.LogError("Failed to load asset from AssetBundle");
//                     }

//                     // 卸载 AssetBundle，保留已加载的资产
//                     bundle.Unload(false);
//                 }
//                 else
//                 {
//                     Debug.LogError("Failed to download AssetBundle");
//                 }
//             }
//         }
//     }
// }
