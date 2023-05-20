#ifndef _PNTRIANGLES_PASS_INCLUDED
#define _PNTRIANGELS_PASS_INCLUDED

struct Attributes {
    float3 positionOS : POSITION;
    float3 normalOS : NORMAL;
};

struct VertexOut {
    float3 positionOS : TEXCOORD0;
    float3 normalOS : TEXCOORD1;
};

struct PatchTess {
    float edgeTess[3] : SV_TessFactor;
    float insideFactor : SV_InsideTessFactor;
};

struct HullOut {
    float3 positionOS : TEXCOORD0;
    float3 normalOS : TEXCOORD1;
    // cubic bezier邻接控制点
    float3 positionOS0 : TEXCOORD2;
    float3 positionOS1 : TEXCOORD3;
    // quadratic bezier邻接控制点
    float3 normalOS0 : TEXCOORD4;
};

struct DomainOut {
    float3 positionOS: TEXCOORD0;
    float3 normalOS : TEXCOORD1;
};

struct GeoOut {
    float4 positionCS : SV_POSITION;
    float2 bary : TEXCOORD0;
    float3 normalWS : TEXCOORD1;
};

CBUFFER_START(UnityPerMaterial)
float4 _MainCol;
float4 _TessFactor;
float _Smoothing;
float4 _FrameCol;
float _FrameScale;
CBUFFER_END

VertexOut PNTrianglesPassVertex(Attributes input) {
    VertexOut output;

    output.positionOS = input.positionOS;
    output.normalOS = input.normalOS;

    return output;
}

PatchTess PNTrianglesPassConstantHull(InputPatch<VertexOut, 3> patch, uint patchID : SV_PrimitiveID) {
    PatchTess pt;

    pt.edgeTess[0] = _TessFactor.x;
    pt.edgeTess[1] = _TessFactor.y;
    pt.edgeTess[2] = _TessFactor.z;
    pt.insideFactor = _TessFactor.w;

    return pt;
}

// 计算cubic bezier (p0, p1)的第一个控制点
float3 CalculateCubicBezierControlPoint(float3 p0, float3 p1, float3 n0) {
    return (2.0 * p0 + p1 - dot(n0, p1 - p0) * n0) / 3.0;
}

// 计算quadratic bezier (p0, p1)的控制点
float3 CalculateQuadraticBezierControlNormal(float3 n0, float3 n1, float3 p0, float3 p1) {
    float3 d = p1 - p0;
    float v = 2.0 * dot(d, n0 + n1) / dot(d, d);
    return normalize(n0 + n1 - v * d);
}

[domain("tri")]
#if defined(_PARTITIONING_INTERGER)
[partitioning("integer")]// 整数分割 向上取整
#elif defined(_PARTITIONING_FRACTIONAL_ODD)
[partitioning("fractional_odd")]// 奇数分割
#elif defined(_PARTITIONING_FRACTIONAL_EVEN)
[partitioning("fractional_even")]// 偶数分割
#else
[partitioning("integer")] // 整数分割 向上取整
#endif
#if defined(_ORDER_CW)
[outputtopology("triangle_cw")]
#elif defined(_ORDER_CWW)
[outputtopology("triangle_ccw")]
#else
[outputtopology("triangle_cw")]
#endif
[patchconstantfunc("PNTrianglesPassConstantHull")]
[outputcontrolpoints(3)]
[maxtessfactor(64.0)]
HullOut PNTrianglesPassHull(InputPatch<VertexOut, 3> patch, uint id : SV_OutputControlPointID) {
    HullOut output;

    output.positionOS = patch[id].positionOS;
    output.normalOS = patch[id].normalOS;

    // 计算两控制点坐标 在Constant Hull Shader里进行也可以
    // 计算邻接顶点patchId
    const uint adjVertexId = id < 2 ? id + 1 : 0;
    output.positionOS0 = CalculateCubicBezierControlPoint(patch[id].positionOS, patch[adjVertexId].positionOS, patch[id].normalOS);
    output.positionOS1 = CalculateCubicBezierControlPoint(patch[adjVertexId].positionOS, patch[id].positionOS, patch[adjVertexId].normalOS);
    output.normalOS0 = CalculateQuadraticBezierControlNormal(patch[id].normalOS, patch[adjVertexId].normalOS, patch[id].positionOS, patch[adjVertexId].positionOS);

    return output;
}

// 根据重心坐标计算 三次贝塞尔三角patch顶点 注意向量应在同一空间
float3 CalculateCubicBezierPosition(float3 controlPoints[10], float3 bary, float smoothing = 0.75) {
    float3 flatSurfacePosition = bary.x * controlPoints[0] + bary.y * controlPoints[3] + bary.z * controlPoints[6];
    float3 bezierSurfacePosition =
        bary.x * bary.x * bary.x * controlPoints[0] + 3.0 * bary.x * bary.x * bary.y * controlPoints[1] + 3.0 * bary.x * bary.y * bary.y * controlPoints[2] +
        bary.y * bary.y * bary.y * controlPoints[3] + 3.0 * bary.y * bary.y * bary.z * controlPoints[4] + 3.0 * bary.y * bary.z * bary.z * controlPoints[5] +
        bary.z * bary.z * bary.z * controlPoints[6] + 3.0 * bary.x * bary.z * bary.z * controlPoints[7] + 3.0 * bary.x * bary.x * bary.z * controlPoints[8] +
        6.0 * bary.x * bary.y * bary.z * controlPoints[9];

    return lerp(flatSurfacePosition, bezierSurfacePosition, smoothing);
}

