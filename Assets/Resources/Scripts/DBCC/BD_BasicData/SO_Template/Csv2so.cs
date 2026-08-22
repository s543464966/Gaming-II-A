#if UNITY_EDITOR
using UnityEngine;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor;
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Linq;

public class Csv2so : IPreprocessBuildWithReport, IPostprocessBuildWithReport
{
    public int callbackOrder { get { return 0; } }
    private List<TextAsset> csvFiles = new List<TextAsset>(); //csv文件资源列表
    private Dictionary<string, int> csvFieldIndexTable; //csv字段索引表
    private string[] rows; //csv行数据
    private TextAsset csvFile;  //csv文件资源
    private string saveDir_SO; //保存SO的文件夹路径
    private string loadPath_Asset; //资源加载路径
    private string loadRelativePath_Asset; //资源加载相对路径
    private Type soType; //SO类型
    private string soAssetName; //SO资源文件的名称
    //  拼接中心多单元格拼接时所用的分隔符
    private const string CELL_SEP = "\u001F"; // 单元格分隔符（Unit Separator）

    public void Factory_SaveCsv2SO()
    {
        //======csv切卡牌SO======//

        // 获取所有csv文件资源
        Factory_GetCsvFiles();
        // 遍历每个csv文件-->一个一个文件处理
        foreach (var csvFile in csvFiles)
        {
            Debug.Log("正在处理"+csvFile.name);
            // 预处理csv文件
            Factory_PreprocessCsvFile(csvFile);
            //  重置相关参数    
            soType = null;  //一种csv对应一种so类型
            // 开始解析csv文件内容
            for (var r = 3; r < rows.Length; r++)   //读取规定的起始的数据位置第四行
            {
                string[] columns = ParseCsvRow(rows[r]); //以逗号分割每一列，处理带逗号的字段
                // 如果整行为空或解析结果长度为0，则提前跳过
                if (columns == null || columns.Length == 0 || string.IsNullOrEmpty(columns[0]))
                {
                    Debug.Log("[Csv2SO] 空行或首列为空，提前退出行循环: r=" + r);
                    break;
                }
                //读取存储路径
                if (columns[0].StartsWith("Assets/"))  //判断是否为Asset/开头的单元格
                {
                    saveDir_SO = columns[0].Trim();   //保存路径
                    Factory_ClearOldAssets(saveDir_SO);// 判断保存资源文件夹是否存在，同时需要清空旧资源
                    if (soType == null)  //一种csv对应一种so类型
                    {
                        soType = Type.GetType(columns[1]); //获取要创建的SO类型
                        Debug.Log("so对应类型被赋予!"+soType.Name);
                    }
                    continue;
                }
                //创建SO实例
                var newSOAsset = ScriptableObject.CreateInstance(soType);
                soAssetName = columns[0];   //SO资源文件的名称用第一列的id命名
                //为目标SO的每个字段进行区分赋excel的数值
                foreach (var field in soType.GetFields())
                {
                    if (!csvFieldIndexTable.ContainsKey(field.Name)) continue;

                    if (columns[csvFieldIndexTable[field.Name]].Equals("")) continue;//单元格值为空跳过
                    //  判断每个值是否是需要进行加工的符号
                    string value = columns[csvFieldIndexTable[field.Name]];
                    value = Factory_ProcessCenter(columns,csvFieldIndexTable[field.Name],field);
                    // 根据字段类型赋值
                    Factory_AssignFieldValue(newSOAsset, field, value);
                }
                //  将该SO实例保存
                AssetDatabase.CreateAsset(newSOAsset, saveDir_SO + "/" + soAssetName + ".asset");
            }
            Debug.Log("处理完毕"+csvFile.name);
        }
        //  保存资产数据库
        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();

        // 定位到 Assets/Resources/Build 目录

        // var readCsvPath = Directory.GetCurrentDirectory() + "\\Assets\\Resources\\Build";//csv文件路径
        // DirectoryInfo dir = new DirectoryInfo(readCsvPath);
        // FileInfo[] files = dir.GetFiles();
        // foreach (FileInfo file in files)    //找到csv文件
        // {
        //     if (!file.Name.EndsWith(".csv")) continue;   //跳过非csv文件

        //     csvFile = Resources.Load<TextAsset>("Build/" + Path.GetFileNameWithoutExtension(file.Name));    //加载csv文件

        //     //开始解析csv文件内容
        //     var rows = csvFile.text.Split('\n');    //以行分割
        //     //分割第一行为列作为字段名
        //     var keys = rows[0].Split(',');
        //     //构建字段名与列索引的映射字典
        //     var dic = new Dictionary<string, int>();
        //     for (var index = 0; index < keys.Length; index++)
        //     {
        //         dic[keys[index]] = index;
        //     }
        //     //遍历每一行数据
        //     for (var r = 3; r < rows.Length; r++)   //读取规定的起始的数据位置第四行
        //     {
        //         string[] columns = rows[r].Split(',');  //以逗号分割每一列
        //         //空行退出
        //         if (columns[0].Equals("")) break;
        //         //读取存储路径
        //         if (columns[0].StartsWith("Assets/"))  //判断是否为Asset/开头的单元格
        //         {
        //             savePath_SO = columns[0];   //保存路径
        //             soType = Type.GetType(columns[1]); //获取要创建的SO类型
        //             continue;
        //         }
        //         //创建SO实例
        //         var newWordAsset = ScriptableObject.CreateInstance(soType);

        //         //为目标SO的每个字段进行区分赋excel的数值
        //         foreach (var field in soType.GetFields())
        //         {
        //             if (!dic.ContainsKey(field.Name))
        //                 continue;
        //             if (columns[dic[field.Name]].Equals(""))    //单元格值为空跳过
        //                 continue;
        //             // 根据字段类型赋值
        //             if (field.FieldType == typeof(string))
        //                 field.SetValue(newWordAsset, columns[dic[field.Name]]);
        //             else if (field.FieldType.BaseType == typeof(UnityEngine.Object))
        //                 field.SetValue(newWordAsset, AssetDatabase.LoadAssetAtPath(columns[dic[field.Name]], field.FieldType));
        //             else
        //                 field.SetValue(newWordAsset, field.FieldType.GetMethod("Parse", new Type[] { typeof(string) }).Invoke(null, new string[] { columns[dic[field.Name]] }));
        //         }
        //         //  将该SO实例保存
        //         AssetDatabase.CreateAsset(newWordAsset, assetPath + "/" + columns[0] + ".asset");
        //     }
        // }
    }
    // 模块：获取所有csv文件原材料
    private void Factory_GetCsvFiles()
    {
        var readCsvPath = Directory.GetCurrentDirectory() + "/Assets/Resources/Build";//csv文件路径
        DirectoryInfo dir = new DirectoryInfo(readCsvPath);
        FileInfo[] files = dir.GetFiles();  //只会获取该目录下的文件，不包含子文件夹
        foreach (FileInfo file in files)    //找到csv文件
        {
            if (!file.Name.EndsWith(".csv")) continue;   //跳过非csv文件

            csvFile = Resources.Load<TextAsset>("Build/" + Path.GetFileNameWithoutExtension(file.Name));    //加载csv文件
            csvFiles.Add(csvFile);  //添加到列表
        }
    }
    // 模块：预处理csv文件
    private void Factory_PreprocessCsvFile(TextAsset _csvFile)
    {
        //预处理csv文件内容
        rows = _csvFile.text.Split('\n');    //以行分割
        //分割第一行为列作为字段名
        var keys = rows[0].Split(',');
        //构建字段名与列索引的映射字典
        csvFieldIndexTable = new Dictionary<string, int>();
        for (var index = 0; index < keys.Length; index++)
        {
            string key = keys[index].Trim();
            Debug.Log(key);
            csvFieldIndexTable[key] = index;
        }
    }
    // 模块：加工中心
    private string Factory_ProcessCenter(string[] _colums,int _row,System.Reflection.FieldInfo field)
    {
        string value = _colums[_row];
        if(value == "<")   //拼接产线开始执行
        {
            Debug.Log("正在进行拼接!"+"拼接类型:"+field.Name);
            var sb = new StringBuilder();   //不定长构建字符串
            if (field.FieldType == typeof(List<int>))    //拼接多个list<int>单元格变为大的
            {
                bool firstToken = true;
                // 从 _row + 1 开始向后读取，最多读取 29 个单元格（和你原来的 i < 30 保持一致）
                for (int i = 1; i < 30; i++)
                {
                    int colIndex = _row + i;
                    if (colIndex >= _colums.Length) break; // 防止越界

                    string cell = _colums[colIndex]?.Trim();  // 使用 ? 防止 NullReference

                    if (string.IsNullOrWhiteSpace(cell)) continue;   //空的单元格跳过

                    if (cell == ">") break; ;// 遇到结束标记则停止读取

                    // 将该单元格按逗号拆分成若干 token，去除空项并 trim
                    var tokens = cell.Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries);
                    //  一个单元格里一个字符一个字符处理
                    foreach (var token in tokens)
                    {
                        var t = token.Trim();   //处理后返回新字符串
                        if (t.Length == 0) continue; // 再次防护空 token

                        if (!firstToken) sb.Append(','); // 不是第一个 token 前面加逗号  //更快更省内存

                        sb.Append(t);
                        firstToken = false;
                    }
                }
                // 最终拼接结果
                value = sb.ToString(); // 例如 "3,4,6,6,2"
            }
            else if (field.FieldType == typeof(List<LevelMonsterDice_List>))  //拼接多个list<string>单元格变为list嵌套
            {
                bool firstCellHasContent = false; // 是否已加入过第一个非空单元格
                for (int i = 1; i < 30; i++)
                {
                    int colIndex = _row + i;
                    if (colIndex >= _colums.Length) break;

                    string cell = _colums[colIndex]?.Trim();
                    if (string.IsNullOrWhiteSpace(cell)) continue; // 空单元格跳过（若希望空单元格作为终止条件，改为 break）
                    if (cell == ">") break; // 结束标记

                    // 处理单元格内的每个 item（按逗号拆分）
                    var tokens = cell.Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries);
                    var cellItems = new List<string>(tokens.Length);
                    //  加入到new的list表里，从string[] -> list<string>类型转换
                    foreach (var token in tokens)
                    {
                        var t = token.Trim();
                        if (t.Length == 0) continue;
                        cellItems.Add(t);
                    }
                    if (cellItems.Count == 0) continue; // 该单元格没有效内容，跳过
                    // 如果不是第一个有效单元格，就添加 cell 分隔符
                    if (firstCellHasContent)
                    {
                        sb.Append(CELL_SEP);
                    }
                    // 将这个单元格内部的 items 用逗号连接后追加（保持单元格内顺序）
                    sb.Append(string.Join(",", cellItems));
                    firstCellHasContent = true;
                }
                // 最终 value 示例: "a,b\u001Fc,d,e\u001Ff" —— 三个单元格，分别是 ["a","b"], ["c","d","e"], ["f"]
                value = sb.ToString();
            }
            Debug.Log("拼接执行完毕!");
        }
        return value;
    }
    // 模块：赋值判断中心 "dice1,dice2,dice3" "dice4,dice5"->"dice1,dice2,dice3,|,dice4,dice5" -> "dice1","dice2","dice3","|",
    private void Factory_AssignFieldValue(ScriptableObject soInstance, System.Reflection.FieldInfo field, string fieldValue)
    {
        if (field.FieldType == typeof(string))//  字符串类型
        {
            field.SetValue(soInstance, fieldValue);
        }
        else if (field.FieldType == typeof(int))//  整数类型
        {
            int.TryParse(fieldValue, out int result);
            field.SetValue(soInstance, result);
        }
        else if (field.FieldType == typeof(float))//  浮点数类型
        {
            float.TryParse(fieldValue, out float result);
            field.SetValue(soInstance, result);
        }
        else if (field.FieldType == typeof(Sprite)) //  Sprite类型
        {
            //  判断值是否是以Assets/开头的路径
            if (fieldValue.StartsWith("Assets/"))
            {
                loadPath_Asset = fieldValue; //资源加载路径-->其他的分类下的资源
            }
            else
            {
                loadRelativePath_Asset = fieldValue; //资源加载相对路径
                loadPath_Asset = saveDir_SO + "/" + loadRelativePath_Asset; //资源加载路径
            }
            // 如果路径以 "Assets/Resources/" 开头，去掉它
            if (loadPath_Asset.StartsWith("Assets/Resources/"))
                loadPath_Asset = loadPath_Asset.Substring("Assets/Resources/".Length);
            Sprite sprite = Resources.Load<Sprite>(loadPath_Asset); //加载Sprite资源
            field.SetValue(soInstance, sprite);
        }
        else if (field.FieldType == typeof(List<string>))//  List<string>类型
        {
            field.SetValue(soInstance, ParseListString(fieldValue));
        }
        else if (field.FieldType == typeof(List<int>))//  List<int>类型
        {
            field.SetValue(soInstance, ParseListInt(fieldValue));
        }
        else if (field.FieldType == typeof(List<Sprite>)) //  List<Sprite>类型
        {
            field.SetValue(soInstance, ParseListSprite(fieldValue));
        }
        else if (field.FieldType == typeof(List<LevelMonsterDice_List>))   //
        {
            field.SetValue(soInstance, ParseStringToNestedList_Dice(fieldValue));
            Debug.Log("List<levelMonsterDice_List>类型赋值完毕!");
        }
        else if (field.FieldType.BaseType == typeof(UnityEngine.Object))
        {
            field.SetValue(soInstance, AssetDatabase.LoadAssetAtPath(fieldValue, field.FieldType));
        }
        else
        {
            // 处理其他类型，默认使用Parse方法
            var parseMethod = field.FieldType.GetMethod("Parse", new Type[] { typeof(string) });
            if (parseMethod != null)
            {
                field.SetValue(soInstance, parseMethod.Invoke(null, new object[] { fieldValue }));
            }
        }
    }
    // 模块：解析逗号分隔的数字字符串并转换为 List<int>
    private List<int> ParseListInt(string data)
    {
        List<int> result = new List<int>();
        string[] values = data.Split(',');  // 按逗号分割字符串

        foreach (var value in values)
        {
            if (int.TryParse(value.Trim(), out int number))
            {
                result.Add(number);
            }
            else
            {
                result.Add(0);  // 如果无法解析为整数，默认为0
            }
        }
        return result;
    }
    // 模块：解析逗号分隔的字符串并转换为 List<string>
    private List<string> ParseListString(string data)
    {
        List<string> result = new List<string>();
        string[] values = data.Split(',');  // 按逗号分割字符串
        foreach (var value in values)
        {
            result.Add(value.Trim());
        }
        return result;
    }
    // 模块：解析逗号分隔的Sprite路径字符串并转换为 List<Sprite>
    private List<Sprite> ParseListSprite(string data)
    {
        List<Sprite> result = new List<Sprite>();
        string[] values = data.Split(',');  // 按逗号分割字符串变成一个一个的相对路径
        foreach (var value in values)
        {
            // 判断值是否是以Assets/开头的路径
            if (value.Trim().StartsWith("Assets/"))
            {
                loadPath_Asset = value.Trim(); //资源加载路径-->其他的分类下的资源
            }
            else
            {
                loadRelativePath_Asset = value.Trim(); //资源加载相对路径
                loadPath_Asset = saveDir_SO + "/" + loadRelativePath_Asset; //资源加载路径
            }
            // 如果路径以 "Assets/Resources/" 开头，去掉它
            if (loadPath_Asset.StartsWith("Assets/Resources/"))
                loadPath_Asset = loadPath_Asset.Substring("Assets/Resources/".Length);
            Debug.Log(loadPath_Asset);
            Sprite sprite = Resources.Load<Sprite>(loadPath_Asset); //加载Sprite资源
            result.Add(sprite);
        }
        return result;
    }
    // 模块：解析逗号分隔的字符串并转换为 List<levelMonsterDice_List>
    private List<LevelMonsterDice_List> ParseStringToNestedList_Dice(string data)
    {
        List<LevelMonsterDice_List> result = new List<LevelMonsterDice_List>();
        if (string.IsNullOrEmpty(data)) return result;

        var cellStrings = data.Split(new[] { CELL_SEP }, StringSplitOptions.None);
        for (int i = 0; i < cellStrings.Length; i++)
        {
            var cell = cellStrings[i];
            if (string.IsNullOrWhiteSpace(cell)) continue;

            var tokens = cell.Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries)
                             .Select(x => x.Trim())
                             .Where(x => x.Length > 0)
                             .ToList();

            if (tokens.Count > 0)
            {
                // 在这里 new List<string>()（tokens 已是一个新 List），并赋给 items
                var group = new LevelMonsterDice_List();
                group.dices_List = tokens;
                
                // 2. 改用Add方法，按顺序添加
                result.Add(group);
            }
        }
        return result;
    }
    // 解析 CSV 行，处理带有逗号的字段，将其视为单个字符串保存进string数组里
    private string[] ParseCsvRow(string row)    //避免简单的用逗号分隔造成数据错误
    {
        var columns = new List<string>();
        bool insideQuote = false;
        string currentField = "";

        foreach (char c in row)
        {
            if (c == '"')  // 如果是双引号，切换 "insideQuote" 状态
            {
                insideQuote = !insideQuote;
                continue;
            }

            if (c == ',' && !insideQuote)  // 逗号不是在引号内时，认为是字段分隔符
            {
                columns.Add(currentField.Trim());
                currentField = "";
            }
            else
            {
                currentField += c;  // 添加字符到当前字段
            }
        }

        // 最后一个字段没有逗号分隔，需要手动添加
        if (!string.IsNullOrEmpty(currentField))
        {
            columns.Add(currentField.Trim());
        }

        return columns.ToArray();   //返回处理后的字段数组
    }
    //模块：清理文件夹全部里的旧资源
    private void Factory_ClearOldAssets(string _pathDir)
    {
        // 先判断文件夹是否存在
        if (!AssetDatabase.IsValidFolder(_pathDir))// Assets/Resources/Card/Hero
        {
            Factory_CreateFolder(_pathDir);// 创建文件夹
        }
        else    //存在的情况下，删除旧资源
        {
            // 1) 使用 AssetDatabase 列出_pathDir文件夹下所有资源 GUID（包含文件与子文件夹）
            string[] guids = AssetDatabase.FindAssets("", new[] { _pathDir });

            // 2) 删除所有扩展名为 .asset 的资源（使用 AssetDatabase.DeleteAsset，正常会同时删除 .meta）
            foreach (var g in guids)
            {
                string path = AssetDatabase.GUIDToAssetPath(g); //根据guid唯一标识符找到对应资源
                if (string.IsNullOrEmpty(path)) continue;

                // 只处理 .asset 文件（忽略文件夹与其他类型）
                if (string.Equals(Path.GetExtension(path), ".asset", StringComparison.OrdinalIgnoreCase))
                {
                    bool deleted = AssetDatabase.DeleteAsset(path); // 删除资源
                    if (!deleted)
                    {
                        // 回退到文件系统删除（并尝试删除对应 .meta）
                        try
                        {
                            string fullPath = Path.Combine(Directory.GetCurrentDirectory(), path).Replace("\\", "/");
                            if (File.Exists(fullPath)) File.Delete(fullPath);
                            string meta = fullPath + ".meta";
                            if (File.Exists(meta)) File.Delete(meta);
                        }
                        catch (Exception e)
                        {
                            Debug.LogWarningFormat("[Csv2SO] 删除 .asset 回退失败: {0} 错误: {1}", path, e.Message);
                        }
                    }
                }
            }
        }

        // 4) 刷新数据库，确保变动生效（并保证根文件夹仍存在）
        AssetDatabase.Refresh();
        if (!AssetDatabase.IsValidFolder(saveDir_SO))
        {
            // 极端情况下如果根目录被误删，则重新创建
            Factory_CreateFolder(saveDir_SO);
            AssetDatabase.Refresh();
        }
    }
    //模块：递归创建文件夹
    private void Factory_CreateFolder(string _pathDir)
    {
        // 从 "Assets" 开始递归创建
        string[] parts = _pathDir.Split('/');
        string current = parts[0]; // 应该是 "Assets"

        for (int i = 1; i < parts.Length; i++)
        {
            string parent = current;
            current = parent + "/" + parts[i];

            // 如果该层文件夹不存在，就创建
            if (!AssetDatabase.IsValidFolder(current))
            {
                AssetDatabase.CreateFolder(parent, parts[i]);
            }
        }
    }
    //======实现对应接口======//
    public void OnPreprocessBuild(BuildReport report)
    {
        // 在编译前运行的逻辑
        Debug.Log("Running script before build...");
        Factory_SaveCsv2SO();
        Debug.Log("构建后创建完毕");
    }

    public void OnPostprocessBuild(BuildReport report)
    {
        // 在编译前运行的逻辑
        Debug.Log("Running script after build...");
    }
}
// --- Editor 菜单项，方便手动触发 ---
public static class Csv2soEditorMenu
{
    // 在编辑器菜单栏新建手动触发项
    [MenuItem("Tools/Csv2SO/Generate From CSV %&g")] // Ctrl+Alt+G (可改)
    public static void GenerateFromCSV_Menu()
    {
        bool ok = EditorUtility.DisplayDialog(
            "Csv2SO - Force Rebuild",
            "此操作会删除所有已存在的同名 .asset 并重新创建，是否继续？",
            "确定（删除并重建）",
            "取消"
        );

        if (!ok)
        {
            Debug.Log("[Csv2SO] 自动化转换操作已取消。");
            return;
        }

        var runner = new Csv2so();
        runner.Factory_SaveCsv2SO(); // 强制覆盖
    }
}
#endif
