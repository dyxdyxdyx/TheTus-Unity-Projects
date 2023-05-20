using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

internal class ColorGradingLutRenderPass : ScriptableRenderPass{
    private ProfilingSampler mProfilingSampler = new ProfilingSampler("CustomColorGradingLut");
    private Material mMaterial;

    private ColorGradingLutParams mColorGradingLutParams;
    private ColorAdjustmentsParams mColorAdjustmentsParams;

    private RTHandle mInternalLut;

    private int mLutParamsId = Shader.PropertyToID("_LutParams"),
        mColorAdjustmentsId = Shader.PropertyToID("_ColorAdjustments"),
        mColorFilterId = Shader.PropertyToID("_ColorFilter"),
        mPostExposureId = Shader.PropertyToID("_PostExposure"),
        mCustomInternalLutPramsId = Shader.PropertyToID("_CustomInternalLutParams");

    private const string mInternalLutName = "_CustomInternalLut";

    private const string mHDRGradingKeyword = "_HDR_GRADING",
        mTonemapACESKeyword = "_TONEMAP_ACES";

    public ColorGradingLutRenderPass(Material material, ColorGradingLutParams colorGradingLutParams, ColorAdjustmentsParams colorAdjustmentsParams) {
        mMaterial = material;
        mColorGradingLutParams = colorGradingLutParams;
        mColorAdjustmentsParams = colorAdjustmentsParams;

        mInternalLut = RTHandles.Alloc(mInternalLutName, name: mInternalLutName);
    }

    public bool isActive() => mMaterial != null;

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData) {
        var cmd = CommandBufferPool.Get();
        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();

        var lutHeight = mColorGradingLutParams.lutSize;
        var lutWidth = lutHeight * lutHeight;

        // params = (lut_height, 0.5 / lut_width, 0.5 / lut_height, lut_height / lut_height - 1)
        mMaterial.SetVector(mLutParamsId, new Vector4(lutHeight, 0.5f / lutWidth, 0.5f / lutHeight, lutHeight / (lutHeight - 1.0f)));
        // 将颜色调整属性发给material 曝光度、对比度、色相偏移和饱和度
        mMaterial.SetVector(mColorAdjustmentsId, new Vector4(
            Mathf.Pow(2f, mColorAdjustmentsParams.postExposure), // 曝光度 曝光单位是2的幂次
            mColorAdjustmentsParams.contrast * 0.01f + 1f, // 对比度 将范围从[-100, 100]转换到[0, 2]
            mColorAdjustmentsParams.hueShift * (1f / 360f), // 色相偏移 将范围从[-180, 180]转换到[-1, 1] ([-0.5, 0.5] ?)
            mColorAdjustmentsParams.saturation * 0.01f + 1f // 饱和度 将范围从[-100, 100]转换到[0, 2]
        ));
        mMaterial.SetColor(mColorFilterId, mColorAdjustmentsParams.colorFilter.linear); // 颜色滤镜 线性

        SetKeyWord(mHDRGradingKeyword, mColorGradingLutParams.hdr);
        SetKeyWord(mTonemapACESKeyword, mColorGradingLutParams.aces);

        RenderTextureDescriptor descriptor = new RenderTextureDescriptor(lutWidth, lutHeight, RenderTextureFormat.ARGB32, 0, 1);

        RenderingUtils.ReAllocateIfNeeded(ref mInternalLut, descriptor, name: mInternalLutName, filterMode: FilterMode.Bilinear);
        cmd.SetRenderTarget(mInternalLut, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);

        using (new ProfilingScope(cmd, mProfilingSampler)) {
            cmd.DrawProcedural(Matrix4x4.identity, mMaterial, 0, MeshTopology.Triangles, 3);
        }

        // 设置全局参数，让ApplyColorLut能够访问到
        cmd.SetGlobalTexture(mInternalLut.name, mInternalLut.nameID); // _CustomInternalLut 纹理
        cmd.SetGlobalFloat(mPostExposureId, Mathf.Pow(2f, mColorAdjustmentsParams.postExposure)); // _PostExposure
        // params (1.0/width, 1.0/height, height-1.0)
        cmd.SetGlobalVector(mCustomInternalLutPramsId, new Vector4(1.0f / lutWidth, 1.0f / lutHeight, lutHeight - 1.0f, 0.0f));// _CustomInternalLutParams

        cmd.ReleaseTemporaryRT(Shader.PropertyToID(mInternalLut.name));

        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();
        CommandBufferPool.Release(cmd);
    }

    private void SetKeyWord(string keyword, bool enabled = true) {
        if (enabled) mMaterial.EnableKeyword(keyword);
        else mMaterial.DisableKeyword(keyword);
    }
}