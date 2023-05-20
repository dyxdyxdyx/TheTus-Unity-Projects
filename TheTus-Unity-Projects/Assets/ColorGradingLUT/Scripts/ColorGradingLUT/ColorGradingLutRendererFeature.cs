using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

struct ColorGradingLutParams{
    public bool hdr;
    public bool aces;
    public int lutSize;
}

struct ColorAdjustmentsParams{
    public float postExposure;
    public float contrast;
    public float hueShift;
    public float saturation;
    public Color colorFilter;
}

struct ApplyColorLutParams{
    public bool hdr;
    public bool aces;
    public Texture customLut;
    public float contribution;
}

internal class ColorGradingLutRendererFeature : ScriptableRendererFeature{
    private const string mApplyColorLutShaderName = "Hidden/PostProcess/ApplyColorLut";
    private const string mLutBuilderShaderName = "Hidden/PostProcess/LutBuilder";

    #region Params Define

    [Header("ColorGradingLut")] public bool hdr = false;
    public bool aces = false;
    public int lutSize = 16;

    [Header("ColorAdjustments")] public float postExposure;
    [Range(-100f, 100f)] public float contrast; // 对比度
    [ColorUsage(false, true)] public Color colorFilter = Color.white; // 颜色滤镜 没有alpha的HDR颜色
    [Range(-180f, 180f)] public float hueShift; // 色相偏移
    [Range(-100f, 100f)] public float saturation; // 饱和度

    [Header("CustomColorLut")] public Texture customLut = null;
    [Range(0.0f, 1.0f)] public float contribution = 0.0f;

    #endregion

    private Material mApplyColorLutMaterial;
    private Material mColorGradingLutMaterial;

    private ApplyColorLutParams mApplyColorLutParams;
    private ColorGradingLutParams mColorGradingLutParams;
    private ColorAdjustmentsParams mColorAdjustmentsParams;

    private ApplyColorLutRenderPass mApplyColorLutRenderPass = null;
    private ColorGradingLutRenderPass mColorGradingLutRenderPass = null;

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData) {
        if (renderingData.cameraData.postProcessEnabled) {
            if (mApplyColorLutRenderPass.isActive())
                renderer.EnqueuePass(mApplyColorLutRenderPass);
            if (mColorGradingLutRenderPass.isActive())
                renderer.EnqueuePass(mColorGradingLutRenderPass);
        }
    }

    public override void Create() {
        mColorGradingLutMaterial = CoreUtils.CreateEngineMaterial(mLutBuilderShaderName);
        mApplyColorLutMaterial = CoreUtils.CreateEngineMaterial(mApplyColorLutShaderName);

        mColorGradingLutParams.hdr = hdr;
        mColorGradingLutParams.aces = aces;
        mColorGradingLutParams.lutSize = lutSize;

        mColorAdjustmentsParams.postExposure = postExposure;
        mColorAdjustmentsParams.contrast = contrast;
        mColorAdjustmentsParams.hueShift = hueShift;
        mColorAdjustmentsParams.saturation = saturation;
        mColorAdjustmentsParams.colorFilter = colorFilter.linear;// 线性空间颜色

        mApplyColorLutParams.hdr = hdr;
        mApplyColorLutParams.aces = aces;
        mApplyColorLutParams.customLut = customLut;
        mApplyColorLutParams.contribution = contribution;

        mColorGradingLutRenderPass = new ColorGradingLutRenderPass(mColorGradingLutMaterial, mColorGradingLutParams, mColorAdjustmentsParams);
        mColorGradingLutRenderPass.renderPassEvent = RenderPassEvent.AfterRenderingPrePasses;

        mApplyColorLutRenderPass = new ApplyColorLutRenderPass(mApplyColorLutMaterial, mApplyColorLutParams);
        mApplyColorLutRenderPass.renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
    }

    protected override void Dispose(bool disposing) {
        CoreUtils.Destroy(mApplyColorLutMaterial);
    }
}