Shader "Unlit/WispOrb"
{
    Properties
    {
        _MainColor ("Main Color", Color) = (0.5, 0.8, 1.0, 1.0)
        _EmissionColor ("Emission Color", Color) = (0.5, 0.8, 1.0, 1.0)
        _EmissionStrength ("Emission Strength", Range(0, 5)) = 2.0
        _PulseSpeed ("Pulse Speed", Range(0, 5)) = 1.0
        _FresnelPower ("Fresnel Power", Range(0, 10)) = 2.0
        _Alpha ("Alpha", Range(0, 1)) = 0.8
    }
    SubShader
    {
        Tags { 
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
            "VRCFallback" = "Hidden"
        }
        LOD 100

        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float3 worldNormal : TEXCOORD2;
                float3 viewDir : TEXCOORD3;
            };

            float4 _MainColor;
            float4 _EmissionColor;
            float _EmissionStrength;
            float _PulseSpeed;
            float _FresnelPower;
            float _Alpha;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                
                // Calculate view direction and normal
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.viewDir = normalize(_WorldSpaceCameraPos - worldPos);
                
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // Calculate fresnel effect
                float fresnel = pow(1.0 - saturate(dot(normalize(i.worldNormal), normalize(i.viewDir))), _FresnelPower);
                
                // Create pulsing effect
                float pulse = (sin(_Time.y * _PulseSpeed) * 0.5 + 0.5);
                
                // Combine colors and effects
                fixed4 col = _MainColor;
                col.rgb += _EmissionColor.rgb * _EmissionStrength * (fresnel + pulse);
                col.a = _Alpha * (fresnel + 0.5);
                
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
