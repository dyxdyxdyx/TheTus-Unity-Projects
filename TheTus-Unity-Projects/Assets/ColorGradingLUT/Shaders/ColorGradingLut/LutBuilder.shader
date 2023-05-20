Shader "Hidden/PostProcess/LutBuilder" {
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
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityInput.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
        #include "LutBuilderPass.hlsl"
        ENDHLSL

        Pass {
            name "LutBuilderLdr Pass"

            HLSLPROGRAM
            #pragma shader_feature _HDR_GRADING
            #pragma shader_feature _TONEMAP_ACES
            
            #pragma vertex vert
            #pragma fragment frag
            ENDHLSL
        }
    }
}