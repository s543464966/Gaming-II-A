//======各系统接入存档系统的接口======//
/// <summary>
/// 所有参与存档的系统必须实现这个接口
/// </summary>
public interface ISavable   //规定各系统继承该接口实现加载和存储临时数据给存档系统
{
    // ==========================================
    // 1. 存档接口方法 (Save Methods)
    // ==========================================

    /// <summary>各个系统把自己的临时数据状态写入到存档模型</summary>
    void ExportToSaveData(SaveData saveData);

    /// <summary>从存档模型读取数据并加载</summary>
    void LoadFromSaveData(SaveData saveData);
}

