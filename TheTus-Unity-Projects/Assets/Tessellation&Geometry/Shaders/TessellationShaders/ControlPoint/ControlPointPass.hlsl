#ifndef __PASS_INCLUDED
#define __PASS_INCLUDED

struct Attributes {
    float4 positionOS : POSITION;
};

struct Varyings {
    float4 positionCS : SV_POSITION;
};

CBUFFER_START (UnityPerMaterial)
float4 _MainCol;
CBUFFER_END


Varyings ControlPointPassVertex(Attributes input) {
    Varyings output;

    VertexPositionInputs vertexInputs = GetVertexPositionInputs(input.positionOS.xyz);
    output.positionCS = vertexInputs.positionCS;

    return output;
}

half4 ControlPointPassFragment(Varyings input) : SV_Target {
    half3 finalCol = _MainCol.rgb;

    return half4(finalCol, 1.0);
}

#endif
