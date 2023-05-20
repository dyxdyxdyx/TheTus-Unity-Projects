using System.Collections.Generic;
using UnityEngine;

public class BezierGenerator : MonoBehaviour{
    private readonly int[] INDICES = {
        0, 1, 5, 4,
        2, 3, 7, 6,
        8, 9, 13, 12,
        10, 11, 15, 14
    };

    public Transform[] controlPoints;
    public Material material;

    private Mesh mMesh;
    private Vector3[] mVertices = new Vector3[4];
    private int[] mIndices = { 0, 1, 2, 3 };

    private ComputeBuffer mControlPointsBuffer;
    private List<Vector4> mControlPointsCPU = new List<Vector4>(16);

    void Start() {
        int pointCount = controlPoints.Length;
        if (pointCount != 16) {
            ErrorAndQuit();
        }

        mMesh = new Mesh();
        for (int i = 0; i < 16; i++) {
            mControlPointsCPU.Add(controlPoints[i].position);
        }
    }

    void Update() {
        // 更新控制点
        for (int i = 0; i < 16; i++) {
            mControlPointsCPU[i] = controlPoints[i].position;
        }

        material.SetVectorArray("_ControlPoints", mControlPointsCPU);

        // 更新并绘制Mesh
        mVertices[0] = controlPoints[0].position;
        mVertices[1] = controlPoints[3].position;
        mVertices[2] = controlPoints[15].position;
        mVertices[3] = controlPoints[12].position;

        mMesh.name = "Bezier";
        mMesh.SetVertices(mVertices);
        mMesh.SetIndices(mIndices, MeshTopology.Quads, 0);
        Graphics.DrawMesh(mMesh, Vector3.zero, Quaternion.identity, material, 0, null);
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