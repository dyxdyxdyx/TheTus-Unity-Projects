#ifndef APPLYCOLORLUT_PASS_INCLUDED
#define APPLYCOLORLUT_PASS_INCLUDED

TEXTURE2D(_CustomLut);
SAMPLER(sampler_CustomLut);
TEXTURE2D(_CustomInternalLut);
SAMPLER(sampler_CustomInternalLut);

float4 _CustomInternalLutParams;
float4 _CustomLutParams;
float _Contribution;
float _PostExposure;

float3 ApplyTonemapping(half3 input) {
    #ifdef _TONEMAP_ACES
    input = min(input, 60.0);
    input = AcesTonemap(unity_to_ACES(input));
    #endif

    // 把颜色钳位到0-1 输出LDR颜色
    return saturate(input);
}

// scaleOffset = (1 / lut_width, 1 / lut_height, lut_height - 1)
// gridSize = scaleOffset.x x scaleOffset.y, blockSize = scaleOffset.y
real3 ApplyLut(TEXTURE2D_PARAM(tex, samplerTex), float3 color, float3 scaleOffset) {
    // 计算block索引
    color.b *= scaleOffset.z;
    float block = floor(color.b);
    // 计算在u = uBase+uOffset
    float u = block * scaleOffset.y + color.r * scaleOffset.z * scaleOffset.x + scaleOffset.x * 0.5;
    float v = color.g * scaleOffset.z * scaleOffset.y + scaleOffset.y * 0.5;
    color.rgb = lerp(
        SAMPLE_TEXTURE2D_LOD(tex, samplerTex, float2(u,v), 0.0).rgb,
        SAMPLE_TEXTURE2D_LOD(tex, samplerTex, float2(u,v)+float2(scaleOffset.y, 0.0), 0.0).rgb,
        color.b - block); // 根据Blue在block位置插值

    return color;
}

half3 ApplyColorGrading(half3 input, float postExposure, TEXTURE2D_PARAM(lutTex, lutSampler), float3 lutParams, TEXTURE2D_PARAM(customLutTex, customLutSampler), float3 customLutParams,
                        float customLutContrib) {
    input *= postExposure;
    #ifdef _HDR_GRADING
    // Internal HDR Lut 需要进行ColorGrading+Tonemapping，所以在LogC空间
    float3 inputLutSpace = saturate(LinearToLogC(input));
    input = ApplyLut2D(TEXTURE2D_ARGS(lutTex, lutSampler), inputLutSpace, lutParams);

    UNITY_BRANCH
    // Custom Lut 只需要进行ColorGrading，所以在sRGB空间
    if(customLutContrib > 0.0) {
        input = saturate(input);// LDR color
        input.rgb = LinearToSRGB(input.rgb);// In LDR do the lut in sRGB for the user Lut
        half3 outLut = ApplyLut(TEXTURE2D_ARGS(customLutTex, customLutSampler), inputLutSpace, _CustomLutParams.xyz);
        input = lerp(input, outLut, customLutContrib);
        input.rgb = SRGBToLinear(input.rgb);// turn back to Linear Space
    }
    #else
    // 首先进行tonemapping（根据设置）
    input = ApplyTonemapping(input);

    UNITY_BRANCH
    if (customLutContrib > 0.0) {
        // 转到sRGB空间采样LUT
        input.rgb = LinearToSRGB(input.rgb);
        half3 outLut = ApplyLut(TEXTURE2D_ARGS(customLutTex, customLutSampler), input, customLutParams);
        input = lerp(input, outLut, customLutContrib);
        input.rgb = SRGBToLinear(input.rgb);
    }

    input = ApplyLut(TEXTURE2D_ARGS(lutTex, lutSampler), input, lutParams);
    #endif

    return input;
}

half4 frag(Varyings input) : SV_Target {
    half3 color = GetSource(input).xyz;
    color = ApplyColorGrading(color, _PostExposure, TEXTURE2D_ARGS(_CustomInternalLut, sampler_CustomInternalLut), _CustomInternalLutParams.xyz, TEXTURE2D_ARGS(_CustomLut, sampler_CustomLut),
                              _CustomLutParams.xyz, _Contribution);
    return half4(color, 1.0);
}

#endif
