#ifndef _PHONGTESSELLATIONLIGHITNG_PASS_INCLUDED
#define _PHONGTESSELLATIONLIGHITNG_PASS_INCLUDED

struct Attributes {
    float3 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 texcoord : TEXCOORD0;
};

struct VertexOut {
    float3 positionWS : TEXCOORD0;
    float3 normalWS : TEXCOORD1;
    float2 uv: TEXCOORD2;
};

struct PatchTess {
    float edgeTess[3] : SV_TessFactor;
    float insideFactor : SV_InsideTessFactor;
};

struct HullOut {
    float3 positionWS : TEXCOORD0;
    float3 normalWS : TEXCOORD1;
    float2 uv : TEXCOORD2;
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
float4 _FrameCol;
float _FrameScale;
CBUFFER_END


VertexOut PhongTessellationLighitngPassVertex(Attributes input) {
    VertexOut output;

    output.positionWS = TransformObjectToWorld(input.positionOS);
    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
    output.uv = TRANSFORM_TEX(input.texcoord, _MainTex);

    return output;
}

PatchTess PhongTessellationLighitngPassConstantHull(InputPatch<VertexOut, 3> patch, uint patchID : SV_PrimitiveID) {
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
[patchconstantfunc("PhongTessellationLighitngPassConstantHull")]
[outputcontrolpoints(3)]
[maxtessfactor(64.0)]
HullOut PhongTessellationLighitngPassHull(InputPatch<VertexOut, 3> patch, uint id : SV_OutputControlPointID) {
    HullOut output;

    output.positionWS = patch[id].positionWS;
    output.normalWS = patch[id].normalWS;
    output.uv = patch[id].uv;

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
float3 CalculatePhongPosition(float3 position, float3 p0Position, float3 p0Normal, float3 p1Position, float3 p1Normal, float3 p2Position, float3 p2Normal, float3 bary, float smoothing = 0.75) {
    float3 output = bary.x * PhongProjectedPosition(position, p0Position, p0Normal) +
        bary.y * PhongProjectedPosition(position, p1Position, p1Normal) +
        bary.z * PhongProjectedPosition(position, p2Position, p2Normal);
    return lerp(position, output, smoothing);
}

[domain("tri")]
DomainOut PhongTessellationLighitngPassDomain(PatchTess patchTess, float3 bary : SV_DomainLocation, OutputPatch<HullOut, 3> patch) {
    DomainOut output;

    float3 positionWS = DOMAIN_PROGRAM_INTERPOLATE(positionWS);
    float3 normalWS = DOMAIN_PROGRAM_INTERPOLATE(normalWS);
    float2 uv = DOMAIN_PROGRAM_INTERPOLATE(uv);

    output.positionWS = CalculatePhongPosition(positionWS, patch[0].positionWS, patch[0].normalWS, patch[1].positionWS, patch[1].normalWS, patch[2].positionWS, patch[2].normalWS, bary, _Smoothing);

    output.normalWS = normalWS;
    output.positionCS = TransformWorldToHClip(output.positionWS);
    output.uv = uv;
    output.shadowCoord = TransformWorldToShadowCoord(output.positionWS);

    return output;
}

half4 PhongTessellationLighitngPassFragment(DomainOut input) : SV_Target {
    half4 var_MainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);

    Light light = GetMainLight(input.shadowCoord);
    half3 lDirWS = normalize(light.direction);
    half3 vDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    half3 nDirWS = normalize(input.normalWS);

    half3 albedo = _MainCol.rgb * var_MainTex.rgb;
    half3 diffuse = albedo * LightingLambert(light.color, lDirWS, nDirWS);
    half3 specular = LightingSpecular(light.color, lDirWS, nDirWS, vDirWS, _SpecCol, _Smoothness);

    half3 finalCol = (diffuse + specular) * light.shadowAttenuation;

    return half4(finalCol, 1.0);
}
#endif
