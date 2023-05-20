#ifndef __PASS_INCLUDED
#define __PASS_INCLUDED

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

CBUFFER_START (UnityPerMaterial)
float4 _MainCol;
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

half4 FlatWireframePassFragment(VertexOut input) : SV_Target {
    float3 dpdx = ddx(input.positionWS);
    float3 dpdy = ddy(input.positionWS);
    input.normalWS = normalize(cross(dpdy, dpdx));
    half3 finalCol = _MainCol.rgb * (normalize(input.normalWS) * 0.5 + 0.5);
    return half4(finalCol, 1.0);
}

#endif
