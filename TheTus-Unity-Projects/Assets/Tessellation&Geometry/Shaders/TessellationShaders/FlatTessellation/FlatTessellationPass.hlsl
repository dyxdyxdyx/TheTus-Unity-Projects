#ifndef _FLATTESSELLATIONPASS_PASS_INCLUDED
#define _FLATTESSELLATIONPASS_PASS_INCLUDED

struct Attributes {
    float3 positionOS : POSITION;
};

struct VertexOut {
    float3 positionOS : TEXCOORD0;
};

struct PatchTess {
    float edgeTess[3] : SV_TessFactor;
    float insideFactor : SV_InsideTessFactor;
};

struct HullOut {
    float3 positionOS : TEXCOORD0;
};

struct DomainOut {
    float3 positionOS: TEXCOORD0;
};

struct GeoOut {
    float4 positionCS : SV_POSITION;
    float2 bary : TEXCOORD0;
};

CBUFFER_START(UnityPerMaterial)
float4 _MainCol;
float4 _TessFactor;
float4 _FrameCol;
float _FrameScale;
CBUFFER_END

// 顶点着色器：接收IA控制点数据，向Hull Shader传递控制点数据
VertexOut FlatTessellationPassVertex(Attributes input) {
    VertexOut output;

    output.positionOS = input.positionOS;

    return output;
}

// Constant Hull Shader：接收顶点着色器传递的patch，向Tessellator传递细分因子
PatchTess FlatTessellationPassConstantHull(InputPatch<VertexOut, 3> patch, uint patchID : SV_PrimitiveID) {
    PatchTess pt;

    pt.edgeTess[0] = _TessFactor.x;
    pt.edgeTess[1] = _TessFactor.y;
    pt.edgeTess[2] = _TessFactor.z;
    pt.insideFactor = _TessFactor.w;

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
[partitioning("integer")]// 整数分割 向上取整
#endif
#if defined(_ORDER_CW)
[outputtopology("triangle_cw")]
#elif defined(_ORDER_CWW)
[outputtopology("triangle_ccw")]
#else
[outputtopology("triangle_cw")]
#endif
[patchconstantfunc("FlatTessellationPassConstantHull")]
[outputcontrolpoints(3)]
[maxtessfactor(64.0)]
// Control Point Hull Shader：接收顶点着色器传递的控制点，对控制点进行变换后输出给Domain Shader
HullOut FlatTessellationPassHull(InputPatch<VertexOut, 3> patch, uint id : SV_OutputControlPointID) {
    HullOut output;

    output.positionOS = patch[id].positionOS;

    return output;
}

// Domain Shader：接收Tessellator镶嵌化后的patch和常量外壳着色器输出的细分因子，将曲面顶点传递给下个阶段
[domain("tri")]
DomainOut FlatTessellationPassDomain(PatchTess patchTess, float3 bary : SV_DomainLocation, OutputPatch<HullOut, 3> patch) {
    DomainOut output;
    output.positionOS = patch[0].positionOS * bary.x + patch[1].positionOS * bary.y + patch[2].positionOS * bary.z;

    // 将顶点变换到齐次裁剪空间的任务在GS中完成

    return output;
}

[maxvertexcount(3)]
void FlatTessellationPassGeometry(triangle DomainOut input[3], inout TriangleStream<GeoOut> stream) {
    GeoOut gout[3];
    gout[0].positionCS = TransformObjectToHClip(input[0].positionOS);
    gout[1].positionCS = TransformObjectToHClip(input[1].positionOS);
    gout[2].positionCS = TransformObjectToHClip(input[2].positionOS);

    gout[0].bary = float2(1.0, 0.0);
    gout[1].bary = float2(0.0, 1.0);
    gout[2].bary = float2(0.0, 0.0);

    stream.Append(gout[0]);
    stream.Append(gout[1]);
    stream.Append(gout[2]);
}

half4 FlatTessellationPassFragment(GeoOut input) : SV_Target {
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
