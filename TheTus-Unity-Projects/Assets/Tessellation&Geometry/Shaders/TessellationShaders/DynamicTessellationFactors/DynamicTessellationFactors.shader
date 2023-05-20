Shader "My Shader/TESS&GS/DynamicTessellationFactors" {
    Properties {
        [MainColor] _MainCol ("Main Color", Color) = (1.0, 1.0, 1.0, 1.0)
        [Header (Tessellation)]
        [KeywordEnum (interger, fractional_odd, fractional_even)] _Partitioning ("Spacing Mode", Float) = 0.0
        [KeywordEnum (cw, cww)] _Order ("Generation Order", Float) = 0.0
        [KeywordEnum (static, camera, screen)] _Dynamic ("Dynamic Factors", Float) = 0.0
        _TessFactor ("Tess Factor (xyz: Edge Tess, w: Inside Tess", Vector) = (1.0, 1.0, 1.0, 1.0)
        [Header (Camera Mode)]
        _TessMinDist ("Tesssellation Min Distance From Camera", Range(0.0, 10.0)) = 10.0
        _TessFadeDist ("Tessellation Fade Distance From Camera", Range(1.0, 20.0)) = 15.0
        [Header (Screen Mode)]
        _TriangleSize ("Triangle Size", Float) = 50.0 
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
            #pragma multi_compile _ _DYNAMIC_STATIC _DYNAMIC_CAMERA _DYNAMIC_SCREEN

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/GeometricTools.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Tessellation.hlsl"
            #include "DynamicTessellationFactorsPass.hlsl"

            #pragma vertex DynamicTessellationFactorsPassVertex
            #pragma hull DynamicTessellationFactorsPassHull
            #pragma domain DynamicTessellationFactorsPassDomain
            #pragma geometry DynamicTessellationFactorsPassGeometry
            #pragma fragment DynamicTessellationFactorsPassFragment
            ENDHLSL
        }
    }
}