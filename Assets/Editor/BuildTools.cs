using UnityEngine;
using System;

// https://bytedance.larkoffice.com/docx/P9QzddFVWodj7rxoJ5WcObDknac
public class BuildTools
{
    public static void Build()
    {
        // var starkBuilderSettings = StarkSDKTool.StarkBuilderSettings.Instance;
        StarkSDKTool.API.BuildManager.Build(StarkSDKTool.Framework.Wasm);

        var uid = "257725607977913";
        var appid = "tt7d7d0bc0e24e245707";
        StarkSDKTool.RequestVersionResult requestVersionResult;

        requestVersionResult = StarkSDKTool.API.PublishManager.RequestVersion(uid, appid);
        Version version = new Version(requestVersionResult.LatestVersion);
        version = new Version(version.Major, version.Minor, version.Build + 1);
        Debug.Log(StarkSDKTool.StarkBuilderSettings.Instance.version);
        StarkSDKTool.API.PublishManager.PublishAndroidWebGLWithIOS(uid, appid, version.ToString(), StarkSDKTool.StarkBuilderSettings.Instance.webglPackagePath);
        StarkSDKTool.API.PublishManager.MakeQRCode(uid, appid);
    }
}
