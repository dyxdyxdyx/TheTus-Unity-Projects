using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace CPP{
    public enum CustomPostProcessInjectionPoint{
        AfterOpaqueAndSky,
        BeforePostProcess,
        AfterPostProcess
    }

    public abstract class CustomPostProcessing : VolumeComponent, IPostProcessComponent, IDisposable{
        // 材质声明
        protected Material mMaterial = null;
        private Material mCopyMaterial = null;

        private const string mCopyShaderName = "Hidden/PostProcess/PostProcessCopy";

        // 注入点
        public virtual CustomPostProcessInjectionPoint InjectionPoint => CustomPostProcessInjectionPoint.AfterPostProcess;

        //  在注入点的顺序
        public virtual int OrderInInjectionPoint => 0;

        protected override void OnEnable() {
            base.OnEnable();
            if (mCopyMaterial == null) {
                mCopyMaterial = CoreUtils.CreateEngineMaterial(mCopyShaderName);
            }
        }

        // 配置当前后处理
        public abstract void Setup();

        // 执行渲染
        public abstract void Render(CommandBuffer cmd, ref RenderingData renderingData, in RTHandle source, in RTHandle destination);

        #region Draw Function

        private int mSourceTextureId = Shader.PropertyToID("_SourceTexture");

        public virtual void Draw(CommandBuffer cmd, in RTHandle source, in RTHandle destination, int pass = -1) {
            // 将GPU端_SourceTexture设置为source
            cmd.SetGlobalTexture(mSourceTextureId, source);
            // 将RT设置为destination 不关心初始状态(直接填充) 需要存储
            cmd.SetRenderTarget(destination, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
            // 绘制程序化三角形
            if (pass == -1 || mMaterial == null)
                cmd.DrawProcedural(Matrix4x4.identity, mCopyMaterial, 0, MeshTopology.Triangles, 3);
            else
                cmd.DrawProcedural(Matrix4x4.identity, mMaterial, pass, MeshTopology.Triangles, 3);
        }

        #endregion

        // 设置keyword
        protected void SetKeyword(string keyword, bool enabled = true) {
            if (enabled) mMaterial.EnableKeyword(keyword);
            else mMaterial.DisableKeyword(keyword);
        }

        #region IPostProcessComponent

        public abstract bool IsActive();

        public virtual bool IsTileCompatible() => false;

        #endregion

        #region IDisposable

        public void Dispose() {
            Dispose(true);
            GC.SuppressFinalize(this);
        }

        public virtual void Dispose(bool disposing) {
        }

        #endregion
    }
}