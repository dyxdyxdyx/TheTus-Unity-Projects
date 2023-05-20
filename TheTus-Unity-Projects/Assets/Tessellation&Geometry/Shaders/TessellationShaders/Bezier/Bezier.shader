Shader "My Shader/TESS&GS/Bezier" {
    Properties {
        [Heaer (Beizer)]
        [MainColor] _MainCol ("Main Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _SpecCol ("Specular Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _Smoothness ("Smoothness", Range(8.0, 256.0)) = 30.0
        [Header (Tessellation)]
        _EdgeTess ("Edge Tess", Float) = 15.0
        _InsideTess ("Inside Tess", Float) = 15.0
        [Header (Frame)]
        [Toggle (_FRAME_DISPLAY)] _FrameDisplay ("Show Frame", Float) = 0.0
        _FrameCol ("Frame Color", Color) = (0.0, 0.0, 0.0, 1.0)
        _FrameScale ("Frame Scaler", Range(1.0, 3.0)) = 1.2
    }
    SubShader {
        Tags {
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
            "RenderType" = "Opaque"
        }
        Pass {
            Name "TessTest Pass"

            Tags {
                "LightMode" = "UniversalForward"
            }

            Cull Off

            HLSLPROGRAM
            // 曲面细分着色器仅支持着色器版本4.6以上
            #pragma target 4.6
            #pragma shader_feature _FRAME_DISPLAY

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "BezierPass.hlsl"

            #pragma vertex QuadTessPassVertex
            #pragma hull QuadTessPassHull
            #pragma domain QuadTessPassDomain
            #pragma geometry QuadTessPassGeometry
            #pragma fragment QuadTessPassFragment
            ENDHLSL
        }
    }
}