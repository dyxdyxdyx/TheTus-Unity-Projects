Shader "Hidden/PostProcess/Bloom" {
    Properties {
        [HideInInspector] _MainTex ("Base (RGB)", 2D) = "white" {}
    }

    SubShader {
        Tags {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }
        LOD 200
        ZWrite Off
        Cull Off
        HLSLINCLUDE
        #include "../Common/PostProcessing.hlsl"
        #include "BloomPass.hlsl"
        ENDHLSL

        //第一个pass，提取较亮区域
        Pass {
            Name "ExtractBright"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment fragExtractBright
            ENDHLSL
        }

        //第二个pass，进行竖直方向高斯模糊
        Pass {
            Name "BlurVertical"
            HLSLPROGRAM
            #pragma vertex vertBlurVertical
            #pragma fragment fragBlur
            ENDHLSL
        }

        //第三个pass，进行水平方向高斯模糊
        Pass {
            Name "BlurHorizontal"
            HLSLPROGRAM
            #pragma vertex vertBlurHorizontal
            #pragma fragment fragBlur
            ENDHLSL
        }

        //第四个pass，混合高亮区域和原图
        Pass {
            Name "BloomBlend"
            HLSLPROGRAM
            #pragma vertex vertBloom
            #pragma fragment fragBloom
            ENDHLSL
        }
    }
}