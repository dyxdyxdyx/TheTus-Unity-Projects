TEXTURE2D(_Bloom);
SAMPLER(sampler_Bloom);
float _LuminanceThreshold;
float _BlurSize;


half luminance(half4 color) {
    //计算得到像素的亮度值
    return 0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b;
}

half4 fragExtractBright(Varyings input) : SV_Target {
    half4 c = GetSource(input);

    half val = saturate(luminance(c) - _LuminanceThreshold);

    return c * val;
}

struct v2fBlur {
    float4 pos : SV_POSITION;
    half2 uv[5]: TEXCOORD0;
};

v2fBlur vertBlurVertical(uint vertexID : SV_VertexID) {
    v2fBlur o;
    ScreenSpaceData ssData = GetScreenSpaceData(vertexID);
    o.pos = ssData.positionCS;
    half2 uv = ssData.uv;
    o.uv[0] = uv;
    o.uv[1] = uv + float2(0.0, _SourceTexture_TexelSize.y * 1.0) * _BlurSize;
    o.uv[2] = uv - float2(0.0, _SourceTexture_TexelSize.y * 1.0) * _BlurSize;
    o.uv[3] = uv + float2(0.0, _SourceTexture_TexelSize.y * 2.0) * _BlurSize;
    o.uv[4] = uv - float2(0.0, _SourceTexture_TexelSize.y * 2.0) * _BlurSize;

    return o;
}

v2fBlur vertBlurHorizontal(uint vertexID : SV_VertexID) {
    v2fBlur o;
    ScreenSpaceData ssData = GetScreenSpaceData(vertexID);
    o.pos = ssData.positionCS;
    half2 uv = ssData.uv;
    o.uv[0] = uv;
    o.uv[1] = uv + float2(_SourceTexture_TexelSize.x * 1.0, 0.0) * _BlurSize;
    o.uv[2] = uv - float2(_SourceTexture_TexelSize.x * 1.0, 0.0) * _BlurSize;
    o.uv[3] = uv + float2(_SourceTexture_TexelSize.x * 2.0, 0.0) * _BlurSize;
    o.uv[4] = uv - float2(_SourceTexture_TexelSize.x * 2.0, 0.0) * _BlurSize;

    return o;
}

half4 fragBlur(v2fBlur i) : SV_Target {
    float weight[3] = {0.4026, 0.2442, 0.0545};

    half3 sum = GetSource(i.uv[0]).rgb * weight[0];

    for (int it = 1; it < 3; it++) {
        sum += GetSource(i.uv[it * 2 - 1]).rgb * weight[it];
        sum += GetSource(i.uv[it * 2]).rgb * weight[it];
    }

    return half4(sum, 1.0); // 返回滤波后的结果
}

struct v2fBloom {
    float4 pos : SV_POSITION;
    half4 uv : TEXCOORD0;
};

//顶点着色器
v2fBloom vertBloom(uint vertexID : SV_VertexID) {
    v2fBloom o;

    ScreenSpaceData ssData = GetScreenSpaceData(vertexID);
    o.pos = ssData.positionCS;

    o.uv.xy = ssData.uv; //xy分量为_MainTex的纹理坐标		
    o.uv.zw = ssData.uv; //zw分量为_Bloom的纹理坐标

    // 平台差异化处理
    //判断y是否小于0，如果是就进行翻转处理
    #if UNITY_UV_STARTS_AT_TOP
    if (_SourceTexture_TexelSize.y < 0.0)
        o.uv.w = 1.0 - o.uv.w;
    #endif
    return o;
}

//片元着色器->混合亮部和原图
half4 fragBloom(v2fBloom i) : SV_Target {
    // 把这两张纹理的采样结果相加即可得到最终效果
    return GetSource(i.uv.zw) + SAMPLE_TEXTURE2D(_Bloom, sampler_Bloom, i.uv.zw);
}
