Shader "My Shader/TESS&GS/Flat Tessellation" {
    Properties {
        [MainColor] _MainCol ("Main Color", Color) = (1.0, 1.0, 1.0, 1.0)
        [Header (Tessellation)]
        _TessFactor ("Tess Factor (xyz: Edge Tess, w: Inside Tess", Vector) = (1.0, 1.0, 1.0, 1.0)
        [KeywordEnum (interger, fractional_odd, fractional_even)] _Partitioning ("Spacing Mode", Float) = 0.0
        [KeywordEnum (cw, cww)] _Order ("Generation Order", Float) = 0.0
        [Header (Frame)]
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

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "FlatTessellationPass.hlsl"

            #pragma vertex FlatTessellationPassVertex
            #pragma hull FlatTessellationPassHull
            #pragma domain FlatTessellationPassDomain
            #pragma geometry FlatTessellationPassGeometry
            #pragma fragment FlatTessellationPassFragment
            ENDHLSL
        }
    }
}