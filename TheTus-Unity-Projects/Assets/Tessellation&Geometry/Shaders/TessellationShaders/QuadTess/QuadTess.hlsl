#ifndef _QUAD_TESS_INCLUDED
#define _QUAD_TESS_INCLUDED

struct Attributes {
    float3 positionOS : POSITION;
};

struct VertexOut {
    float3 positionOS : TEXCOORD0;
};

struct PatchTess {
    float edgeTess[4] : SV_TessFactor;
    float insideTess[2] : SV_InsideTessFactor;
};

struct HullOut {
    float3 positionOS : TEXCOORD0;
};

struct DomainOut {
    float3 positionOS: TEXCOORD0;
};

struct GeoOut {
    float4 positionCS: SV_POSITION;
    float2 bary : TEXCOORD0;
};

// CBUFFER_START(UnityPerMaterial)
//
// CBUFFER_END

VertexOut QuadTessPassVertex(Attributes input) {
    VertexOut output;

    output.positionOS = input.positionOS;

    return output;
}

PatchTess QuadTessPassConstantHull(InputPatch<VertexOut, 4> patch, uint patchID : SV_PrimitiveID) {
    PatchTess pt;

    pt.edgeTess[0] = 25;
    pt.edgeTess[1] = 25;
    pt.edgeTess[2] = 25;
    pt.edgeTess[3] = 25;

    pt.insideTess[0] = 25;
    pt.insideTess[1] = 25;

    return pt;
}

[domain("quad")]
[partitioning("fractional_even")]
[outputtopology("triangle_cw")]
[outputcontrolpoints(4)]
[patchconstantfunc("QuadTessPassConstantHull")]
[maxtessfactor(64.0f)]
HullOut QuadTessPassHull(InputPatch<VertexOut, 4> patch, uint id : SV_OutputControlPointID) {
    HullOut output;

    output.positionOS = patch[id].positionOS;

    return output;
}

// 对于quad 输入的是uv坐标
[domain("quad")]
DomainOut QuadTessPassDomain(PatchTess patchTess, float2 uv : SV_DomainLocation, const OutputPatch<HullOut, 4> patch) {
    DomainOut output;

    float3 v1 = lerp(patch[0].positionOS, patch[1].positionOS, uv.x);
    float3 v2 = lerp(patch[2].positionOS, patch[3].positionOS, uv.x);
    float3 positionOS = lerp(v1, v2, uv.y);
    positionOS.y = 0.3f * (positionOS.z * sin(positionOS.x) + positionOS.x * cos(positionOS.z));

    output.positionOS = positionOS;

    return output;
}

[maxvertexcount(6)]
void QuadTessPassGeometry(triangle DomainOut input[3], inout TriangleStream<GeoOut> triStream) {
    GeoOut output[3];

    output[0].positionCS = TransformObjectToHClip(input[0].positionOS);
    output[1].positionCS = TransformObjectToHClip(input[1].positionOS);
    output[2].positionCS = TransformObjectToHClip(input[2].positionOS);

    output[0].bary = float2(1.0, 0.0);
    output[1].bary = float2(0.0, 1.0);
    output[2].bary = float2(0.0, 0.0);

    triStream.Append(output[0]);
    triStream.Append(output[1]);
    triStream.Append(output[2]);
}

half4 QuadTessPassFragment(GeoOut input) : SV_Target {
    float3 barys;

    barys.xy = input.bary;
    barys.z = 1.0 - barys.x - barys.y;
    // 屏幕空间变化率的和 让线框具有固定宽度
    float3 deltas = fwidth(barys);
    barys = smoothstep(deltas, 1.2 * deltas, barys);
    float minBary = min(barys.x, min(barys.y, barys.z));

    half3 finalCol = lerp(0.0, 1.0, minBary);

    return half4(finalCol, 1.0);
}
#endif
