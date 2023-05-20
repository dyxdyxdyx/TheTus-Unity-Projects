using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using CPP;
using UnityEngine.Serialization;

namespace CPP.EFFECTS{
    [VolumeComponentMenu("Custom Post-processing/Bloom")]
    public class Bloom : CustomPostProcessing{
        #region Parameters Define

        public ClampedIntParameter iterations = new ClampedIntParameter(0, 0, 4); //高斯模糊迭代次数
        public ClampedFloatParameter blurSpread = new ClampedFloatParameter(0.6f, 0.2f, 3.0f); //高斯模糊范围
        public IntParameter downSample = new ClampedIntParameter(2, 1, 8); //下采样，缩放系数
        [Range(0.0f, 4.0f)] public ClampedFloatParameter luminanceThreshold = new ClampedFloatParameter(0.6f, 0.0f, 4.0f); //阈值

        #endregion

        private const string mShaderName = "Hidden/PostProcess/Bloom";

        public override bool IsActive() => mMaterial != null && iterations.value != 0;

        public override CustomPostProcessInjectionPoint InjectionPoint => CustomPostProcessInjectionPoint.BeforePostProcess;
        public override int OrderInInjectionPoint => 0;

        private RTHandle mTempRT0, mTempRT1;
        private string mTempRT0Name => "_TemporaryRenderTexture0";
        private string mTempRT1Name => "_TemporaryRenderTexture1";


        public override void Setup() {
            if (mMaterial == null)
                mMaterial = CoreUtils.CreateEngineMaterial(mShaderName);

            mTempRT0 = RTHandles.Alloc(mTempRT0Name, name: mTempRT0Name);
            mTempRT1 = RTHandles.Alloc(mTempRT1Name, name: mTempRT1Name);
        }

        public override void Render(CommandBuffer cmd, ref RenderingData renderingData, in RTHandle source, in RTHandle destination) {
            if (mMaterial == null) return;
            var descriptor = renderingData.cameraData.cameraTargetDescriptor;
            descriptor.width /= downSample.value;
            descriptor.height /= downSample.value;
            descriptor.msaaSamples = 1;
            descriptor.depthBufferBits = 0;

            RenderingUtils.ReAllocateIfNeeded(ref mTempRT0, descriptor, name: mTempRT0Name, filterMode: FilterMode.Bilinear);
            // RenderingUtils.ReAllocateIfNeeded(ref mTempRT1, descriptor, name: mTempRT1Name, filterMode: FilterMode.Bilinear);

            mMaterial.SetFloat("_LuminanceThreshold", luminanceThreshold.value);
            Draw(cmd, source, mTempRT0, 0);

            for (int i = 0; i < iterations.value; i++) {
                mMaterial.SetFloat("_BlurSize", 1.0f + i * blurSpread.value); //传入模糊半径

                RenderingUtils.ReAllocateIfNeeded(ref mTempRT1, descriptor, name: mTempRT1Name, filterMode: FilterMode.Bilinear);
                Draw(cmd, mTempRT0, mTempRT1, 1);

                CoreUtils.Swap(ref mTempRT0, ref mTempRT1);
                Draw(cmd, mTempRT0, mTempRT1, 2);

                CoreUtils.Swap(ref mTempRT0, ref mTempRT1);
                Draw(cmd, mTempRT0, mTempRT1);
            }

            mMaterial.SetTexture("_Bloom", mTempRT0);

            Draw(cmd, mTempRT0, mTempRT1, 3);

            mMaterial.SetTexture("_Bloom", mTempRT0);
            Draw(cmd, source, destination, 3);


            // Draw(cmd, mTempRT0, destination);
            cmd.ReleaseTemporaryRT(Shader.PropertyToID(mTempRT0.name));
            cmd.ReleaseTemporaryRT(Shader.PropertyToID(mTempRT1.name));
        }

        public override void Dispose(bool disposing) {
            base.Dispose(disposing);
            CoreUtils.Destroy(mMaterial);
        }
    }
}