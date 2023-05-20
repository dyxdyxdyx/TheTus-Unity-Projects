#ifndef DISPLACEMENT_PASS_INCLUDED
#define DISPLACEMENT_PASS_INCLUDED


struct Attributes {
    float4 positionOS : POSITION;
    float4 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 texcoord : TEXCOORD0;
};

struct VertexOut {
    float4 positionOS : TEXCOORD0;
    float4 normalOS : TEXCOORD1;
    float4 tangentOS : TEXCOORD2;
    float2 texcoord : TEXCOORD3;
};

struct PatchTess {
    float edgeTess[3] : SV_TessFactor;
    float insideTess : SV_InsideTessFactor;
};

struct HullOut {
    float4 positionOS : TEXCOORD0;
    float4 normalOS : TEXCOORD1;
    float4 tangentOS : TEXCOORD2;
    float2 texcoord : TEXCOORD3;
};

struct DomainOut {
    float4 positionCS : SV_POSITION;
};

TEXTURE2D(_MainTex);
SAMPLER(sampler_MainTex);
TEXTURE2D(_DisTex);
SAMPLER(sampler_DisTex);
TEXTURE2D(_NormTex);
SAMPLER(sampler_NormTex);

CBUFFER_START(UnityPerMaterial)
float4 _MainTex_ST;
float4 _NormTex_ST;
float4 _DisTex_ST;
float _DisStrength;
float4 _MainCol;
float _BumpScale;
float4 _SpecCol;
float _Smoothness;
float _TessEdgeLength;
CBUFFER_END

// 顶点着色器，传递IA数据
VertexOut DisplacementShadowCasterPassVertex(Attributes input) {
    VertexOut output;

    output.positionOS = input.positionOS;
    output.normalOS = input.normalOS;
    output.tangentOS = input.tangentOS;
    output.texcoord = input.texcoord;

    return output;
}

// 基于屏幕占用范围的细分因子计算
float TessellationEdgeFactor(float3 p0, float3 p1) {
    float edgeLength = distance(p0, p1);
    
    float3 edgeCenter = (p0 + p1) * 0.5;
    float viewDistance = distance(edgeCenter, _WorldSpaceCameraPos);

    // 根据视距调整边世界空间细分因子
    return edgeLength * _ScreenParams.y / (_TessEdgeLength * viewDistance);
}

// 常量外壳着色器，传递细分因子
PatchTess DisplacementShadowCasterPassConstantHull(InputPatch<VertexOut, 3> patch, uint patchID : SV_PrimitiveID) {
    PatchTess pt;

    float3 p0 = TransformObjectToWorld(patch[0].positionOS);
    float3 p1 = TransformObjectToWorld(patch[1].positionOS);
    float3 p2 = TransformObjectToWorld(patch[2].positionOS);

    pt.edgeTess[0] = TessellationEdgeFactor(p1, p2);
    pt.edgeTess[1] = TessellationEdgeFactor(p2, p0);
    pt.edgeTess[2] = TessellationEdgeFactor(p0, p1);
    pt.insideTess = (pt.edgeTess[0] + pt.edgeTess[1] + pt.edgeTess[2]) * 0.333;

    return pt;
}

// 控制点外壳着色器，传递patch数据
[domain("tri")]
[partitioning("fractional_even")] // 整数分割 向上取整s
[outputtopology("triangle_cw")]
[patchconstantfunc("DisplacementShadowCasterPassConstantHull")]
[outputcontrolpoints(3)]
[maxtessfactor(64.0)]
HullOut DisplacementShadowCasterPassHull(InputPatch<VertexOut, 3> patch, uint id : SV_OutputControlPointID) {
    HullOut output;

    output.positionOS = patch[id].positionOS;
    output.normalOS = patch[id].normalOS;
    output.tangentOS = patch[id].tangentOS;
    output.texcoord = patch[id].texcoord;

    return output;
}

#define DOMAIN_PROGRAM_INTERPOLATE(fieldName) \
patch[0].fieldName * bary.x + \
patch[1].fieldName * bary.y + \
patch[2].fieldName * bary.z;

// 域着色器，将顶点displacement
[domain("tri")]
DomainOut DisplacementShadowCasterPassDomain(PatchTess patchTess, float3 bary : SV_DomainLocation, OutputPatch<HullOut, 3> patch) {
    DomainOut output;

    float3 positionOS = DOMAIN_PROGRAM_INTERPOLATE(positionOS);
    float3 normalOS = DOMAIN_PROGRAM_INTERPOLATE(normalOS);
    float4 tangentOS = DOMAIN_PROGRAM_INTERPOLATE(tangentOS);
    float2 texcoord = DOMAIN_PROGRAM_INTERPOLATE(texcoord);

    // Displacement
    float2 uv = TRANSFORM_TEX(texcoord, _DisTex);
    float displacement = SAMPLE_TEXTURE2D_LOD(_DisTex, sampler_DisTex, uv, 0).g;
    displacement = (displacement - 0.5) * _DisStrength;
    normalOS = normalize(normalOS);
    positionOS.xyz += normalOS * displacement;

    VertexPositionInputs vertexInput = GetVertexPositionInputs(positionOS);

    output.positionCS = vertexInput.positionCS;
    #if UNITY_REVERSED_Z
    output.positionCS.z = min(output.positionCS.z, UNITY_NEAR_CLIP_VALUE);
    #else
    output.positionCS.z = max(output.positionCS.z, UNITY_NEAR_CLIP_VALUE);
    #endif

    return output;
}

half4 DisplacementShadowCasterPassFragment(DomainOut input) : SV_Target {
    return 1.0;
}

#endif
