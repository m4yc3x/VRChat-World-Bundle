// **************************************************
// **************** Mayce's Shaders *****************
// **************************************************
// https://github.com/m4yc3x

Shader "Mayce/AudioLink/AudioLink_RaymarchA"
{
    Properties
    {
        [Header(Base Properties)]
        _MainTex ("Texture", 2D) = "white" {}
        _EmissionIntensity ("Emission Intensity", Range(0,10)) = 2
        
        [Header(Environment Properties)]
        _MaxSteps ("Max Ray Steps", Range(10,200)) = 100
        _MaxDistance ("Max Ray Distance", Range(10,100)) = 50
        _SurfaceDistance ("Surface Distance", Range(0.001,0.1)) = 0.01
        _EnvironmentScale ("Environment Scale", Range(0.1,10)) = 1
        
        [Header(Color Properties)]
        [HDR] _BaseColor ("Base Color", Color) = (0.2,0.4,0.8,1)
        [HDR] _SecondaryColor ("Secondary Color", Color) = (0.8,0.2,0.4,1)
        [HDR] _AccentColor ("Accent Color", Color) = (0.4,0.8,0.2,1)
        _ColorSpeed ("Color Speed", Range(0,2)) = 0.5
        _ColorBlend ("Color Blend", Range(0,1)) = 0.5
        _ColorDepth ("Color Depth", Range(0,2)) = 1.0
        
        [Header(Audio Properties)]
        _AudioSmoothing ("Audio Smoothing", Range(0,0.95)) = 0.8
        _BassIntensity ("Bass Intensity", Range(0,2)) = 0.7
        _MidIntensity ("Mid Intensity", Range(0,2)) = 0.6
        _TrebleIntensity ("Treble Intensity", Range(0,2)) = 0.5
        
        [Header(Light Properties)]
        _LightIntensity ("Light Intensity", Range(0,2)) = 1
        _ShadowSoftness ("Shadow Softness", Range(0,32)) = 16
        _AmbientLight ("Ambient Light", Range(0,1)) = 0.2
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
            #include "Packages/com.llealloo.audiolink/Runtime/Shaders/AudioLink.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 ro : TEXCOORD1;
                float3 hitPos : TEXCOORD2;
                UNITY_FOG_COORDS(3)
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _EmissionIntensity;
            float _MaxSteps;
            float _MaxDistance;
            float _SurfaceDistance;
            float _EnvironmentScale;
            float4 _BaseColor;
            float4 _SecondaryColor;
            float4 _AccentColor;
            float _ColorSpeed;
            float _ColorBlend;
            float _ColorDepth;
            float _AudioSmoothing;
            float _BassIntensity;
            float _MidIntensity;
            float _TrebleIntensity;
            float _LightIntensity;
            float _ShadowSoftness;
            float _AmbientLight;

            // Audio data smoothing
            float smoothAudioValue(float audioValue, float smoothing) {
                static float lastValue = 0;
                float smoothedValue = lerp(lastValue, audioValue, 1 - smoothing);
                lastValue = smoothedValue;
                return smoothedValue;
            }

            // Rotation matrix
            float2x2 rot2D(float angle) {
                float s = sin(angle);
                float c = cos(angle);
                return float2x2(c, -s, s, c);
            }

            // Signed Distance Functions
            float sdSphere(float3 p, float r) {
                return length(p) - r;
            }

            float sdBox(float3 p, float3 b) {
                float3 q = abs(p) - b;
                return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
            }

            float sdOctahedron(float3 p, float s) {
                p = abs(p);
                return (p.x + p.y + p.z - s) * 0.57735027;
            }

            // Smooth minimum function for soft blending
            float smin(float a, float b, float k) {
                float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
                return lerp(b, a, h) - k * h * (1.0 - h);
            }

            // Scene distance function
            float getDist(float3 p, float time, float4 audioData) {
                // Audio-reactive values
                float bassValue = smoothAudioValue(audioData.x, _AudioSmoothing) * _BassIntensity;
                float midValue = smoothAudioValue(audioData.y, _AudioSmoothing) * _MidIntensity;
                float trebleValue = smoothAudioValue(audioData.w, _AudioSmoothing) * _TrebleIntensity;
                
                // Offset the entire scene to be centered in view
                p.z -= 6; // Move scene forward
                p.y -= 1; // Adjust height to be centered
                
                // Create base environment
                float ground = p.y + 3.5; // Lower the ground plane
                
                // Create central structure
                float3 centralPos = p;
                centralPos.y -= sin(time * 0.5) * 0.3; // Reduce vertical movement
                float central = sdOctahedron(centralPos, 1.2 + bassValue * 0.5);
                
                // Create multiple rings of orbiting spheres
                float spheres = 9999;
                for(int ring = 0; ring < 3; ring++) {
                    float ringRadius = 3.0 + ring * 2.0; // Increase spacing between rings
                    float ringOffset = ring * 0.5;
                    
                    for(int i = 0; i < 8; i++) {
                        float angle = time * (0.2 + ring * 0.1) + i * 6.28 / 8 + ringOffset;
                        float height = cos(time * 0.3 + i + ring) * (0.8 + ring * 0.3);
                        float radius = ringRadius + sin(time + i) * 0.3 + midValue;
                        
                        float3 spherePos = float3(
                            sin(angle) * radius,
                            height,
                            cos(angle) * radius
                        );
                        
                        float sphereSize = 0.3 + trebleValue * 0.1 + ring * 0.1;
                        float sphere = sdSphere(p - spherePos, sphereSize);
                        spheres = smin(spheres, sphere, 0.5);
                    }
                }
                
                // Create multiple layers of floating boxes
                float boxes = 9999;
                for(int layer = 0; layer < 2; layer++) {
                    float layerHeight = layer * 2.0 - 0.5;
                    
                    for(int i = 0; i < 6; i++) {
                        float angle = time * 0.15 + i * 6.28 / 6 + layer;
                        float height = layerHeight + sin(time * 0.4 + i) * 0.7;
                        float radius = 4.5 + layer * 1.5; // Increase radius for better visibility
                        
                        float3 boxPos = float3(
                            sin(angle) * radius,
                            height,
                            cos(angle) * radius
                        );
                        
                        float3 boxSpacePos = p - boxPos;
                        float2x2 boxRot = rot2D(time * 0.5 + i);
                        boxSpacePos.xz = mul(boxRot, boxSpacePos.xz);
                        
                        float3 boxSize = float3(0.5, 0.5, 0.5) * (1.0 + midValue * 0.2);
                        float box = sdBox(boxSpacePos, boxSize);
                        boxes = smin(boxes, box, 0.3);
                    }
                }
                
                // Create audio-reactive pillars
                float pillars = 9999;
                for(int i = 0; i < 12; i++) {
                    float angle = i * 6.28 / 12;
                    float radius = 7.0; // Increase radius for better framing
                    
                    float3 pillarPos = float3(
                        sin(angle) * radius,
                        0,
                        cos(angle) * radius
                    );
                    
                    float pillarHeight = 2.5 + bassValue + sin(time * 0.5 + i) * 0.3;
                    float3 pillarSize = float3(0.25, pillarHeight, 0.25);
                    float pillar = sdBox(p - pillarPos, pillarSize);
                    pillars = smin(pillars, pillar, 0.2);
                }
                
                // Combine all elements with smooth blending
                float final = ground;
                final = smin(final, central, 1.0);
                final = smin(final, spheres, 0.5);
                final = smin(final, boxes, 0.8);
                final = smin(final, pillars, 0.3);
                
                return final * _EnvironmentScale;
            }

            // Get normal through numerical gradient
            float3 getNormal(float3 p, float time, float4 audioData) {
                float2 e = float2(0.01, 0);
                float3 n = getDist(p, time, audioData) - float3(
                    getDist(p - e.xyy, time, audioData),
                    getDist(p - e.yxy, time, audioData),
                    getDist(p - e.yyx, time, audioData)
                );
                return normalize(n);
            }

            // Ray marching function
            float rayMarch(float3 ro, float3 rd, float time, float4 audioData) {
                float dO = 0;
                
                for(int i = 0; i < _MaxSteps; i++) {
                    float3 p = ro + rd * dO;
                    float dS = getDist(p, time, audioData);
                    dO += dS;
                    if(dO > _MaxDistance || dS < _SurfaceDistance) break;
                }
                
                return dO;
            }

            // Lighting calculation
            float getLight(float3 p, float time, float4 audioData) {
                // Adjust light position for better scene illumination
                float3 lightPos = float3(3, 6, -4);
                lightPos.xz = mul(rot2D(time * 0.3), lightPos.xz);
                
                float3 l = normalize(lightPos - p);
                float3 n = getNormal(p, time, audioData);
                
                float diff = dot(n, l);
                diff = saturate(diff);
                
                // Soften shadows for better visibility
                float d = rayMarch(p + n * _SurfaceDistance * 2, l, time, audioData);
                if(d < length(lightPos - p)) diff *= smoothstep(0, 1, d / (_ShadowSoftness * 1.5));
                
                return diff;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                
                // Set up proper camera position and view direction
                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                // Position camera at a good viewing distance, slightly elevated
                o.ro = float3(0, 3, -12);
                o.hitPos = worldPos;
                
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // Initialize audio data
                float4 audioData = 0;
                
                if (AudioLinkIsAvailable())
                {
                    audioData = float4(
                        AudioLinkData(ALPASS_AUDIOBASS).r,
                        AudioLinkData(ALPASS_AUDIOLOWMIDS).r,
                        AudioLinkData(ALPASS_AUDIOHIGHMIDS).r,
                        AudioLinkData(ALPASS_AUDIOTREBLE).r
                    );
                }
                
                float time = _Time.y;
                
                // Calculate ray direction
                float3 ro = i.ro;
                float3 rd = normalize(i.hitPos - ro);
                
                // Perform ray marching
                float d = rayMarch(ro, rd, time, audioData);
                float3 p = ro + rd * d;
                
                // Calculate lighting
                float diff = getLight(p, time, audioData) * _LightIntensity + _AmbientLight;
                
                // Enhanced color calculations
                float bassColor = smoothAudioValue(audioData.x, 0.7) * _BassIntensity;
                float midColor = smoothAudioValue(audioData.y, 0.6) * _MidIntensity;
                float trebleColor = smoothAudioValue(audioData.w, 0.5) * _TrebleIntensity;
                
                // Position-based color variation
                float heightColor = (p.y + 2.0) * 0.2; // Subtle height-based coloring
                float distanceColor = length(p.xz) * 0.1; // Subtle distance-based coloring
                
                // Create smooth color transitions
                float colorPhase1 = sin(time * _ColorSpeed + distanceColor) * 0.5 + 0.5;
                float colorPhase2 = sin(time * _ColorSpeed * 0.7 + heightColor) * 0.5 + 0.5;
                
                // Blend between three colors based on position and audio
                float3 color1 = lerp(_BaseColor.rgb, _SecondaryColor.rgb, colorPhase1);
                float3 color2 = lerp(_SecondaryColor.rgb, _AccentColor.rgb, colorPhase2);
                
                // Create final base color with subtle audio influence
                float3 baseColor = lerp(color1, color2, 
                    saturate((bassColor * 0.3 + midColor * 0.2) * _ColorBlend));
                
                // Add depth-based color variation
                float depthFactor = saturate(d / (_MaxDistance * _ColorDepth));
                baseColor = lerp(baseColor, _BaseColor.rgb, depthFactor * 0.3);
                
                // Subtle color enhancement based on audio
                float audioEnhance = bassColor * 0.2 + midColor * 0.15 + trebleColor * 0.1;
                baseColor *= 1.0 + audioEnhance * _ColorBlend;
                
                // Apply distance fog with color tint
                float fog = 1.0 - saturate(d / _MaxDistance);
                float3 fogColor = lerp(_BaseColor.rgb * 0.5, baseColor, fog);
                
                // Final color
                float3 col = fogColor * diff;
                col *= _EmissionIntensity;
                
                // Subtle color correction
                col = saturate(col); // Prevent over-saturation
                
                fixed4 final = fixed4(col, 1);
                UNITY_APPLY_FOG(i.fogCoord, final);
                return final;
            }
            ENDCG
        }
    }
} 