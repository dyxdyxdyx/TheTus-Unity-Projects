Shader "My Shader/TESS&GS/Flat Wireframe Deriv" {
    Properties {
        [MainColor] _MainCol ("Main Color", Color) = (1.0, 1.0, 1.0, 1.0)

    }
    SubShader {
        Tags {
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
            "RenderType" = "Opaque"
        }
        Pass {
            Name "FlatWireframe Pass"

            Tags {
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM
            #pragma target 3.0

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "FlatWireframeDerivePass.hlsl"

            #pragma vertex FlatWireframePassVertex
            #pragma fragment FlatWireframePassFragment
            ENDHLSL
        }
    }
}