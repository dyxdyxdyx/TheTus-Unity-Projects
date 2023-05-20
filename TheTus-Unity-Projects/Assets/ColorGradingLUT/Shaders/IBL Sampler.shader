Shader "My Shader/BlinnPhong IBL" {
    Properties {
        _Gloss ("Gloss", Range(1.0, 255.0)) = 30.0
        _FresnelPow ("Fresnel Pow", Range(0.0, 5.0)) = 1.0
    }
    SubShader {
        Tags {
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
            "RenderType" = "Opaque"
        }

        Pass {
            Name "IBL Sampler"

            Tags {
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
            };

            CBUFFER_START(UnityPerMaterial)
            float _Gloss;
            float _FresnelPow;
            CBUFFER_END

            Varyings vert(Attributes input) {
                Varyings output = (Varyings)0;

                VertexPositionInputs vertexInputs = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS);
                output.positionCS = vertexInputs.positionCS;
                output.positionWS = vertexInputs.positionWS;
                output.normalWS = normalInputs.normalWS;

                return output;
            }

            half4 frag(Varyings input) : SV_Target {
                half3 vDirWS = normalize(GetWorldSpaceViewDir(input.positionWS));
                half3 nDirWS = normalize(input.normalWS);
                half3 rDirWS = reflect(-vDirWS, nDirWS);

                // 获取光源信息
                Light light = GetMainLight();
                // 计算blinnphong
                half3 diffuse = LightingLambert(light.color, light.direction, nDirWS);
                half3 specular = LightingSpecular(light.color, light.direction, nDirWS, vDirWS, (1.0, 1.0, 1.0, 1.0), _Gloss);

                half4 var_Cubemap = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, rDirWS, (255.0-_Gloss)*8.0/255.0);
                half3 DecodeEnv = DecodeHDREnvironment(var_Cubemap, unity_SpecCube0_HDR);
                // half3 DecodeEnv = var_Cubemap.rgb;
                half fresnel = pow(1.0 - saturate(dot(vDirWS, nDirWS)), _FresnelPow);

                half3 finalCol = specular + DecodeEnv * fresnel;

                return half4(finalCol, 1.0);
            }
            ENDHLSL
        }
    }
}