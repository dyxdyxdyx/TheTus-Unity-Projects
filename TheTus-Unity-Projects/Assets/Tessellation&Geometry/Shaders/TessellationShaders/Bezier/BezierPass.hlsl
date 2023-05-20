#ifndef _BEZIER_TESS_INCLUDED
#define _BEZIER_TESS_INCLUDED

struct Attributes {
    float3 positionOS : POSITION;
};

struct VertexOut {
    float3 positionOS : TEXCOORD0;
};

// quad patch: 4个边细分因子，2个内部细分因子
struct PatchTess {
    float edgeTess[4] : SV_TessFactor;
    float insideTess[2] : SV_InsideTessFactor;
};

struct HullOut {
    float3 positionOS : TEXCOORD0;
};

struct DomainOut {
    float3 positionOS: TEXCOORD0;
    float3 normalOS : TEXCOORD1;
};

struct GeoOut {
    float4 positionCS: SV_POSITION;
    float2 bary : TEXCOORD0;
    float3 positionWS : TEXCOORD1;
    float3 normalWS : TEXCOORD2;
};

CBUFFER_START(UnityPerMaterial)
float4 _MainCol;
float4 _SpecCol;
float _Smoothness;
float _EdgeTess;
float _InsideTess;
float4 _FrameCol;
float _FrameScale;

// C# 传过来的控制点坐标数组
float4 _ControlPoints[16];
CBUFFER_END

// Vertex Shader：将quad的4个control point传给Hull Shader
VertexOut QuadTessPassVertex(Attributes input) {
    VertexOut output;

    output.positionOS = input.positionOS;

    return output;
}

// Constant Hull Shader: 定义quad的细分因子，传递给Tessellator
PatchTess QuadTessPassConstantHull(InputPatch<VertexOut, 4> patch, uint patchID : SV_PrimitiveID) {
    PatchTess pt;

    // Uniform Tessellation
    pt.edgeTess[0] = _EdgeTess;
    pt.edgeTess[1] = _EdgeTess;
    pt.edgeTess[2] = _EdgeTess;
    pt.edgeTess[3] = _EdgeTess;

    pt.insideTess[0] = _InsideTess;
    pt.insideTess[1] = _InsideTess;

    return pt;
}

// Control Point Hull Shader: 仅传递Vertex Shader传递的quad的control point给Tessellator
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

// 计算伯恩斯坦基函数的4个系数（三阶）
float4 BernsteinBasis(float t) {
    float invT = 1.0f - t;

    return float4(invT * invT * invT,
                  3.0f * t * invT * invT,
                  3.0f * t * t * invT,
                  t * t * t);
}

// 通过伯恩斯坦系数计算控制点坐标
float3 CubicBezierSum(float4 basisU, float4 basisV) {
    float3 sum = float3(0.0f, 0.0f, 0.0f);
    sum = basisV.x * (basisU.x * _ControlPoints[0] + basisU.y * _ControlPoints[1] + basisU.z * _ControlPoints[2] + basisU.w * _ControlPoints[3]);
    sum += basisV.y * (basisU.x * _ControlPoints[4] + basisU.y * _ControlPoints[5] + basisU.z * _ControlPoints[6] + basisU.w * _ControlPoints[7]);
    sum += basisV.z * (basisU.x * _ControlPoints[8] + basisU.y * _ControlPoints[9] + basisU.z * _ControlPoints[10] + basisU.w * _ControlPoints[11]);
    sum += basisV.w * (basisU.x * _ControlPoints[12] + basisU.y * _ControlPoints[13] + basisU.z * _ControlPoints[14] + basisU.w * _ControlPoints[15]);

    return sum;
}

// 计算贝塞尔系数的导系数
float4 dBernsteinBasis(float t) {
    float invT = 1.0f - t;

    return float4(-3 * invT * invT,
                  3 * invT * invT - 6 * t * invT,
                  6 * t * invT - 3 * t * t,
                  3 * t * t);
}

// Domain Shader: 逐patch处理Tessllator传递的细分后的patch
// 对于quad 输入的是uv坐标(顶点patch位置uv，而非纹理uv)
[domain("quad")]
DomainOut QuadTessPassDomain(PatchTess patchTess, float2 uv : SV_DomainLocation, const OutputPatch<HullOut, 4> patch) {
    DomainOut output;

    // 由于uv in [0, 1]线性，刚好对应Bezier Curve的t，所以直接将uv带进Bernstein公式得到两轴系数，然后再将系数组合为Bezier Curved Surfaces

    // 计算曲面点坐标
    float4 basisU = BernsteinBasis(uv.x);
    float4 basisV = BernsteinBasis(uv.y);
    float3 positionOS = CubicBezierSum(basisU, basisV);

    // 计算曲面点偏导
    float4 dBasisU = dBernsteinBasis(uv.x);
    float4 dBasisV = dBernsteinBasis(uv.y);
    float3 dPu = CubicBezierSum(dBasisU, basisV);
    float3 dPv = CubicBezierSum(basisU, dBasisV);

    output.positionOS = positionOS;
    output.normalOS = cross(dPu, dPv);

    return output;
}

// Geometry Shader: 绘制Frame，https://catlikecoding.com/unity/tutorials/advanced-rendering/flat-and-wireframe-shading/
[maxvertexcount(6)]
void QuadTessPassGeometry(triangle DomainOut input[3], inout TriangleStream<GeoOut> triStream) {
    GeoOut output[3];

    output[0].bary = float2(1.0, 0.0);
    output[1].bary = float2(0.0, 1.0);
    output[2].bary = float2(0.0, 0.0);

    UNITY_UNROLL
    for (int i = 0; i < 3; i++) {
        output[i].positionCS = TransformObjectToHClip(input[i].positionOS);
        output[i].normalWS = TransformObjectToWorldNormal(input[i].normalOS);
        output[i].positionWS = TransformObjectToWorld(input[i].positionOS);
        triStream.Append(output[i]);
    }
}

half4 QuadTessPassFragment(GeoOut input) : SV_Target {
    // lighiting
    Light light = GetMainLight();

    half3 nDirWS = normalize(input.normalWS);
    half3 vDirWS = GetWorldSpaceViewDir(input.positionWS);
    half3 lDirWS = normalize(light.direction);

    half3 albedo = _MainCol.rgb;
    half3 diffuse = albedo * LightingLambert(light.color, lDirWS, nDirWS);
    half3 specular = LightingSpecular(light.color, lDirWS, nDirWS, vDirWS, _SpecCol, _Smoothness);

    half3 lighitng = (diffuse + specular) * light.shadowAttenuation;

    // frame
    float3 barys;

    float minBary = 1.0;

    #if defined(_FRAME_DISPLAY)
    barys.xy = input.bary;
    barys.z = 1.0 - barys.x - barys.y;
    // 屏幕空间变化率的和 让线框具有固定宽度
    float3 deltas = fwidth(barys);
    barys = smoothstep(deltas, _FrameScale * deltas, barys);
    minBary = min(barys.x, min(barys.y, barys.z));
    #endif
    
    half3 finalCol = lerp(_FrameCol, lighitng, minBary);

    return half4(finalCol, 1.0);
}
#endif
