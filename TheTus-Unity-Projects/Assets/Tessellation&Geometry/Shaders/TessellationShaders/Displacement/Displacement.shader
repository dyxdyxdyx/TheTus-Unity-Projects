Shader "My Shader/BUMP Mapping/Displacement" {
    Properties {
        [MainColor] _MainCol ("Main Color", Color) = (1.0, 1.0, 1.0, 1.0)
        [MainTexture] _MainTex ("Main Texture", 2D) = "white" {}
        _SpecCol ("Specular Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _Smoothness ("Smoothness", Range(8.0, 256.0)) = 30.0
        [Header (Normal Map)]
        _NormTex ("Normal Texture", 2D) = "bump" {}
        _BumpScale ("Bump Scale", Float) = 1.0
        [Header (Displacement)]
        _DisTex ("Displacement Texture", 2D) = "black"{}
        _DisStrength ("Displacement Strength", Float) = 1.0
        [Header (Tessellation)]
        _TessEdgeLength ("Tessellation Edge Length", Range(5.0, 100.0)) = 50.0
    }
    SubShader {
        Tags {
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
            "RenderType" = "Opaque"
        }

        Pass {
            Name "Lighting Pass"

            Tags {
                "LightMode" = "UniversalForward"
            }

            Cull Off

            HLSLPROGRAM
            #pragma target 4.6
            // 接受阴影
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _SHADOWS_SOFT

            #pragma vertex DisplacementPassVertex
            #pragma hull DisplacementPassHull
            #pragma domain DisplacementPassDomain
            #pragma fragment DisplacementPassFragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "DisplacementPass.hlsl"
            ENDHLSL
        }

        Pass {
            Name "ShadowCaster Pass"

            Tags {
                "LightMode" = "ShadowCaster"
            }

            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM
            #pragma target 4.6

            #pragma vertex DisplacementShadowCasterPassVertex
            #pragma hull DisplacementShadowCasterPassHull
            #pragma domain DisplacementShadowCasterPassDomain
            #pragma fragment DisplacementShadowCasterPassFragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "DisplacementShadowCasterPass.hlsl"
            ENDHLSL
        }
    }
}