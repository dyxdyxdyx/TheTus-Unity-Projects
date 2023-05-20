#ifndef LUTBUILDERLDR_PASS_INCLUDED
#define LUTBUILDERLDR_PASS_INCLUDED

float4 _LutParams;
float4 _ColorAdjustments;
float4 _ColorFilter;

struct Varyings {
    float4 positionCS : SV_POSITION;
    float2 uv : VAR_SCREEN_UV;
};

Varyings vert(uint vertexID : SV_VertexID) {
    Varyings output;
    // 根据id判断三角形顶点的坐标
    // 坐标顺序为(-1, -1) (-1, 3) (3, -1)
    output.positionCS = float4(vertexID <= 1 ? -1.0 : 3.0, vertexID == 1 ? 3.0 : -1.0, 0.0, 1.0);
    output.uv = float2(vertexID <= 1 ? 0.0 : 2.0, vertexID == 1 ? 2.0 : 0.0);
    // 不同API可能会产生颠倒的情况 进行判断
    if (_ProjectionParams.x < 0.0) {
        output.uv.y = 1.0 - output.uv.y;
    }
    return output;
}

// 根据色调映设空间(是否ACES) 返回对应亮度
float Luminance(float3 color, bool useACES) {
    return useACES ? AcesLuminance(color) : Luminance(color);
}

// 对比度
float3 ColorGradingContrast(float3 color, bool useACES) {
    // 为了更好的效果 如果使用ACES 则将颜色从线性空间转换到ACEScc空间 否则转换到logC空间
    color = useACES ? ACES_to_ACEScc(unity_to_ACES(color)) : LinearToLogC(color);
    // 从颜色中减去均匀的中间灰度，然后通过对比度进行缩放，然后在中间添加中间灰度
    color = (color - ACEScc_MIDGRAY) * _ColorAdjustments.y + ACEScc_MIDGRAY;
    // 将颜色转换回线性空间
    return useACES ? ACES_to_ACEScg(ACEScc_to_ACES(color)) : LogCToLinear(color);
}

// 颜色过滤
float3 ColorGradeColorFilter(float3 color) {
    // 将颜色与颜色滤镜相乘
    return color * _ColorFilter.rgb;
}

// 色相偏移
float3 ColorGradingHueShift(float3 color) {
    // 将颜色格式从rgb转换为hsv
    color = RgbToHsv(color);
    // 将色相偏移添加到h
    float hue = color.x + _ColorAdjustments.z;
    // 如果色相超出范围 将其截断
    color.x = RotateHue(hue, 0.0, 1.0);
    // 将颜色格式从hsv转换为rgb
    return HsvToRgb(color);
}

// 饱和度
float3 ColorGradingSaturation(float3 color, bool useACES) {
    // 获取颜色的亮度
    float luminance = Luminance(color, useACES);
    // 从颜色中减去亮度，然后通过饱和度进行缩放，然后在中间添加亮度
    return (color - luminance) * _ColorAdjustments.w + luminance;
}

half3 ColorGrade(float3 color, bool useAces = false) {
    // 对比度
    color = ColorGradingContrast(color, useAces);
    color = ColorGradeColorFilter(color);
    // 当对比度增加时，会导致颜色分量变暗，在这之后将颜色钳位
    color = max(color, 0.0);
    // 色相偏移
    color = ColorGradingHueShift(color);
    color = ColorGradingSaturation(color, useAces);
    // 当饱和度增加时，可能产生负数，在这之后将颜色钳位
    // 如果是ACES空间，则把颜色从ACEcg空间转回ACES 并且应用Aces tonemapping
    return max(useAces ? AcesTonemap(ACEScg_to_ACES(color)) : color, 0.0);
}

// params = (lut_height, 0.5 / lut_width, 0.5 / lut_height, lut_height / lut_height - 1)
real3 GetDeafultLutValue(float2 uv, float4 params) {
    uv -= params.yz;
    real3 color;
    color.r = frac(uv.x * params.x);
    color.b = uv.x - color.r / params.x;
    color.g = uv.y;
    return color * params.w;
}

half4 frag(Varyings input) : SV_Target {
    float3 color = GetDeafultLutValue(input.uv, _LutParams);
    #ifdef _HDR_GRADING
    #ifdef _TONEMAP_ACES
    return half4(ColorGrade(LogCToLinear(color), true), 1.0);
    #else
    return half4(ColorGrade(LogCToLinear(color)), 1.0);
    #endif
    #else
    return half4(ColorGrade(color), 1.0);
    #endif
}

#endif
