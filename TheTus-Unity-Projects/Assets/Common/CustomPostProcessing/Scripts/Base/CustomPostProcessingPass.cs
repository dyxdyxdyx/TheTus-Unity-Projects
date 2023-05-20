using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace CPP{
    public class CustomPostProcessingPass : ScriptableRenderPass{
        // 所有自定义后处理基类
        private List<CustomPostProcessing> mCustomPostProcessings;

        // 当前active组件下标
        private List<int> mActiveCustomPostProcessingIndex;

        // 每个组件对应的ProfilingSampler
        private string mProfilerTag;
        private List<ProfilingSampler> mProfilingSamplers;

        // 声明RT
        private RTHandle mSourceRT;
        private RTHandle mDesRT;
        private RTHandle mTempRT0;
        private RTHandle mTempRT1;

        private string mTempRT0Name => "_TemporaryRenderTexture0";
        private string mTempRT1Name => "_TemporaryRenderTexture1";

        public CustomPostProcessingPass(string profilerTag, List<CustomPostProcessing> customPostProcessings) {
            mProfilerTag = profilerTag;
            mCustomPostProcessings = customPostProcessings;
            mActiveCustomPostProcessingIndex = new List<int>(customPostProcessings.Count);
            // 将自定义后处理器对象列表转换成一个性能采样器对象列表
            mProfilingSamplers = customPostProcessings.Select(c => new ProfilingSampler(c.ToString())).ToList();

            mTempRT0 = RTHandles.Alloc(mTempRT0Name, name: mTempRT0Name);
            mTempRT1 = RTHandles.Alloc(mTempRT1Name, name: mTempRT1Name);
        }

        // 获取active的CPPs下标，并返回是否存在有效组件
        public bool SetupCustomPostProcessing() {
            mActiveCustomPostProcessingIndex.Clear();
            for (int i = 0; i < mCustomPostProcessings.Count; i++) {
                mCustomPostProcessings[i].Setup();
                if (mCustomPostProcessings[i].IsActive()) {
                    mActiveCustomPostProcessingIndex.Add(i);
                }
            }

            return mActiveCustomPostProcessingIndex.Count != 0;
        }
        
        // 实现渲染逻辑
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData) {
            // 初始化commandbuffer
            var cmd = CommandBufferPool.Get(mProfilerTag);
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();

            // 获取相机Descriptor
            var descriptor = renderingData.cameraData.cameraTargetDescriptor;
            descriptor.msaaSamples = 1;
            descriptor.depthBufferBits = 0;

            // 初始化临时RT
            bool rt1Used = false;

            // 设置源和目标RT为本次渲染的RT 在Execute里进行 特殊处理后处理后注入点
            mDesRT = renderingData.cameraData.renderer.cameraColorTargetHandle;
            mSourceRT = renderingData.cameraData.renderer.cameraColorTargetHandle;

            // 声明temp0临时纹理z
            RenderingUtils.ReAllocateIfNeeded(ref mTempRT0, descriptor, name: mTempRT0Name);

            // 执行每个组件的Render方法
            if (mActiveCustomPostProcessingIndex.Count == 1) {
                int index = mActiveCustomPostProcessingIndex[0];
                using (new ProfilingScope(cmd, mProfilingSamplers[index])) {
                    mCustomPostProcessings[index].Render(cmd, ref renderingData, mSourceRT, mTempRT0);
                }
            }
            else {
                // 如果有多个组件，则在两个RT上来回bilt
                RenderingUtils.ReAllocateIfNeeded(ref mTempRT1, descriptor, name: mTempRT1Name);
                rt1Used = true;
                Blit(cmd, mSourceRT, mTempRT0);
                for (int i = 0; i < mActiveCustomPostProcessingIndex.Count; i++) {
                    int index = mActiveCustomPostProcessingIndex[i];
                    var customProcessing = mCustomPostProcessings[index];
                    using (new ProfilingScope(cmd, mProfilingSamplers[index])) {
                        customProcessing.Render(cmd, ref renderingData, mTempRT0, mTempRT1);
                    }

                    CoreUtils.Swap(ref mTempRT0, ref mTempRT1);
                }
            }
            
            Blitter.BlitCameraTexture(cmd, mTempRT0, mDesRT);

            // 释放
            cmd.ReleaseTemporaryRT(Shader.PropertyToID(mTempRT0.name));
            if (rt1Used) cmd.ReleaseTemporaryRT(Shader.PropertyToID(mTempRT1.name));

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }
}