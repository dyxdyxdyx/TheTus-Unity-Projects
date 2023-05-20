#ifndef _PHONGTESSELLATION_PASS_INCLUDED
#define _PHONGTESSELLATION_PASS_INCLUDED

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
float _Smoothing;
float4 _FrameCol;
float _FrameScale;
CBUFFER_END

VertexOut PhongTessellationPassVertex(Attributes input) {
    VertexOut output;

    output.positionOS = input.positionOS;
    output.normalOS = input.normalOS;

    return output;
}

PatchTess PhongTessellationPassConstantHull(InputPatch<VertexOut, 3> patch, uint patchID : SV_PrimitiveID) {
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
[partitioning("integer")] // 整数分割 向上取整
#endif
#if defined(_ORDER_CW)
[outputtopology("triangle_cw")]
#elif defined(_ORDER_CWW)
[outputtopology("triangle_ccw")]
#else
[outputtopology("triangle_cw")]
#endif
[patchconstantfunc("PhongTessellationPassConstantHull")]
[outputcontrolpoints(3)]
[maxtessfactor(64.0)]
HullOut PhongTessellationPassHull(InputPatch<VertexOut, 3> patch, uint id : SV_OutputControlPointID) {
    HullOut output;

    output.positionOS = patch[id].positionOS;
    output.normalOS = patch[id].normalOS;

    return output;
}

#define DOMAIN_PROGRAM_INTERPOLATE(fieldName) \
patch[0].fieldName * bary.x + \
patch[1].fieldName * bary.y + \
patch[2].fieldName * bary.z;

// 计算三角形点Q投影到顶点vi切线平面P的点Q'
float3 PhongProjectedPosition(float3 position, float3 triVertexPosition, float3 normal) {
    return position - dot(position - triVertexPosition, normal) * normal;
}

// 计算应用Phong Tessellation后点p的位置
// 所有点应在同一空间
float3 CalculatePhongPosition(float3 position, float3 p0Position, float3 p0Normal, float3 p1Position, float3 p1Normal, float3 p2Position, float3 p2Normal, float3 bary, float smoothing = 0.75) {
    float3 output = bary.x * PhongProjectedPosition(position, p0Position, p0Normal) +
        bary.y * PhongProjectedPosition(position, p1Position, p1Normal) +
        bary.z * PhongProjectedPosition(position, p2Position, p2Normal);
    return lerp(position, output, smoothing);
}

[domain("tri")]
DomainOut PhongTessellationPassDomain(PatchTess patchTess, float3 bary : SV_DomainLocation, OutputPatch<HullOut, 3> patch) {
    DomainOut output;

    float3 positionOS = DOMAIN_PROGRAM_INTERPOLATE(positionOS);

    output.positionOS = CalculatePhongPosition(positionOS, patch[0].positionOS, patch[0].normalOS, patch[1].positionOS, patch[1].normalOS, patch[2].positionOS, patch[2].normalOS, bary, _Smoothing);

    return output;
}

[maxvertexcount(3)]
void PhongTessellationPassGeometry(triangle DomainOut input[3], inout TriangleStream<GeoOut> stream) {
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

half4 PhongTessellationPassFragment(GeoOut input) : SV_Target {
    float minBary = 1.0;

    #if defined(_FRAME_DISPLAY)
    float3 barys;
    barys.xy = input.bary;
    barys.z = 1.0 - barys.x - barys.y;
    // 屏幕空间变化率的和 让线框具有固定宽度
    float3 deltas = fwidth(barys);
    barys = smoothstep(deltas, _FrameScale * deltas, barys);
    minBary = min(barys.x, min(barys.y, barys.z));
    #endif

    half3 finalCol = lerp(_FrameCol, _MainCol, minBary);

    return half4(finalCol, 1.0);
}
#endif
