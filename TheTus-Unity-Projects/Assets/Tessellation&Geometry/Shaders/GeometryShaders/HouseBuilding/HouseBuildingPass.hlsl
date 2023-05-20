#ifndef _HOUSEBUILDING_PASS_INCLUDED
#define _HOUSEBUILDING_PASS_INCLUDED

struct Attributes {
    float4 positionOS : POSITION;
};

struct VertexOut {
    float4 positionOS : TEXCOORD0;
    float3 positionWS : TEXCOORD1;
};

struct Varyings {
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 positionWS : TEXCOORD1;
    uint primID: SV_PrimitiveID;
};

TEXTURE2D_ARRAY(_Textures);
SAMPLER(sampler_Textures);

CBUFFER_START(UnityPerMaterial)
float _BladeWidth;
float _Height;
float _TextureCount;
CBUFFER_END

VertexOut HouseBuildingPassVertex(Attributes input) {
    VertexOut output;

    VertexPositionInputs vertexInputs = GetVertexPositionInputs(input.positionOS);
    output.positionOS = input.positionOS;
    output.positionWS = vertexInputs.positionWS;

    return output;
}

// 输出最大顶点数量：5
[maxvertexcount(5)]
void HouseBuildingPassGeometry(point VertexOut input[1],// 输入图元类型：点
                               uint primID : SV_PrimitiveID,// 当前处理图元的ID
                               inout TriangleStream<Varyings> triStream) {// 输出流
    // 计算朝向摄像机的上方向和右方向向量
    float3 up = float3(0.0, 1.0, 0.0);
    float3 look = -GetWorldSpaceViewDir(input[0].positionWS.xyz);
    look.y = 0.0;
    look = normalize(look);
    float3 right = cross(up, look);

    float4 v[5];
    float width = _BladeWidth * 0.5, height = _Height * 0.5;
    // 顺时针
    v[0] = float4(input[0].positionWS.xyz + 1.7 * up * height, 1.0); // 顶部
    v[1] = float4(input[0].positionWS.xyz + width * right + height * up, 1.0); // 右上
    v[2] = float4(input[0].positionWS.xyz - width * right + height * up, 1.0); // 左上
    v[3] = float4(input[0].positionWS.xyz + width * right - height * up, 1.0); // 右下
    v[4] = float4(input[0].positionWS.xyz - width * right - height * up, 1.0); // 左下

    float2 texcoords[5];
    texcoords[0] = float2(0.0, 0.0);
    texcoords[1] = float2(1.0, 1.0);
    texcoords[2] = float2(0.0, 1.0);
    texcoords[3] = float2(1.0, 0.0);
    texcoords[4] = float2(0.0, 0.0);

    //  static loop，把循环展开
    Varyings gout;
    UNITY_UNROLL
    for (uint i = 0; i < 5; ++i) {
        VertexPositionInputs positionInputs = GetVertexPositionInputs(v[i]);
        gout.positionCS = TransformWorldToHClip(v[i]);
        gout.positionWS = v[i];
        gout.primID = primID;
        gout.uv = texcoords[i];

        triStream.Append(gout);
    }
}

half4 HouseBuildingPassFragment(Varyings input) : SV_Target {
    half4 var_MainTex = SAMPLE_TEXTURE2D_ARRAY(_Textures, sampler_Textures, input.uv, input.primID % _TextureCount);
    half3 finalCol = var_MainTex.rgb;

    return half4(finalCol, 1.0);
}

#endif
