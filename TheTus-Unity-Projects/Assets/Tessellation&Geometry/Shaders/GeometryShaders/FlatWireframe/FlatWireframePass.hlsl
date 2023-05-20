#ifndef _FLATWIREFRAME_PASS_INCLUDED
#define _FLATWIREFRAME_PASS_INCLUDED


struct Attributes {
    float4 positionOS : POSITION;
    float4 normalOS : NORMAL;
    float4 texcoord : TEXCOORD0;
};

struct VertexOut {
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 positionWS : TEXCOORD1;
    float3 normalWS : TEXCOORD2;
};

CBUFFER_START(UnityPerMaterial)
float4 _MainCol;
float4 _FrameCol;
float _FrameScale;
CBUFFER_END

VertexOut FlatWireframePassVertex(Attributes input) {
    VertexOut output;

    VertexPositionInputs vertexInputs = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS.xyz);
    output.positionCS = vertexInputs.positionCS;
    output.positionWS = vertexInputs.positionWS;
    output.normalWS = normalInputs.normalWS;

    return output;
}

struct GeoOut {
    VertexOut data;
    float2 barycentricCoordinates : TEXCOORD3;
};

// 输出顶点最大值 三角形3
[maxvertexcount(3)]
// 输入：顶点着色器输出的插值数据，三角形，原始数据
// 输出：输入到图元流，传递给片元着色器，将数据插值
void FlatWireframePassGeometry(triangle VertexOut input[3], inout TriangleStream<GeoOut> stream) {
    // 更改当前三角形中每个三角形的法线为面法线
    float3 p0 = input[0].positionWS.xyz;
    float3 p1 = input[1].positionWS.xyz;
    float3 p2 = input[2].positionWS.xyz;
    float3 normal = normalize(cross(p1 - p0, p2 - p0));

    input[0].normalWS = normal;
    input[1].normalWS = normal;
    input[2].normalWS = normal;

    GeoOut g0, g1, g2;
    g0.data = input[0];
    g1.data = input[1];
    g2.data = input[2];

    // 几何着色器输出到片元着色器的数据会经过重心插值
    // sum(barycentricValue) = 1.0
    g0.barycentricCoordinates = float2(1.0, 0.0);
    g1.barycentricCoordinates = float2(0.0, 1.0);
    g2.barycentricCoordinates = float2(0.0, 0.0);

    // 把输入的三角形以此放到输入流中
    stream.Append(g0);
    stream.Append(g1);
    stream.Append(g2);
}

half4 FlatWireframePassFragment(GeoOut input) : SV_Target {
    float3 barys;
    barys.xy = input.barycentricCoordinates;
    barys.z = 1.0 - barys.x - barys.y;
    // 屏幕空间变化率的和 让线框具有固定宽度
    float3 deltas = fwidth(barys);
    barys = smoothstep(deltas, _FrameScale * deltas, barys);
    float minBary = 1.0;
    #if defined(_FRAME_RENDERING)
    minBary = min(barys.x, min(barys.y, barys.z));
    #endif

    half3 normalShading = 1.0;
    #if defined(_NORMAL_SHADING)
    normalShading = (input.data.normalWS * 0.5) + 0.5;
    #endif

    half3 finalCol = _MainCol.rgb * normalShading * minBary + _FrameCol * (1 - minBary);

    return half4(finalCol, 1.0);
}

#endif
