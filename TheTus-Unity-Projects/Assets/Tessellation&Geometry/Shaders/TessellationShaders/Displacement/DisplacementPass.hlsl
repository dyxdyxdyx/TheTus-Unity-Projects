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
    float4 uv : TEXCOORD0; // xy: MainTex zw: NormTex
    float3 positionWS : TEXCOORD1;
    float4 tangentWS : TEXCOORD2;
    float3 normalWS : TEXCOORD3;
    float4 shadowCoord : TEXCOORD4;
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
VertexOut DisplacementPassVertex(Attributes input) {
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

bool TriangleIsBelowClipPlane(float3 p0, float3 p1, float3 p2, int planeIndex, float bias) {
    float4 plane = unity_CameraWorldClipPlanes[planeIndex];
    // 结果为负，则在平面外部
    return dot(float4(p0, 1), plane) < bias && dot(float4(p1, 1), plane) < bias && dot(float4(p2, 1), plane) < bias;
}

bool TriangleIsBackFace(float4 p0CS, float4 p1CS, float4 p2CS, float bias) {
    float3 p0 = p0CS.xyz / p0CS.w;
    float3 p1 = p1CS.xyz / p1CS.w;
    float3 p2 = p2CS.xyz / p2CS.w;
    #if UNITY_REVERSED_Z
    return cross(p1 - p0, p2 - p0).z < bias;
    #else
        return cross(p1 - p0, p2-p0).z > -bias;
    #endif
}

// 根据视锥平面进行剔除
bool TriangleIsCulled(float3 p0WS, float3 p1WS, float3 p2WS, float bias) {
    float4 p0CS = TransformWorldToHClip(p0WS);
    float4 p1CS = TransformWorldToHClip(p1WS);
    float4 p2CS = TransformWorldToHClip(p2WS);
    return TriangleIsBackFace(p0CS, p1CS, p2CS, bias) ||
        TriangleIsBelowClipPlane(p0WS, p1WS, p2WS, 0, bias) ||
        TriangleIsBelowClipPlane(p0WS, p1WS, p2WS, 1, bias) ||
        TriangleIsBelowClipPlane(p0WS, p1WS, p2WS, 2, bias) ||
        TriangleIsBelowClipPlane(p0WS, p1WS, p2WS, 3, bias);
}

// 常量外壳着色器，传递细分因子
PatchTess DisplacementPassConstantHull(InputPatch<VertexOut, 3> patch, uint patchID : SV_PrimitiveID) {
    PatchTess pt;

    float3 p0 = TransformObjectToWorld(patch[0].positionOS);
    float3 p1 = TransformObjectToWorld(patch[1].positionOS);
    float3 p2 = TransformObjectToWorld(patch[2].positionOS);
    float bias = -0.5 * _DisStrength;
    // 判断是否要剔除三角形
    if (TriangleIsCulled(p0, p1, p2, bias)) {
        pt.edgeTess[0] = pt.edgeTess[1] = pt.edgeTess[2] = pt.insideTess = 0;
    }
    else {
        pt.edgeTess[0] = TessellationEdgeFactor(p1, p2);
        pt.edgeTess[1] = TessellationEdgeFactor(p2, p0);
        pt.edgeTess[2] = TessellationEdgeFactor(p0, p1);
        // 编译器优化
        pt.insideTess = (TessellationEdgeFactor(p1, p2) + TessellationEdgeFactor(p2, p0) + TessellationEdgeFactor(p0, p1)) * 0.333;
    }

    return pt;
}

// 控制点外壳着色器，传递patch数据
[domain("tri")]
[partitioning("integer")] // 整数分割 向上取整s
[outputtopology("triangle_cw")]
[patchconstantfunc("DisplacementPassConstantHull")]
[outputcontrolpoints(3)]
[maxtessfactor(64.0)]
HullOut DisplacementPassHull(InputPatch<VertexOut, 3> patch, uint id : SV_OutputControlPointID) {
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

// 域着色器，将顶点displacement，并且传递每个patch的数据给像素着色器
[domain("tri")]
DomainOut DisplacementPassDomain(PatchTess patchTess, float3 bary : SV_DomainLocation, OutputPatch<HullOut, 3> patch) {
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
    VertexNormalInputs normalInput = GetVertexNormalInputs(normalOS.xyz, tangentOS);

    output.positionCS = vertexInput.positionCS;
    output.positionWS = vertexInput.positionWS;
    output.normalWS = normalInput.normalWS;

    output.uv.xy = TRANSFORM_TEX(texcoord, _MainTex);
    output.uv.zw = TRANSFORM_TEX(texcoord, _NormTex);

    real sign = tangentOS.w * GetOddNegativeScale();
    half4 tangentWS = half4(normalInput.tangentWS, sign);
    output.tangentWS = tangentWS;

    output.shadowCoord = TransformWorldToShadowCoord(output.positionWS);

    return output;
}


half3 SampleNormal(float2 uv, TEXTURE2D_PARAM(bumpMap, sampler_bumpMap), half scale = half(1.0)) {
    half4 n = SAMPLE_TEXTURE2D(bumpMap, sampler_bumpMap, uv);
    return UnpackNormalScale(n, scale);
}

half3 GetNormalWS(DomainOut input, half3 normalTS) {
    float sgn = input.tangentWS.w;
    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
    half3x3 tbn = half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);
    half3 normalWS = TransformTangentToWorld(normalTS, tbn);
    return normalWS;
}

// 像素着色器，光照计算
half4 DisplacementPassFragment(DomainOut input) : SV_Target {
    Light light = GetMainLight(input.shadowCoord);

    half3 nDirTS = SampleNormal(input.uv.zw, TEXTURE2D_ARGS(_NormTex, sampler_NormTex), _BumpScale);
    half3 nDirWS = normalize(GetNormalWS(input, nDirTS));
    half3 lDirWS = normalize(light.direction);
    half3 vDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);

    half4 var_MainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv.xy);

    half3 albedo = _MainCol.rgb * var_MainTex.rgb;
    half3 diffuse = albedo * LightingLambert(light.color, lDirWS, nDirWS);
    half3 specular = LightingSpecular(light.color, lDirWS, nDirWS, vDirWS, _SpecCol, _Smoothness);

    half3 finalCol = (diffuse + specular) * light.shadowAttenuation;

    return half4(finalCol, 1.0);
}

#endif
