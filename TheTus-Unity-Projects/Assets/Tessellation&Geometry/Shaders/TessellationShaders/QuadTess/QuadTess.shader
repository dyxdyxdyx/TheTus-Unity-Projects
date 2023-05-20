Shader "My Shader/TESS&GS/QuadTess" {
    Properties {

    }
    SubShader {
        Tags {
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
            "RenderType" = "Opaque"
        }
        Pass {
            Name "TessTest Pass"
            
            Cull Off

            HLSLPROGRAM
            // 几何着色器仅支持着色器版本4.0以上
            #pragma target 4.6

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "QuadTess.hlsl"

            #pragma vertex QuadTessPassVertex
            #pragma hull QuadTessPassHull
            #pragma domain QuadTessPassDomain
            #pragma geometry QuadTessPassGeometry
            #pragma fragment QuadTessPassFragment
            ENDHLSL
        }
    }
}