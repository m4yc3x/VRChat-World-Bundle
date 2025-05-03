// **************************************************
// ************* Mayce's Quest Shaders **************
// **************************************************
// https://github.com/m4yc3x

Shader "Mayce/AudioLink/AudioLinkE_Vertex" {
    Properties {
        _Color1 ("Color1", Color) = (1,1,1,1)
        _Color2 ("Color2", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "blue" {}
        _Ramp ("Ramp (RGB)", 2D) = "red" {}
        _Normal ("Normal", 2D) = "bump" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
        _Noise ("Noise", 2D) = "red" {}

        _Edge ("Edge Size", Float) = 1.0
        _Fog ("Fog", Float) = 1.0
        _Fade ("Edge Fade", Float) = 1.0
        
        [Header(Audio Reactivity)]
        _AudioReactivity ("Audio Reactivity", Range(0,1)) = 0.8
        _AudioPower ("Audio Power", Range(0.1,5)) = 2.0
        _AudioSpeed ("Audio Speed Influence", Range(0,2)) = 1.0
        _AudioNormal ("Audio Normal Influence", Range(0,2)) = 1.0
        _AudioColor ("Audio Color Influence", Range(0,2)) = 1.0
    }
    SubShader {
        Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" }
        LOD 200

        GrabPass { }

        CGPROGRAM
        #pragma surface surf Standard noshadow nolightmap vertex:vert alpha:blend
        #pragma target 3.0

        #include "Packages/com.llealloo.audiolink/Runtime/Shaders/AudioLink.cginc"

        sampler2D _MainTex, _Normal, _Ramp, _Noise;
        UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

        struct Input {
            float2 uv_MainTex;
            float2 uv_Normal;
            float4 projPos;
            float4 grabPos;
            float3 worldPos;
            float2 localDir;
            float3 worldRefl;
            float4 screenPos;
            float3 viewDir;
            float depth;
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _Color1, _Color2;
        half _Edge, _Fade, _Fog;
        float _AudioReactivity, _AudioPower, _AudioSpeed, _AudioNormal, _AudioColor;

        UNITY_INSTANCING_BUFFER_START(Props)
        UNITY_INSTANCING_BUFFER_END(Props)

        inline float InverseLerp(float a, float b, float value)
        {
            return saturate((value - a) / (b - a));
        }

        // Audio data processing
        float4 GetAudioData()
        {
            float4 audioData = float4(0,0,0,0);
            if (AudioLinkIsAvailable())
            {
                audioData.x = AudioLinkData(ALPASS_AUDIOBASS).r;
                audioData.y = AudioLinkData(ALPASS_AUDIOLOWMIDS).r;
                audioData.z = AudioLinkData(ALPASS_AUDIOHIGHMIDS).r;
                audioData.w = AudioLinkData(ALPASS_AUDIOTREBLE).r;
            }
            return pow(audioData * _AudioReactivity, _AudioPower);
        }

        void vert (inout appdata_full v, out Input o) {
            UNITY_INITIALIZE_OUTPUT(Input,o);

            o.localDir = v.vertex.xz;
            float4 vertex = UnityObjectToClipPos(v.vertex);
            o.projPos = ComputeScreenPos(vertex);
            COMPUTE_EYEDEPTH(o.projPos.z);
            o.grabPos = ComputeGrabScreenPos(vertex);
            float4 worldPos = mul(unity_ObjectToWorld, v.vertex);
            float3 relPos = worldPos.xyz - _WorldSpaceCameraPos.xyz;
            o.depth = length(relPos);
        }

        void surf (Input IN, inout SurfaceOutputStandard o) {
            float4 audioData = GetAudioData();
            float audioSum = (audioData.x + audioData.y + audioData.z + audioData.w) * 0.25;
            
            // Scene depth calculations with audio influence
            float sceneZ = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(IN.projPos)));
            float partZ = IN.projPos.z;
            float zDiff = abs(sceneZ-partZ);
            float edge = InverseLerp(_Edge * (1 + audioSum * _AudioReactivity), 0, zDiff);
            float fog = 1-InverseLerp(_Fog * (1 + audioData.x * _AudioReactivity), 0, zDiff);
            float fade = InverseLerp(_Fade, 0, zDiff);

            // Audio-reactive UV animation
            float2 UV2 = IN.uv_Normal;
            float timeScale = _Time.y * (1 + audioSum * _AudioSpeed);
            UV2.x += timeScale * 0.2;
            UV2.y += timeScale * 0.1;
            UV2 *= 0.5;
            
            // Normal mapping with audio influence
            float3 normal = UnpackScaleNormal(tex2D(_Normal, UV2), 1 + audioSum * _AudioNormal);

            float2 UV = IN.uv_MainTex;
            UV.y += timeScale * 0.2;
            UV += normal * (0.2 + audioData.y * 0.1);

            float2 UV3 = IN.uv_MainTex;
            UV3.y += timeScale;
            UV3 += normal * (1 + audioData.z * 0.2);

            float noiseTex = tex2D(_Noise, UV3 * 0.2);
            float blend = tex2D(_MainTex, UV).r;
            
            // Color blending with audio reactivity
            fixed4 c = tex2D(_Ramp, float2(blend, 0));
            fixed4 audioColor = lerp(_Color1, _Color2, audioSum * _AudioColor);
            c = lerp(c, audioColor, edge);
            
            float FogEdge = smoothstep(noiseTex, noiseTex + 1, fog);
            fixed4 fogc = lerp(_Color2, _Color1, fog * FogEdge);
            c += fogc;
            
            // Audio-reactive emission and roughness
            fixed4 emission = lerp(0, audioColor, pow(blend, 2) * (1 + audioSum));
            fixed roughness = lerp(1, 0, blend + audioSum * 0.2);

            o.Albedo = c.rgb;
            o.Metallic = _Metallic;
            o.Normal = normal;
            o.Smoothness = roughness * _Glossiness;
            o.Emission = emission.rgb * audioSum * _AudioColor;
            
            float distanceAlpha = 1-InverseLerp(0.5*0.7, 0.5, IN.depth);
            o.Alpha = 1-fade;
        }
        ENDCG
    }
    FallBack "Diffuse"
} 