// 根据重心坐标计算 二次贝塞尔三角patch法线 注意向量应在同一空间
float3 CalculateQuadraticBezierNormal(float3 controlPoints[6], float3 bary, float smoothing = 0.75) {
    float3 flatSurfaceNormal = bary.x * controlPoints[0] + bary.y * controlPoints[2] + bary.z * controlPoints[4];
    float3 bezierSurfaceNormal =
        bary.x * bary.x * controlPoints[0] + 2.0 * bary.x * bary.y * controlPoints[1] +
        bary.y * bary.y * controlPoints[2] + 2.0 * bary.y * bary.z * controlPoints[3] +
        bary.z * bary.z * controlPoints[4] + 2.0 * bary.x * bary.z * controlPoints[5];
    return normalize(lerp(flatSurfaceNormal, bezierSurfaceNormal, smoothing));
}

// 计算二次贝塞尔插值后的切线
float3 CalculateTangentAfterQuadraticBezier(float3 t0, float3 t1, float3 t2, float3 flatSurfaceNormal, float3 bezierSurfaceNormal, float3 bary) {
    float3 flatSurfaceTangent = bary.x * t0 + bary.y * t1 + bary.z * t2;
    float3 flatBitangent = cross(flatSurfaceNormal, flatSurfaceTangent);
    return normalize(cross(flatBitangent, bezierSurfaceNormal));
}

[domain("tri")]
DomainOut PNTrianglesPassDomain(PatchTess patchTess, float3 bary : SV_DomainLocation, OutputPatch<HullOut, 3> patch) {
    DomainOut output;

    // 计算cubic triangle bezier patch position
    // 计算控制点位置
    float3 controlPoints[10];
    float3 avgBezier = 0.0, avgVertices = 0.0;
    // 让编译器将循环展开
    UNITY_UNROLL
    for (int i = 0; i < 3; i++) {
        controlPoints[i * 3] = patch[i].positionOS;
        controlPoints[i * 3 + 1] = patch[i].positionOS0;
        controlPoints[i * 3 + 2] = patch[i].positionOS1;
        avgBezier += patch[i].positionOS0 + patch[i].positionOS1;
        avgVertices += patch[i].positionOS;
    }
    avgBezier /= 6.0;
    avgVertices /= 3.0;
    controlPoints[9] = avgBezier + (avgBezier - avgVertices) * 0.5;

    // 计算quadratic bezier patch normal
    // 计算控制点位置
    float3 controlNormals[6];
    UNITY_UNROLL
    for (int i = 0; i < 3; i ++) {
        controlNormals[i * 2] = patch[i].normalOS;
        controlNormals[i * 2 + 1] = patch[i].normalOS0;
    }

    // 计算贝塞尔点
    output.positionOS = CalculateCubicBezierPosition(controlPoints, bary, _Smoothing);
    output.normalOS = CalculateQuadraticBezierNormal(controlNormals, bary, _Smoothing);

    return output;
}

[maxvertexcount(3)]
void PNTrianglesPassGeometry(triangle DomainOut input[3], inout TriangleStream<GeoOut> stream) {
    GeoOut gout[3];
    gout[0].positionCS = TransformObjectToHClip(input[0].positionOS);
    gout[1].positionCS = TransformObjectToHClip(input[1].positionOS);
    gout[2].positionCS = TransformObjectToHClip(input[2].positionOS);

    gout[0].normalWS = TransformObjectToWorldNormal(input[0].normalOS);
    gout[1].normalWS = TransformObjectToWorldNormal(input[1].normalOS);
    gout[2].normalWS = TransformObjectToWorldNormal(input[2].normalOS);

    gout[0].bary = float2(1.0, 0.0);
    gout[1].bary = float2(0.0, 1.0);
    gout[2].bary = float2(0.0, 0.0);

    stream.Append(gout[0]);
    stream.Append(gout[1]);
    stream.Append(gout[2]);
}

half4 PNTrianglesPassFragment(GeoOut input) : SV_Target {
    float3 barys;
    barys.xy = input.bary;
    barys.z = 1.0 - barys.x - barys.y;
    // 屏幕空间变化率的和 让线框具有固定宽度
    float3 deltas = fwidth(barys);
    barys = smoothstep(deltas, _FrameScale * deltas, barys);
    float minBary = min(barys.x, min(barys.y, barys.z));

    half3 finalCol = lerp(_FrameCol, _MainCol, minBary);
    // finalCol = normalize(input.normalWS) * 0.5 + 0.5;

    return half4(finalCol, 1.0);
}
#endif
