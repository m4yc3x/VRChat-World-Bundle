// **************************************************
// ************* Mayce's Quest Shaders **************
// **************************************************
// https://github.com/m4yc3x

Shader "Mayce/AudioLink/AudioLinkC_FragmentOnly"
{
    Properties
    {
        [Header(Base Properties)]
        _MainTex ("Texture", 2D) = "blue" {}
        _EmissionIntensity ("Emission Intensity", Range(0,20)) = 1
        
        [Header(Color Properties)]
        _ColorA ("Color A", Color) = (1,0,0,1)  // Pure red
        _ColorB ("Color B", Color) = (0,1,0,1)  // Pure green
        _ColorC ("Color C", Color) = (0,0,1,1)  // Pure blue
        _ColorD ("Color D", Color) = (1,0,1,0)  // Pure magenta
        _ColorSpeed ("Color Cycle Speed", Range(0,2)) = 0.8
        _ColorMix ("Color Mix", Range(0,1)) = 0.5
        _GradientScale ("Gradient Scale", Range(0.1,5)) = 1
        
        [Header(Pattern Properties)]
        _PatternScale ("Pattern Scale", Range(0.1,50)) = 8
        _WarpSpeed ("Warp Speed", Range(0,5)) = 1
        _WarpStrength ("Warp Strength", Range(0,2)) = 0.8
        _PatternSharpness ("Pattern Sharpness", Range(1,10)) = 3
        
        [Header(Audio Reactivity)]
        _AudioThreshold ("Audio Threshold", Range(0,0.5)) = 0.05
        _AudioPower ("Audio Power", Range(0.1,4)) = 2
        _AudioReactivity ("Audio Reactivity", Range(0,1)) = 0.8
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        Cull Back

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
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float3 worldPos : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _EmissionIntensity;
            float4 _ColorA, _ColorB, _ColorC, _ColorD;
            float _ColorSpeed, _ColorMix, _GradientScale;
            float _PatternScale, _WarpSpeed, _WarpStrength;
            float _PatternSharpness;
            float _AudioThreshold, _AudioPower, _AudioReactivity;

            // Improved hash function
            float2 hash22(float2 p)
            {
                float3 p3 = frac(float3(p.xyx) * float3(.1031, .1030, .0973));
                p3 += dot(p3, p3.yzx + 33.33);
                return frac((p3.xx+p3.yz)*p3.zy);
            }

            // Smooth noise
            float2 noise2(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                
                // Quintic interpolation
                float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
                
                float2 a = hash22(i + float2(0,0));
                float2 b = hash22(i + float2(1,0));
                float2 c = hash22(i + float2(0,1));
                float2 d = hash22(i + float2(1,1));
                
                return lerp(lerp(a, b, u.x), lerp(c, d, u.x), u.y);
            }

            // Enhanced fractal noise with rotation
            float2 fractalNoise(float2 p, float time)
            {
                float2 value = 0;
                float amplitude = 1.0;
                float frequency = 1.0;
                
                // Get audio bass data
                float audioBass = 1.0;
                if (AudioLinkIsAvailable()) {
                    audioBass = 1.0 + AudioLinkData(ALPASS_AUDIOBASS).r * 2.0; // Scale bass influence
                }
                
                float2x2 rot = float2x2(cos(0.5), sin(0.5), -sin(0.5), cos(0.5));
                
                for(int i = 0; i < 4; i++)
                {
                    value += noise2(p * frequency + time) * amplitude;
                    amplitude *= 0.5;
                    frequency *= 2.0 * audioBass; // Multiply frequency by bass power
                    p = mul(rot, p);
                }
                
                return value;
            }

            // Color gradient function
            float3 getGradientColor(float t, float3 colorA, float3 colorB, float3 colorC, float3 colorD, float time)
            {
                // Create smooth transitions between colors
                float t1 = frac(t + time * _ColorSpeed * 0.5);
                float t2 = frac(t + time * _ColorSpeed * 0.3 + 0.33);
                float t3 = frac(t + time * _ColorSpeed * 0.7 + 0.66);
                
                // Smooth step for better gradients
                t1 = smoothstep(0.0, 1.0, t1);
                t2 = smoothstep(0.0, 1.0, t2);
                t3 = smoothstep(0.0, 1.0, t3);
                
                // Mix colors with different phases
                float3 color1 = lerp(colorA, colorB, t1);
                float3 color2 = lerp(colorB, colorC, t2);
                float3 color3 = lerp(colorC, colorD, t3);
                float3 color4 = lerp(colorD, colorA, t1);
                
                // Final color mix
                float3 finalColor = lerp(
                    lerp(color1, color2, t2),
                    lerp(color3, color4, t3),
                    t1
                );
                
                return finalColor;
            }

            float3 getTrippyPattern(float2 uv, float time, float4 audioData)
            {
                // Create warped coordinates
                float2 warpUV = uv * _PatternScale;
                float2 warp1 = fractalNoise(warpUV, time * _WarpSpeed);
                float2 warp2 = fractalNoise(warpUV * 1.5 + float2(0.5,0.8), time * _WarpSpeed * 0.8);
                
                // Apply audio reactivity to warping
                warp1 = warp1 * 2.0 - 1.0;
                warp2 = warp2 * 2.0 - 1.0;
                warp1 *= 1.0 + audioData.x;
                warp2 *= 1.0 + audioData.y;
                
                // Combine warps with different frequencies
                float2 finalWarp = warp1 * 0.7 + warp2 * 0.3;
                finalWarp *= _WarpStrength;
                
                // Generate base pattern
                float2 warpedUV = uv + finalWarp * (0.1 + audioData.z * 0.1);
                float2 basePattern = fractalNoise(warpedUV * _PatternScale, time);
                
                // Dynamic color cycling
                float timeScale = time * _ColorSpeed;
                float audioBoost = (audioData.x + audioData.y) * 0.5;
                
                // Create dynamic color cycles
                float3 colors[4];
                float3 baseColors[4] = {_ColorA.rgb, _ColorB.rgb, _ColorC.rgb, _ColorD.rgb};
                
                [unroll]
                for(int i = 0; i < 4; i++)
                {
                    float cyclePhase = timeScale + i * 1.57079632679; // Precise quarter pi
                    float3 colorShift = float3(
                        sin(cyclePhase),
                        sin(cyclePhase + 2.09439510239), // 2pi/3
                        sin(cyclePhase + 4.18879020479)  // 4pi/3
                    ) * 0.5 + 0.5; // Normalize to 0-1 range
                    
                    colors[i] = lerp(baseColors[i], colorShift, 0.7); // Mix with base color
                }
                
                // Create dynamic pattern value
                float2 center = float2(0.5, 0.5);
                float2 toCenter = uv - center;
                float angle = atan2(toCenter.y, toCenter.x) / (3.14159 * 2) + 0.5;
                float dist = length(toCenter) * 2.0;
                
                // Combine multiple pattern elements
                float patternValue = basePattern.x * 0.5 + basePattern.y * 0.5;
                patternValue += angle * 0.4;
                patternValue += sin(dist * 3.0 + timeScale) * 0.2;
                
                // Add time-based rotation to pattern
                float rotatingValue = frac(patternValue + timeScale * 0.3 + audioBoost * 0.2);
                
                // Create smooth color transitions
                float t = frac(rotatingValue * 4.0); // Cycle through all 4 colors
                int idx = int(rotatingValue * 4.0);
                float3 col1 = colors[idx % 4];
                float3 col2 = colors[(idx + 1) % 4];
                
                float3 finalColor = lerp(col1, col2, smoothstep(0.0, 0.8, t));
                
                // Add pattern variation
                float noisePattern = (basePattern.x + basePattern.y) * 0.5;
                finalColor *= 1.0 + (noisePattern - 0.5) * 0.2;
                
                // Add dark accents instead of highlights
                float darkBase = saturate(dist);
                float darkPattern = pow(darkBase + noisePattern * 0.2, _PatternSharpness);
                darkPattern *= (1.0 - audioData.w * 0.5); // Inverse audio reaction
                
                // Mix in dark accents
                float3 darkAccent = float3(0,0,0);
                finalColor = lerp(finalColor, darkAccent, darkPattern * 0.5);
                
                // Add audio-reactive color enhancement
                float3 audioColor = float3(
                    audioData.x,
                    audioData.y,
                    audioData.z
                ) * 0.15; // Reduced intensity
                
                finalColor *= 1.0 + audioColor;
                
                return saturate(finalColor);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float4 audioData = float4(0,0,0,0);
                float audioSum = 0;
                
                if (AudioLinkIsAvailable())
                {
                    audioData.x = AudioLinkData(ALPASS_AUDIOBASS).r;
                    audioData.y = AudioLinkData(ALPASS_AUDIOLOWMIDS).r;
                    audioData.z = AudioLinkData(ALPASS_AUDIOHIGHMIDS).r;
                    audioData.w = AudioLinkData(ALPASS_AUDIOTREBLE).r;
                    audioSum = audioData.x + audioData.y + audioData.z + audioData.w;
                }
                
                // Early out if no audio
                if (audioSum <= _AudioThreshold)
                {
                    return fixed4(0,0,0,1);
                }
                
                float time = _Time.y;
                float3 pattern = getTrippyPattern(i.uv, time, audioData);
                
                // Apply gentler audio reactivity
                float audioInfluence = pow(audioSum * 0.25, _AudioPower) * _AudioReactivity * 0.3;
                pattern *= 1.0 + audioInfluence;
                
                // Create final color with controlled intensity
                fixed4 col = fixed4(pattern, 1);
                col.rgb *= _EmissionIntensity;
                
                // Apply texture
                fixed4 texColor = tex2D(_MainTex, i.uv);
                col *= texColor;
                
                // Final intensity control
                col.rgb = saturate(col.rgb);
                
                // Apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
    
    FallBack "Unlit/Texture"
    CustomEditor "ShaderGUI"
} 