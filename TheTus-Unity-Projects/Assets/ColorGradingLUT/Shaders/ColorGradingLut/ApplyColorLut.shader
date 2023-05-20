Shader "Hidden/PostProcess/ApplyColorLut" {
    Properties {
        [HideInInspector] _MainTex ("Base (RGB)", 2D) = "white" {}
    }

    SubShader {
        Tags {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }
        LOD 200
        
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
        #include "../Common/PostProcessing.hlsl"
        #include "ApplyColorLutPass.hlsl"
        ENDHLSL
        
        Pass {
            name "ApplyColorLUT Pass"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment frag

            #pragma multi_compile _ _HDR_GRADING _TONEMAP_ACES
            ENDHLSL
        }
    }
}