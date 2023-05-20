Shader "My Shader/TESS&GS/Flat Wireframe" {
    Properties {
        [MainColor] _MainCol ("Main Color", Color) = (1.0, 1.0, 1.0, 1.0)
        [Toggle (_FRAME_RENDERING)] _FrameRendering("Frame Rendering", Float) = 1.0
        _FrameCol ("Frame Color", Color) = (0.0, 0.0, 0.0, 0.0)
        _FrameScale ("Frame Width Scale", Range(1.0, 5.0)) = 2.0
        [Toggle (_NORMAL_SHADING)] _NormalShading ("Normal Shading", Float) = 0.0
    }
    SubShader {
        Tags {
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
            "RenderType" = "Opaque"
        }
        Pass {
            Name "FlatWireFrame Pass"

            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "FlatWireframePass.hlsl"

            // 几何着色器仅支持着色器版本4.0以上
            #pragma target 4.0

            #pragma shader_feature _NORMAL_SHADING
            #pragma shader_feature _FRAME_RENDERING

            #pragma vertex FlatWireframePassVertex
            #pragma geometry FlatWireframePassGeometry
            #pragma fragment FlatWireframePassFragment
            ENDHLSL
        }
    }
}