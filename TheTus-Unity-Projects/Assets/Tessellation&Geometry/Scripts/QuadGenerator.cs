using UnityEngine;

public class QuadGenerator : MonoBehaviour{
    private const int COUNT = 4;

    public Transform[] controlPoints;
    public Material material;

    private Mesh mMesh;
    private Vector3[] mVertices = new Vector3[COUNT];

    private int[] mIndices = { 0, 1, 3, 2 };

    void Start() {
        int pointCount = controlPoints.Length;
        if (pointCount != COUNT) {
            ErrorAndQuit();
        }
    }

    void Update() {
        // 生成Mesh
        mMesh = new Mesh();
        for (int i = 0; i < COUNT; ++i) {
            mVertices[i] = controlPoints[i].position;
            // mIndices[i] = i;
        }

        mMesh.vertices = mVertices;
        mMesh.SetIndices(mIndices, MeshTopology.Quads, 0);
        Graphics.DrawMesh(mMesh, Vector3.zero, Quaternion.identity, material, 0, Camera.main);
    }

    private void ErrorAndQuit() {
        Debug.LogError("错误：点的数量不是16或有空的Transform。请添加或移除控制点以使其数量为16。");
#if UNITY_EDITOR
        UnityEditor.EditorApplication.isPlaying = false;
#else
        Application.Quit();
#endif
    }
}