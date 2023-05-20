#ifndef _PNTRIANGLESLIGHITNG_PASS_INCLUDED
#define _PNTRIANGELSLIGHITNG_PASS_INCLUDED

struct Attributes {
    float3 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 texcoord : TEXCOORD0;
};

struct VertexOut {
    float3 positionWS : TEXCOORD0;
    float3 normalWS : TEXCOORD1;
    float2 uv : TEXCOORD2;
};

struct PatchTess {
    float edgeTess[3] : SV_TessFactor;
    float insideFactor : SV_InsideTessFactor;
};

struct HullOut {
    float3 positionWS : TEXCOORD0;
    float3 normalWS : TEXCOORD1;
    // cubic bezier邻接控制点
    float3 positionWS0 : TEXCOORD2;
    float3 positionWS1 : TEXCOORD3;
    // quadratic bezier邻接控制点
    float3 normalWS0 : TEXCOORD4;
    float2 uv : TEXCOORD5;
};

struct DomainOut {
    float4 positionCS : SV_POSITION;
    float3 positionWS: TEXCOORD0;
    float3 normalWS : TEXCOORD1;
    float2 uv : TEXCOORD2;
    float4 shadowCoord : TEXCOORD3;
};

TEXTURE2D(_MainTex);
SAMPLER(sampler_MainTex);

CBUFFER_START(UnityPerMaterial)
float4 _MainTex_ST;
float4 _MainCol;
float4 _SpecCol;
float _Smoothness;
float4 _TessFactor;
float _Smoothing;
CBUFFER_END

VertexOut PNTrianglesLightingPassVertex(Attributes input) {
    VertexOut output;

    output.positionWS = TransformObjectToWorld(input.positionOS);
    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
    output.uv = TRANSFORM_TEX(input.texcoord, _MainTex);

    return output;
}

PatchTess PNTrianglesLightingPassConstantHull(InputPatch<VertexOut, 3> patch, uint patchID : SV_PrimitiveID) {
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
[patchconstantfunc("PNTrianglesLightingPassConstantHull")]
[outputcontrolpoints(3)]
[maxtessfactor(64.0)]
HullOut PNTrianglesLightingPassHull(InputPatch<VertexOut, 3> patch, uint id : SV_OutputControlPointID) {
    HullOut output;

    output.positionWS = patch[id].positionWS;
    output.normalWS = patch[id].normalWS;
    output.uv = patch[id].uv;

    // 计算两控制点坐标 在Constant Hull Shader里进行也可以
    // 计算邻接顶点patchId
    const uint adjVertexId = id < 2 ? id + 1 : 0;
    output.positionWS0 = CalculateCubicBezierControlPoint(patch[id].positionWS, patch[adjVertexId].positionWS, patch[id].normalWS);
    output.positionWS1 = CalculateCubicBezierControlPoint(patch[adjVertexId].positionWS, patch[id].positionWS, patch[adjVertexId].normalWS);
    output.normalWS0 = CalculateQuadraticBezierControlNormal(patch[id].normalWS, patch[adjVertexId].normalWS, patch[id].positionWS, patch[adjVertexId].positionWS);

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
DomainOut PNTrianglesLightingPassDomain(PatchTess patchTess, float3 bary : SV_DomainLocation, OutputPatch<HullOut, 3> patch) {
    DomainOut output;

    // 计算cubic triangle bezier patch position
    // 计算控制点位置
    float3 controlPoints[10];
    float3 avgBezier = 0.0, avgVertices = 0.0;
    // 让编译器将循环展开
    UNITY_UNROLL
    for (int i = 0; i < 3; i++) {
        controlPoints[i * 3] = patch[i].positionWS;
        controlPoints[i * 3 + 1] = patch[i].positionWS0;
        controlPoints[i * 3 + 2] = patch[i].positionWS1;
        avgBezier += patch[i].positionWS0 + patch[i].positionWS1;
        avgVertices += patch[i].positionWS;
    }
    avgBezier /= 6.0;
    avgVertices /= 3.0;
    controlPoints[9] = avgBezier + (avgBezier - avgVertices) * 0.5;

    // 计算quadratic bezier patch normal
    // 计算控制点位置
    float3 controlNormals[6];
    UNITY_UNROLL
    for (int i = 0; i < 3; i ++) {
        controlNormals[i * 2] = patch[i].normalWS;
        controlNormals[i * 2 + 1] = patch[i].normalWS0;
    }

    // 计算贝塞尔点
    output.positionWS = CalculateCubicBezierPosition(controlPoints, bary, _Smoothing);
    output.normalWS = CalculateQuadraticBezierNormal(controlNormals, bary, _Smoothing);

    output.uv = bary.x * patch[0].uv + bary.y * patch[1].uv + bary.z * patch[2].uv;
    output.shadowCoord = TransformWorldToShadowCoord(output.positionWS);
    output.positionCS = TransformWorldToHClip(output.positionWS);

    return output;
}

half4 PNTrianglesLightingPassFragment(DomainOut input) : SV_Target {
    half4 var_MainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);

    Light light = GetMainLight(input.shadowCoord);
    half3 lDirWS = normalize(light.direction);
    half3 vDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    half3 nDirWS = normalize(input.normalWS);

    half3 albedo = var_MainTex.rgb * _MainCol.rgb;
    half3 diffuse = albedo * LightingLambert(light.color, lDirWS, nDirWS);
    half3 specular = LightingSpecular(light.color, lDirWS, nDirWS, vDirWS, _SpecCol, _Smoothness);
    
    half3 finalCol = (diffuse + specular) * light.shadowAttenuation;

    return half4(finalCol, 1.0);
}
#endif
