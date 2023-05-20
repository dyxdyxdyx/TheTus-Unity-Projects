using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace CPP{
    public class CustomProcessRendererFeature : ScriptableRendererFeature{
        // 不同插入点的render pass
        private CustomPostProcessingPass mAfterOpaqueAndSkyPass;
        private CustomPostProcessingPass mBeforePostProcessPass;
        private CustomPostProcessingPass mAfterPostProcessPass;

        // 所有后处理基类列表
        private List<CustomPostProcessing> mCustomPostProcessings;

        // 获取所有的CustomPostProcessing实例，并且根据插入点排序，放入到对应Render Pass中
        public override void Create() {
            // 获取VolumeStack
            var stack = VolumeManager.instance.stack;

            // 获取所有的CustomPostProcessing实例
            mCustomPostProcessings = VolumeManager.instance.baseComponentTypeArray
                .Where(t => t.IsSubclassOf(typeof(CustomPostProcessing))) // 筛选出VolumeComponent派生类类型中所有的CustomPostProcessing类型元素 不论是否在Volume中 不论是否激活
                .Select(t => stack.GetComponent(t) as CustomPostProcessing) // 将类型元素转换为实例
                .ToList(); // 转换为List

            // 初始化不同插入点的render pass
            // 找到在透明物和天空后渲染的CustomPostProcessing
            var afterOpaqueAndSkyCPPs = mCustomPostProcessings
                .Where(c => c.InjectionPoint == CustomPostProcessInjectionPoint.AfterOpaqueAndSky) // 筛选出所有CustomPostProcessing类中注入点为透明物体和天空后的实例
                .OrderBy(c => c.OrderInInjectionPoint) // 按照顺序排序
                .ToList(); // 转换为List
            // 创建CustomPostProcessingPass类
            mAfterOpaqueAndSkyPass = new CustomPostProcessingPass("Custom PostProcess after Skybox", afterOpaqueAndSkyCPPs);
            // 设置Pass执行时间
            mAfterOpaqueAndSkyPass.renderPassEvent = RenderPassEvent.AfterRenderingSkybox;

            var beforePostProcessingCPPs = mCustomPostProcessings
                .Where(c => c.InjectionPoint == CustomPostProcessInjectionPoint.BeforePostProcess)
                .OrderBy(c => c.OrderInInjectionPoint)
                .ToList();
            mBeforePostProcessPass = new CustomPostProcessingPass("Custom PostProcess before PostProcess", beforePostProcessingCPPs);
            mBeforePostProcessPass.renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;

            var afterPostProcessCPPs = mCustomPostProcessings
                .Where(c => c.InjectionPoint == CustomPostProcessInjectionPoint.AfterPostProcess)
                .OrderBy(c => c.OrderInInjectionPoint)
                .ToList();
            mAfterPostProcessPass = new CustomPostProcessingPass("Custom PostProcess after PostProcessing", afterPostProcessCPPs);
            mAfterPostProcessPass.renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing;
        }
        
        // 当为每个摄像机设置一个渲染器时，调用此方法
        // 将不同注入点的RenderPass注入到renderer中
        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData) {
            // 当前渲染的游戏相机支持后处理
            if (renderingData.cameraData.postProcessEnabled) {
                // 为每个render pass设置RT
                // 并且将pass列表加到renderer中
                if (mAfterOpaqueAndSkyPass.SetupCustomPostProcessing()) {
                    mAfterOpaqueAndSkyPass.ConfigureInput(ScriptableRenderPassInput.Color);
                    renderer.EnqueuePass(mAfterOpaqueAndSkyPass);
                }

                if (mBeforePostProcessPass.SetupCustomPostProcessing()) {
                    mBeforePostProcessPass.ConfigureInput(ScriptableRenderPassInput.Color);
                    renderer.EnqueuePass(mBeforePostProcessPass);
                }

                if (mAfterPostProcessPass.SetupCustomPostProcessing()) {
                    mAfterPostProcessPass.ConfigureInput(ScriptableRenderPassInput.Color);
                    renderer.EnqueuePass(mAfterPostProcessPass);
                }
            }
        }

        protected override void Dispose(bool disposing) {
            base.Dispose(disposing);
            if (disposing && mCustomPostProcessings != null) {
                foreach (var item in mCustomPostProcessings) {
                    item.Dispose();
                }
            }
        }
    }
}