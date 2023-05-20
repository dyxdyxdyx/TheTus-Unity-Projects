Shader "My Shader/TESS&GS/Control Point" {
    Properties {
        [MainColor] _MainCol ("Main Color", Color) = (1.0, 1.0, 1.0, 1.0)
        }
    SubShader {
        Tags {
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
        }
        Pass {
		Name "Pass"
            ZTest Always

            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "ControlPointPass.hlsl"

            #pragma vertex ControlPointPassVertex
            #pragma fragment ControlPointPassFragment
            ENDHLSL
        }
    }
}