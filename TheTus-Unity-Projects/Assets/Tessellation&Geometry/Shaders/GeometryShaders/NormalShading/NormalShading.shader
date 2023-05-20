Shader "My Shader/TESS&GS/Normal Shading" {
    Properties {
        [MainColor] _MainCol ("Color", Color) = (0.0, 0.0, 0.0, 0.0)
        [Toggle (_NORMAL_SHADING)] _NormalShading ("Normal Shading", Float) = 1.0
        _Offset ("Offset", Float) = 0.0
        _Length ("Length", Float) = 0.1
    }
    SubShader {
        Tags {
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
            "RenderType" = "Opaque"
        }
        Pass {
            Name "NormalShading Pass"

            Cull Off

            HLSLPROGRAM
            #pragma target 4.0
            #pragma shader_feature _NORMAL_SHADING

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "NormalShadingPass.hlsl"

            #pragma vertex NormalShadingPassVertex
            #pragma geometry NormalShadingPassGeometry
            #pragma fragment NormalShadingPassFragment
            ENDHLSL
        }
    }
}