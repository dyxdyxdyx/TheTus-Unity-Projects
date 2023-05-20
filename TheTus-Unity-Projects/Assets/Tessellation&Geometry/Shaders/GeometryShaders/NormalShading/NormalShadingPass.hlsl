#ifndef _NORMALSHADING_PASS_INCLUDED
#define _NORMALSHADING_PASS_INCLUDED

struct Attributes {
    float4 positionOS : POSITION;
    float4 normalOS : NORMAL;
};

struct VertexOut {
    float3 positionOS : TEXCOORD0;
    float3 normalOS : TEXCOORD1;
};

struct Varyings {
    float4 positionCS : SV_POSITION;
    float3 normalWS : TEXCOORD0;
};

CBUFFER_START(UnityPerMaterial)
float4 _MainCol;
float _Offset;
float _Length;
CBUFFER_END

VertexOut NormalShadingPassVertex(Attributes input) {
    VertexOut output;

    output.positionOS = input.positionOS.xyz;
    output.normalOS = input.normalOS;

    return output;
}

[maxvertexcount(2)]
void NormalShadingPassGeometry(triangle VertexOut gin[3], uint primID : SV_PrimitiveID, inout LineStream<Varyings> lineStream) {
    // 根据法线计算模型空间两顶点位置
    VertexOut vout[2];
    float3 normal = normalize(gin[0].positionOS + gin[1].positionOS + gin[2].positionOS);
    vout[0].positionOS = (gin[0].positionOS + gin[1].positionOS + gin[2].positionOS) * 0.3333 + _Offset * normal; // 重心坐标
    vout[1].positionOS = vout[0].positionOS + normal * _Length;
    vout[0].normalOS = vout[1].normalOS = normal;

    Varyings gout[2];
    UNITY_UNROLL
    for (uint i = 0; i < 2; ++i) {
        VertexPositionInputs vertexInputs = GetVertexPositionInputs(vout[i].positionOS);
        VertexNormalInputs normalInputs = GetVertexNormalInputs(vout[i].normalOS.xyz);
        gout[i].positionCS = vertexInputs.positionCS;
        gout[i].normalWS = normalInputs.normalWS;

        lineStream.Append(gout[i]);
    }
}

half4 NormalShadingPassFragment(Varyings input) : SV_Target {
    half3 finalCol = _MainCol.rgb;
    #if defined (_NORMAL_SHADING)
    finalCol = normalize(input.normalWS) * 0.5 + 0.5;
    #endif

    return half4(finalCol, 1.0);
}

#endif
