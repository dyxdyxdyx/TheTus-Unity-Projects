Shader "My Shader/Unlit LDR" {
    Properties {
       [MainColor] _MainColor ("Main Color", Color) = (1.0, 1.0, 1.0, 1.0)
    }
    SubShader {
        Tags {
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
            "RenderType" = "Opaque"
        }

        Pass {
            Name "Unlit LDR"
            Tags {
                "Light Mode" = "UniversalForward"
            }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes {
                float4 positionOS : POSITION;
            };

            struct Varyings {
                float4 positionCS : SV_POSITION;
            };

            CBUFFER_START(UnityPerMaterial)
            float3 _MainColor;
            CBUFFER_END

            Varyings vert(Attributes input) {
                Varyings output = (Varyings)0;

                VertexPositionInputs vertexInputs = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vertexInputs.positionCS;

                return output;
            }

            half4 frag(Varyings input) : SV_Target {
                return half4(_MainColor.rgb, 1.0);
            }
            ENDHLSL
        }
    }
}