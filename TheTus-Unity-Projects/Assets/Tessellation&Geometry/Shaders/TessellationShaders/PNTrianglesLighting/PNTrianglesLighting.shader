Shader "My Shader/TESS&GS/PN Triangles Lighting" {
    Properties {
        [Header (Lighitng)]
        [MainColor] _MainCol ("Main Color", Color) = (1.0, 1.0, 1.0, 1.0)
        [MainTexture] _MainTex ("Main Texture", 2D) = "white" {}
        _SpecCol ("Specular Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _Smoothness ("Smoothness", Range(8.0, 256.0)) = 30.0
        [Header (Tessellation)]
        _TessFactor ("Tess Factor (xyz: Edge Tess, w: Inside Tess", Vector) = (1.0, 1.0, 1.0, 1.0)
        [KeywordEnum (interger, fractional_odd, fractional_even)] _Partitioning ("Spacing Mode", Float) = 0.0
        [KeywordEnum (cw, cww)] _Order ("Generation Order", Float) = 0.0
        _Smoothing ("TN Triangles Smoothing", Range(0.0, 1.0)) = 0.75
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

            HLSLPROGRAM
            // 几何着色器仅支持着色器版本4.0以上
            #pragma target 4.6
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _PARTITIONING_INTERGER _PARTITIONING_FRACTIONAL_ODD _PARTITIONING_FRACTIONAL_EVEN
            #pragma multi_compile _ _ORDER_CW _ORDER_CWW

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "PNTrianglesLightingPass.hlsl"

            #pragma vertex PNTrianglesLightingPassVertex
            #pragma hull PNTrianglesLightingPassHull
            #pragma domain PNTrianglesLightingPassDomain
            #pragma fragment PNTrianglesLightingPassFragment
            ENDHLSL
        }
    }
}