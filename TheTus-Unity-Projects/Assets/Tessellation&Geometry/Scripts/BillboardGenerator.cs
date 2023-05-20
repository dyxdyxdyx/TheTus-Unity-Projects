using UnityEngine;

public class BillboardGenerator : MonoBehaviour{
    public int number;
    public Vector2 xRange, yRange, zRange;
    public Texture2D[] textures;
    public Material material;

    private Mesh mMesh;

    void Start() {
        // 发送Texture2D Array到Shader
        int texLen = textures.Length;
        Texture2DArray texArray = new Texture2DArray(textures[0].width, textures[0].height, texLen, textures[0].format, false);
        for (int i = 0; i < texLen; ++i)
            Graphics.CopyTexture(textures[i], 0, 0, texArray, i, 0);
        texArray.Apply();
        material.SetTexture("_Textures", texArray);
        material.SetInt("_TextureCount", texLen);

        // 生成Mesh
        mMesh = new Mesh();
        // 生成顶点和索引
        Vector3[] vertices = new Vector3[number];
        int[] indices = new int[number];
        for (int i = 0; i < number; ++i) {
            float x = Random.Range(xRange.x, xRange.y), y = Random.Range(yRange.x, yRange.y), z = Random.Range(zRange.x, zRange.y);
            vertices[i] = new Vector3(x, y, z);
            indices[i] = i;
        }

        // 生成点图元拓扑序列
        mMesh.vertices = vertices;
        mMesh.SetIndices(indices, MeshTopology.Points, 0);
    }

    // 每帧渲染Mesh
    void Update() {
        Graphics.DrawMesh(mMesh, Vector3.zero, Quaternion.identity, material, 0, Camera.main);
    }
}