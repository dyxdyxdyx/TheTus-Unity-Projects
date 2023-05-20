Shader "My Shader/TESS&GS/Phong Tessellation" {
    Properties {
        [MainColor] _MainCol ("Main Color", Color) = (1.0, 1.0, 1.0, 1.0)
        [Header (Tessellation)]
        _TessFactor ("Tess Factor (xyz: Edge Tess, w: Inside Tess", Vector) = (1.0, 1.0, 1.0, 1.0)
        [KeywordEnum (interger, fractional_odd, fractional_even)] _Partitioning ("Spacing Mode", Float) = 0.0
        [KeywordEnum (cw, cww)] _Order ("Generation Order", Float) = 0.0
        _Smoothing ("Phong Tessellation Smoothing (alpha)", Range(0.0, 1.0)) = 0.75
        [Header (Frame)]
        [Toggle (_FRAME_DISPLAY)] _FrameDisplay("Display Frame", Float) = 1.0
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

            HLSLPROGRAM
            // 几何着色器仅支持着色器版本4.0以上
            #pragma target 4.6
            #pragma multi_compile _ _PARTITIONING_INTERGER _PARTITIONING_FRACTIONAL_ODD _PARTITIONING_FRACTIONAL_EVEN
            #pragma multi_compile _ _ORDER_CW _ORDER_CWW
            #pragma shader_feature _FRAME_DISPLAY

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "PhongTessellationPass.hlsl"

            #pragma vertex PhongTessellationPassVertex
            #pragma hull PhongTessellationPassHull
            #pragma domain PhongTessellationPassDomain
            #pragma geometry PhongTessellationPassGeometry
            #pragma fragment PhongTessellationPassFragment
            ENDHLSL
        }
    }
}