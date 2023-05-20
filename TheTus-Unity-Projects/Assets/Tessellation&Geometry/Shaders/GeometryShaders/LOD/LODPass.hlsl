#ifndef _LOD_PASS_INCLUDED
#define _LOD_PASS_INCLUDED

struct Attributes {
    float4 positionOS : POSITION;
    float4 normalOS : NORMAL;
    float4 texcoord : TEXCOORD0;
};

struct VertexOut {
    float3 positionOS : TEXCOORD0;
    float3 normalOS : TEXCOORD1;
};

struct Varyings {
    float4 positionCS : SV_POSITION;
    float3 normalWS : TEXCOORD0;
    float2 baryCoord : TEXCOORD1;
};

CBUFFER_START(UnityPerMaterial)
float4 _MainCol;
float4 _FrameCol;
float _FrameScale;
CBUFFER_END

VertexOut LODPassVertex(Attributes input) {
    VertexOut output;

    output.positionOS = input.positionOS.xyz;
    output.normalOS = input.normalOS.xyz;

    return output;
}

// 根据模型空间位置计算Varyings，并输出到流
void AppendVertex(float3 positionOS, float2 baryCoord, inout TriangleStream<Varyings> triStream) {
    VertexOut vout;

    vout.positionOS = positionOS;
    vout.normalOS = normalize(vout.positionOS);
    vout.positionOS = normalize(vout.normalOS);

    Varyings gout;
    VertexPositionInputs vertexInputs = GetVertexPositionInputs(vout.positionOS);
    VertexNormalInputs normalInputs = GetVertexNormalInputs(vout.normalOS);
    gout.positionCS = vertexInputs.positionCS;
    gout.normalWS = normalInputs.normalWS;
    gout.baryCoord = baryCoord;

    triStream.Append(gout);
}

// 进行cnt次细分
void Subdivide(int cnt, VertexOut gin[3], inout TriangleStream<Varyings> triStream) {
    float depth = pow(2, cnt);// 层数
    uint vcnt = depth * 2 + 1; // 每层下行顶点数
    float len = distance(gin[0].positionOS, gin[1].positionOS) / depth; // 每个小三角形边长
    float3 rightup = normalize(gin[1].positionOS - gin[0].positionOS); // 右上向量
    float3 right = normalize(gin[2].positionOS - gin[0].positionOS); // 右向量
    
    float3 coordsX = {1.0, 0.0, 0.0};
    float3 coordsY = {0.0, 1.0, 0.0};

    // 用来当前层每行三角形的基准位置
    float3 down = gin[0].positionOS;
    float3 up = down + rightup * len;

    UNITY_UNROLL
    for (uint i = 0; i < depth; ++i) {
        for (uint j = 0; j < vcnt; ++j) {
            // 下行
            if (j % 2 == 0)
                AppendVertex(down + right * len * (j / 2), float2(coordsX[j % 3], coordsY[j % 3]), triStream);
            // 上行
            else
                AppendVertex(up + right * len * (j / 2), float2(coordsX[j % 3], coordsY[j % 3]), triStream);
        }
        // 迭代下一层
        vcnt -= 2;
        down = up;
        up += rightup * len;
        triStream.RestartStrip();
    }
}

[maxvertexcount(80)]
void LODPassGeometry(triangle VertexOut gin[3], uint primID : SV_PrimitiveID, inout TriangleStream<Varyings> triStream) {
    // 计算世界空间中心点与相机距离
    float3 centerW = mul(unity_ObjectToWorld, float3(0.0, 0.0, 0.0));
    float3 vDir = GetWorldSpaceViewDir(centerW);
    float dis = length(vDir);

    // 根据距离设置细分次数
    uint subCnt = 0;
    if (dis < 4)
        subCnt = 3;
    else if (dis < 8)
        subCnt = 2;
    else if (dis < 12)
        subCnt = 1;

    Subdivide(subCnt, gin, triStream);
}

half4 LODPassFragment(Varyings input) : SV_Target {
    float3 barys;
    barys.xy = input.baryCoord;
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
    normalShading = (input.normalWS * 0.5) + 0.5;
    #endif

    half3 finalCol = _MainCol.rgb * normalShading * minBary + _FrameCol * (1 - minBary);

    return half4(finalCol, 1.0);
}

#endif
