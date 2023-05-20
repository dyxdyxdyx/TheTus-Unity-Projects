Shader "House Building" {
    Properties {
        _Width ("Width", Float) = 0.25
        _Height ("Height", Float) = 0.5
        [MainTexture] _MainTex ("Main Texture", 2D) = "white" {}
        }
    SubShader {
        Tags {
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
            "RenderType" = "Opaque"
        }
        Pass {
            Name "HouseBuilding Pass"

            HLSLPROGRAM
            // 几何着色器要求着色器版本4.0以上
            #pragma target 4.0

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "HouseBuildingPass.hlsl"

            #pragma vertex HouseBuildingPassVertex
            #pragma geometry HouseBuildingPassGeometry
            #pragma fragment HouseBuildingPassFragment
            ENDHLSL
        }
    }
}