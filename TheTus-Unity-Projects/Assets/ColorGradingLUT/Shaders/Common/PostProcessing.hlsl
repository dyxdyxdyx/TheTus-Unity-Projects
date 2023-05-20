#ifndef POSTPROCESSING_INCLUDED
#define POSTPROCESSING_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

TEXTURE2D(_MainTex);
SAMPLER(sampler_MainTex);
float4 _MainTex_TexelSize;

TEXTURE2D(_CameraDepthTexture);
SAMPLER(sampler_CameraDepthTexture);

struct Attributes {
    float4 positionOS : POSITION;
    float2 texcoord : TEXCOORD0;
};

struct Varyings {
    float2 uv : TEXCOORD0;
    float4 vertex : SV_POSITION;
    UNITY_VERTEX_OUTPUT_STEREO
};

half4 GetSource(float2 uv) {
    return SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
}

half4 GetSource(Varyings input) {
    return GetSource(input.uv);
}

Varyings Vert(Attributes input) {
    Varyings output = (Varyings)0;
    // 分配instance id
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    output.vertex = vertexInput.positionCS;
    output.uv = input.texcoord;

    return output;
}

#endif
