using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

internal class ApplyColorLutRenderPass : ScriptableRenderPass{
    private ProfilingSampler mProfilingSampler = new ProfilingSampler("ApplyColorLut");
    private Material mMaterial;

    private ApplyColorLutParams mApplyColorLutParams;

    private RTHandle mTempRT0;
    private const string mTempRT0Name = "_TemporaryRenderTexture0";

    private int mCustomLutId = Shader.PropertyToID("_CustomLut"),
        mCustomLutParamsId = Shader.PropertyToID("_CustomLutParams"),
        mContributionId = Shader.PropertyToID("_Contribution");

    private const string mHDRGradingKeyword = "_HDR_GRADING",
        mTonemapACESKeyword = "_TONEMAP_ACES";

    public bool isActive() => mMaterial != null && mApplyColorLutParams.customLut != null;


    public ApplyColorLutRenderPass(Material material, ApplyColorLutParams applyColorColorLutParams) {
        mMaterial = material;
        mApplyColorLutParams = applyColorColorLutParams;

        mTempRT0 = RTHandles.Alloc(mTempRT0Name, name: mTempRT0Name);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData) {
        var cmd = CommandBufferPool.Get("ApplyColorLut");
        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();

        mMaterial.SetTexture(mCustomLutId, mApplyColorLutParams.customLut);
        mMaterial.SetFloat(mContributionId, mApplyColorLutParams.contribution);
        // params (1.0/width, 1.0/height, height-1.0)
        mMaterial.SetVector(mCustomLutParamsId,
            new Vector4(1.0f / mApplyColorLutParams.customLut.width, 1.0f / mApplyColorLutParams.customLut.height, mApplyColorLutParams.customLut.height - 1.0f, 0.0f));

        SetKeyWord(mHDRGradingKeyword, mApplyColorLutParams.hdr);
        SetKeyWord(mTonemapACESKeyword, mApplyColorLutParams.aces);

        var renderer = renderingData.cameraData.renderer;
        var source = renderer.cameraColorTargetHandle;
        var destination = renderer.cameraColorTargetHandle;

        var descriptor = renderingData.cameraData.cameraTargetDescriptor;
        descriptor.msaaSamples = 1;
        descriptor.depthBufferBits = 0;

        RenderingUtils.ReAllocateIfNeeded(ref mTempRT0, descriptor, name: mTempRT0Name, filterMode: FilterMode.Bilinear);
        using (new ProfilingScope(cmd, mProfilingSampler)) {
            cmd.Blit(source, mTempRT0, mMaterial, 0);
            cmd.Blit(mTempRT0, destination);
        }

        cmd.ReleaseTemporaryRT(Shader.PropertyToID(mTempRT0.name));

        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();
        CommandBufferPool.Release(cmd);
    }

    private void SetKeyWord(string keyword, bool enabled = true) {
        if (enabled) mMaterial.EnableKeyword(keyword);
        else mMaterial.DisableKeyword(keyword);
    }
}