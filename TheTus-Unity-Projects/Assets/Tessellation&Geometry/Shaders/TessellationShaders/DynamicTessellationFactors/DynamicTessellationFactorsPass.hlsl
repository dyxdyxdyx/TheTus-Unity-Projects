#ifndef _DYNAMICTESSELLATIONFACTORS_PASS_INCLUDED
#define _DYNAMICTESSELLATIONFACTORS_PASS_INCLUDED

struct Attributes {
    float3 positionOS : POSITION;
};

struct VertexOut {
    float3 positionWS : TEXCOORD0;
};

struct PatchTess {
    float edgeTess[3] : SV_TessFactor;
    float insideFactor : SV_InsideTessFactor;
};

struct HullOut {
    float3 positionWS : TEXCOORD0;
};

struct DomainOut {
    float3 positionWS: TEXCOORD0;
};

struct GeoOut {
    float4 positionCS : SV_POSITION;
    float2 bary : TEXCOORD0;
};

CBUFFER_START(UnityPerMaterial)
float4 _MainCol;
float4 _TessFactor;
float4 _TessMinDist;
float _TessFadeDist;
float _TriangleSize;
float4 _FrameCol;
float _FrameScale;
CBUFFER_END

VertexOut DynamicTessellationFactorsPassVertex(Attributes input) {
    VertexOut output;

    output.positionWS = TransformObjectToWorld(input.positionOS);

    return output;
}

PatchTess DynamicTessellationFactorsPassConstantHull(InputPatch<VertexOut, 3> patch, uint patchID : SV_PrimitiveID) {
    PatchTess pt;
    float4 tessFactors = _TessFactor;

    #if defined(_DYNAMIC_CAMERA)
    float3 cameraPositionWS = GetCameraPositionWS();
    real3 distanceBasedTessFactor = GetDistanceBasedTessFactor(patch[0].positionWS, patch[1].positionWS, patch[2].positionWS, cameraPositionWS, _TessMinDist, _TessMinDist + _TessFadeDist);
    tessFactors = _TessFactor * CalcTriTessFactorsFromEdgeTessFactors(distanceBasedTessFactor);
    pt.edgeTess[0] = max(1.0, tessFactors.x);
    pt.edgeTess[1] = max(1.0, tessFactors.y);
    pt.edgeTess[2] = max(1.0, tessFactors.z);
    pt.insideFactor = max(1.0, tessFactors.w);
    #elif defined(_DYNAMIC_SCREEN)
    real3 screenSpaceTessFactor = GetScreenSpaceTessFactor(patch[0].positionWS, patch[1].positionWS, patch[2].positionWS, GetWorldToHClipMatrix(), _ScreenParams, _TriangleSize);
    tessFactors = _TessFactor * CalcTriTessFactorsFromEdgeTessFactors(screenSpaceTessFactor);
    #endif

    pt.edgeTess[0] = max(1.0, tessFactors.x);
    pt.edgeTess[1] = max(1.0, tessFactors.y);
    pt.edgeTess[2] = max(1.0, tessFactors.z);
    pt.insideFactor = max(1.0, tessFactors.w);

    return pt;
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
[patchconstantfunc("DynamicTessellationFactorsPassConstantHull")]
[outputcontrolpoints(3)]
[maxtessfactor(64.0)]
HullOut DynamicTessellationFactorsPassHull(InputPatch<VertexOut, 3> patch, uint id : SV_OutputControlPointID) {
    HullOut output;

    output.positionWS = patch[id].positionWS;

    return output;
}

[domain("tri")]
DomainOut DynamicTessellationFactorsPassDomain(PatchTess patchTess, float3 bary : SV_DomainLocation, OutputPatch<HullOut, 3> patch) {
    DomainOut output;
    output.positionWS = patch[0].positionWS * bary.x + patch[1].positionWS * bary.y + patch[2].positionWS * bary.z;

    return output;
}

[maxvertexcount(3)]
void DynamicTessellationFactorsPassGeometry(triangle DomainOut input[3], inout TriangleStream<GeoOut> stream) {
    GeoOut gout[3];
    gout[0].positionCS = TransformWorldToHClip(input[0].positionWS);
    gout[1].positionCS = TransformWorldToHClip(input[1].positionWS);
    gout[2].positionCS = TransformWorldToHClip(input[2].positionWS);

    gout[0].bary = float2(1.0, 0.0);
    gout[1].bary = float2(0.0, 1.0);
    gout[2].bary = float2(0.0, 0.0);

    stream.Append(gout[0]);
    stream.Append(gout[1]);
    stream.Append(gout[2]);
}

half4 DynamicTessellationFactorsPassFragment(GeoOut input) : SV_Target {
    float3 barys;
    barys.xy = input.bary;
    barys.z = 1.0 - barys.x - barys.y;
    // 屏幕空间变化率的和 让线框具有固定宽度
    float3 deltas = fwidth(barys);
    barys = smoothstep(deltas, _FrameScale * deltas, barys);
    float minBary = min(barys.x, min(barys.y, barys.z));

    half3 finalCol = lerp(_FrameCol, _MainCol, minBary);

    return half4(finalCol, 1.0);
}
#endif
