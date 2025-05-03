// **************************************************
// ************* Mayce's Quest Shaders **************
// **************************************************
// https://github.com/m4yc3x

Shader "Mayce/AudioLink/AudioLinkG_Vertex"
{
    Properties
    {
        [Header(Base Properties)]
        _MainTex ("Texture", 2D) = "white" {}
        _EmissionStrength ("Emission Strength", Range(0,5)) = 1.5
        
        [Header(Distortion)]
        _DistortionScale ("Distortion Scale", Range(0.1,10)) = 3.0
        _DistortionSpeed ("Distortion Speed", Range(0,2)) = 0.8
        _DistortionIntensity ("Distortion Intensity", Range(0,2)) = 1.0
        _LayerCount ("Layer Count", Range(1,3)) = 2
        
        [Header(Visual Flow)]
        _FlowScale ("Flow Scale", Range(0.1,10)) = 2.0
        _FlowSpeed ("Flow Speed", Range(0,2)) = 0.5
        _TurbulenceAmount ("Turbulence", Range(0,2)) = 0.7
        
        [Header(Color Settings)]
        [HDR] _PrimaryColor ("Primary Color", Color) = (0.1, 0.4, 0.8, 1)
        [HDR] _SecondaryColor ("Secondary Color", Color) = (0.7, 0.1, 0.5, 1)
        [HDR] _AccentColor ("Accent Color", Color) = (0.0, 0.8, 0.9, 1)
        _ColorCycleSpeed ("Color Cycle Speed", Range(0,1)) = 0.3
        _ColorBlend ("Color Blend", Range(0,1)) = 0.7
        
        [Header(Audio Reactivity)]
        _BassImpact ("Bass Impact", Range(0,2)) = 1.0
        _MidImpact ("Mid Impact", Range(0,1)) = 0.6
        _HighImpact ("High Impact", Range(0,1)) = 0.4
        _AudioReactivity ("Overall Reactivity", Range(0,1)) = 0.8
        _AudioThreshold ("Audio Threshold", Range(0,0.3)) = 0.05
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
            #pragma target 3.0
            #pragma multi_compile_instancing

            #include "UnityCG.cginc"
            #include "Packages/com.llealloo.audiolink/Runtime/Shaders/AudioLink.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float3 worldPos : TEXCOORD2;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _EmissionStrength;
            
            float _DistortionScale, _DistortionSpeed, _DistortionIntensity, _LayerCount;
            float _FlowScale, _FlowSpeed, _TurbulenceAmount;
            
            float4 _PrimaryColor, _SecondaryColor, _AccentColor;
            float _ColorCycleSpeed, _ColorBlend;
            
            float _BassImpact, _MidImpact, _HighImpact;
            float _AudioReactivity, _AudioThreshold;

            // Fast hash function
            float hash(float2 p)
            {
                float3 p3 = frac(float3(p.xyx) * float3(443.897, 441.423, 437.195));
                p3 += dot(p3, p3.yzx + 19.19);
                return frac((p3.x + p3.y) * p3.z);
            }

            // Optimized 2D simplex noise
            float snoise(float2 v) {
                // Precomputed values
                const float2 C = float2(0.211324865405187, 0.366025403784439);
                const float2 D = float2(0.366025403784439, 0.211324865405187);
                
                // First corner
                float2 i = floor(v + dot(v, C.yy));
                float2 x0 = v - i + dot(i, C.xx);
                
                // Other corners
                float2 i1 = (x0.x > x0.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
                float2 x1 = x0 - i1 + C.xx;
                float2 x2 = x0 - 1.0 + 2.0 * C.xx;
                
                // Calculate weights
                float3 m = max(0.5 - float3(dot(x0, x0), dot(x1, x1), dot(x2, x2)), 0.0);
                m = m * m * m * m; // 4th power for better gradient
                
                // Generate noise
                float3 h = frac(float3(127.231, 311.673, 74.616) * 
                            frac(float3(dot(i, float2(127.1, 311.7)), 
                                     dot(i + i1, float2(127.1, 311.7)), 
                                     dot(i + 1.0, float2(127.1, 311.7)))));
                
                // Calculate gradients
                float3 gx = 2.0 * frac(h * 43758.5453) - 1.0;
                float3 gy = 2.0 * frac(h * 22578.1459) - 1.0;
                
                // Compute dot products
                float2 grad0 = float2(gx.x, gy.x) * x0;
                float2 grad1 = float2(gx.y, gy.y) * x1;
                float2 grad2 = float2(gx.z, gy.z) * x2;
                
                // Final noise value (scaled to -1 to 1 range)
                return 40.0 * dot(m, float3(dot(grad0.xy, x0), 
                                         dot(grad1.xy, x1), 
                                         dot(grad2.xy, x2)));
            }

            // Fast fractional Brownian motion (fBm) that limits iterations
            float fbm(float2 p, float octaves) {
                float value = 0.0;
                float amplitude = 0.5;
                float frequency = 1.0;
                
                // Using min function keeps shader performance high even with high octave settings
                int iters = min(int(octaves), 4);
                
                UNITY_UNROLL
                for (int i = 0; i < 4; i++) {
                    if (i >= iters) break;
                    value += amplitude * snoise(p * frequency);
                    amplitude *= 0.5;
                    frequency *= 2.0;
                }
                
                return value * 0.5 + 0.5; // Normalize to 0-1
            }

            // Multi-layer domain warping optimized for performance
            float2 flowDistortion(float2 uv, float time, float4 audio) {
                // Calculate audio-reactive parameters
                float bassIntensity = audio.x * _BassImpact;
                float midIntensity = audio.y * _MidImpact;
                
                // Start with base UV
                float2 distortedUV = uv;
                
                // Layer 1 - large scale movement
                float2 noise1 = float2(
                    snoise(float2(uv.x * 0.5 + time * 0.3, uv.y * 0.7 - time * 0.1)),
                    snoise(float2(uv.x * 0.7 - time * 0.1, uv.y * 0.5 + time * 0.2))
                );
                
                // Apply first distortion layer
                distortedUV += noise1 * _DistortionIntensity * (1.0 + bassIntensity);
                
                // Only calculate additional layers if needed (based on quality setting)
                if (_LayerCount > 1) {
                    // Layer 2 - medium scale detail
                    float2 noise2 = float2(
                        snoise(distortedUV * 1.6 + float2(time * 0.15, -time * 0.13)),
                        snoise(distortedUV * 1.7 + float2(-time * 0.13, time * 0.15))
                    );
                    
                    // Apply second distortion layer with mid-frequency influence
                    distortedUV += noise2 * _DistortionIntensity * 0.1 * (1.0 + midIntensity * 0.8);
                    
                    // Layer 3 - fine detail (highest quality)
                    if (_LayerCount > 2) {
                        float2 noise3 = float2(
                            snoise(distortedUV * 3.0 + float2(time * 0.3, time * 0.2)),
                            snoise(distortedUV * 2.8 + float2(time * 0.2, -time * 0.3))
                        );
                        
                        // Apply third layer with subtle high frequency influence
                        distortedUV += noise3 * _DistortionIntensity * 0.25 * (1.0 + audio.z * _HighImpact);
                    }
                }
                
                return distortedUV;
            }
            
            // HSV to RGB conversion
            float3 hsv2rgb(float3 c) {
                float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
                float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
                return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
            }
            
            // Improved audio-reactive color generation
            float3 getHyperColors(float2 uv, float time, float4 audio) {
                // Sample AudioLink history for changing colors based on audio dynamics
                float4 audioHistory;
                audioHistory.x = AudioLinkData(ALPASS_AUDIOLINK + int2(0, 15)).r; // Bass from 15 frames ago
                audioHistory.y = AudioLinkData(ALPASS_AUDIOLINK + int2(1, 10)).r; // Low mids from 10 frames ago
                audioHistory.z = AudioLinkData(ALPASS_AUDIOLINK + int2(2, 5)).r;  // High mids from 5 frames ago
                audioHistory.w = AudioLinkData(ALPASS_AUDIOLINK + int2(3, 2)).r;  // Treble from 2 frames ago
                
                // Calculate audio dynamics (changes over time)
                float4 audioDelta = abs(audio - audioHistory);
                float audioChange = saturate(dot(audioDelta, float4(1.0, 0.8, 0.6, 0.4)));
                
                // Base hue that cycles over time, modified by audio changes
                float timeScale = time * _ColorCycleSpeed;
                
                // Make hue shift respond to audio changes - more change = faster cycling
                float dynamicSpeed = 1.0 + audioChange * 5.0;
                
                // Primary hues with audio-reactive phase shifts
                float hue1 = frac(timeScale * 0.1 * dynamicSpeed + audio.x * 0.2);
                float hue2 = frac(timeScale * 0.1 * dynamicSpeed + 0.33 + audio.y * 0.15);
                float hue3 = frac(timeScale * 0.1 * dynamicSpeed + 0.66 + audio.z * 0.1);
                
                // Audio-reactive color modifications
                float bassEffect = audio.x * _BassImpact;
                float midEffect = audio.y * _MidImpact;
                float highEffect = audio.z * _HighImpact;
                
                // Add frequency-specific modulations to color properties
                float saturation1 = 0.8 + audioDelta.x * 0.5;
                float saturation2 = 0.9 + audioDelta.y * 0.4;
                float saturation3 = 1.0 + audioDelta.z * 0.3;
                
                float value1 = 1.0 + audioChange * 0.5;
                float value2 = 1.0 + audioChange * 0.7;
                float value3 = 1.0 + audioChange * 0.9;
                
                // Generate primary colors with enhanced audio reactivity
                float3 color1 = lerp(_PrimaryColor.rgb, hsv2rgb(float3(hue1, saturation1, value1)), _ColorBlend);
                float3 color2 = lerp(_SecondaryColor.rgb, hsv2rgb(float3(hue2, saturation2, value2)), _ColorBlend);
                float3 color3 = lerp(_AccentColor.rgb, hsv2rgb(float3(hue3, saturation3, value3)), _ColorBlend);
                
                // Add brief bright flashes on bass transients
                if (audioDelta.x > 0.4) {
                    float flashIntensity = audioDelta.x - 0.4;
                    color1 += flashIntensity * 0.5;
                    color2 += flashIntensity * 0.3;
                    color3 += flashIntensity * 0.4;
                }
                
                // Additional audio-reactive brightness
                color1 *= 1.0 + bassEffect * 0.5;
                color2 *= 1.0 + midEffect * 0.7;
                color3 *= 1.0 + highEffect * 0.9;
                
                // Create pattern for color mixing, modulated by audio
                float pattern = fbm(uv * _FlowScale + flowDistortion(uv, time * 0.3, audio) * 0.5, _LayerCount);
                pattern = saturate(pattern);
                
                // Add sudden pattern shifts during audio transients
                if (audioChange > 0.2) {
                    float transientShift = (hash(float2(time, audio.x + audio.y)) * 2.0 - 1.0) * (audioChange - 0.2);
                    pattern = saturate(pattern + transientShift * 0.2);
                }
                
                // Mix colors based on pattern with dynamic transitions
                float transitionEdge = lerp(0.33, 0.4, audio.y * 0.5);
                float3 finalColor;
                
                if (pattern < transitionEdge) {
                    finalColor = lerp(color1, color2, pattern / transitionEdge);
                } 
                else if (pattern < transitionEdge * 2.0) {
                    finalColor = lerp(color2, color3, (pattern - transitionEdge) / transitionEdge);
                }
                else {
                    finalColor = lerp(color3, color1, (pattern - transitionEdge * 2.0) / (1.0 - transitionEdge * 2.0));
                }
                
                // Add audio-reactive highlights
                float highlight = pow(pattern, 3.0) * audio.w;
                finalColor += color3 * highlight * highEffect;
                
                // Apply audio dynamics as color vibrance
                finalColor = lerp(dot(finalColor, float3(0.299, 0.587, 0.114)), finalColor, 1.0 + audioChange * 0.5);
                
                return finalColor;
            }
            
            // Main visualization function
            float3 createVisualization(float2 uv, float time, float4 audio) {
                // Apply main flow distortion
                float2 distortedUV = flowDistortion(uv * _DistortionScale, time * _DistortionSpeed, audio);
                
                // Generate base flow pattern
                float flowPattern = fbm(distortedUV * _FlowScale, _LayerCount);
                
                // Generate detailed noise for dark line patterns
                float darkLinePattern1 = snoise(distortedUV * (_FlowScale * 2.5) + float2(time * 0.3, time * -0.2)) * 0.5 + 0.5;
                float darkLinePattern2 = snoise(distortedUV * (_FlowScale * 1.7) + float2(time * -0.2, time * 0.25)) * 0.5 + 0.5;
                
                // Create sharp transitions for dark lines
                float darkLines = smoothstep(0.45, 0.55, darkLinePattern1) * smoothstep(0.45, 0.55, darkLinePattern2);
                darkLines = 1.0 - darkLines * 0.8; // Invert and scale for darkness
                
                // Apply audio-reactive turbulence
                float bassResponse = saturate((audio.x - _AudioThreshold) / (1.0 - _AudioThreshold));
                float turbulence = 0.0;
                
                if (bassResponse > 0.1) {
                    // Dynamic turbulence based on bass
                    float turbAmt = _TurbulenceAmount * bassResponse;
                    turbulence = snoise(uv * (_FlowScale * 2.0) + time * (_FlowSpeed * 2.0)) * turbAmt;
                    
                    // Add rotating gradient ripples during strong bass hits
                    if (bassResponse > 0.5) {
                        // Create rotating UV coordinates
                        float2 rotatedUV = uv - 1.9;
                        float2x2 rotMat = float2x2(cos(time * 8.0), -sin(time * 8.0), 
                                                  sin(time * 8.0), cos(time * 8.0));
                        rotatedUV = mul(rotMat, rotatedUV);
                        float dist = length(rotatedUV) * 100.0;
                        
                        // Create smooth gradient ripples
                        float ripple = sin(dist - time * 5.0 * bassResponse);
                        ripple = pow(ripple * 0.5 + 0.5, 0.7); // Smoothen transition
                        ripple *= smoothstep(1.0, 0.0, dist / 3.0); // Fade out
                        turbulence = lerp(turbulence, ripple, bassResponse - 0.5);
                        
                        // Create additional gradient ripples that rotate in opposite direction
                        rotMat = float2x2(cos(-time * 6.0), -sin(-time * 6.0),
                                        sin(-time * 6.0), cos(-time * 6.0));
                        rotatedUV = mul(rotMat, uv - 0.5);
                        dist = length(rotatedUV) * 80.0;
                        float darkRipple = sin(dist - time * 3.0 * bassResponse);
                        darkRipple = pow(darkRipple * 0.5 + 0.5, 0.8);
                        darkLines *= 1.0 - darkRipple * bassResponse * 0.5;
                    }
                }
                
                // Create thinner dark lines based on distortion gradient
                float2 gradientUV = float2(
                    snoise(distortedUV * (_FlowScale * 3.0) + float2(0.0, time * 0.4)),
                    snoise(distortedUV * (_FlowScale * 3.0) + float2(time * 0.4, 0.0))
                );
                
                float gradientLines = max(
                    smoothstep(0.48, 0.52, frac(gradientUV.x * 4.0)),
                    smoothstep(0.48, 0.52, frac(gradientUV.y * 4.0))
                );
                
                // Apply gradient lines with audio reactivity - stronger on mid frequencies
                darkLines *= 1.0 - gradientLines * 0.6 * (1.0 + audio.y * _MidImpact);
                
                // Combine base pattern with turbulence
                float finalPattern = lerp(flowPattern, turbulence, bassResponse * 0.5);
                
                // Get colors based on pattern and audio
                float3 colors = getHyperColors(distortedUV, time, audio);
                
                // Apply pattern edge enhancement
                float edge = max(0, 1.0 - abs(finalPattern * 2.0 - 1.0) * 8.0);
                edge = pow(edge, 1.0 + audio.z * 5.0); // Sharpen edges with high frequencies
                
                // Create dark edges with high-frequency audio reactivity
                float darkEdges = pow(1.0 - edge, 2.0) * (0.7 + audio.z * _HighImpact * 0.5);
                darkLines *= 1.0 - darkEdges * 0.5;
                
                // Combine colors with pattern and apply dark lines
                float3 finalColor = colors * (0.4 + finalPattern * 0.6) * darkLines;
                
                // Add edge highlights with accent color (slightly reduced to balance darkness)
                finalColor += _AccentColor.rgb * edge * (0.8 + audio.z * _HighImpact * 1.5);
                
                return finalColor;
            }

            v2f vert (appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                
                // Audio-reactive vertex displacement
                float4 audioData = float4(0,0,0,0);
                if (AudioLinkIsAvailable())
                {
                    audioData.x = AudioLinkData(ALPASS_AUDIOBASS).r;
                    
                    // Only apply displacement if bass exceeds threshold
                    if (audioData.x > _AudioThreshold * 2.0)
                    {
                        // Apply minimal displacement
                        float displacement = (audioData.x - _AudioThreshold * 2.0) * 0.1 * _AudioReactivity;
                        v.vertex.xyz += v.normal * displacement;
                    }
                }
                
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                
                // Check if AudioLink is available
                if (!AudioLinkIsAvailable())
                {
                    // Return black when audio is not available
                    return fixed4(0, 0, 0, 1);
                }
                
                // Sample AudioLink data
                float4 audioData;
                audioData.x = AudioLinkData(ALPASS_AUDIOBASS).r;
                audioData.y = AudioLinkData(ALPASS_AUDIOLOWMIDS).r;
                audioData.z = AudioLinkData(ALPASS_AUDIOHIGHMIDS).r;
                audioData.w = AudioLinkData(ALPASS_AUDIOTREBLE).r;
                
                // Early out if there's no significant audio
                float audioSum = audioData.x + audioData.y + audioData.z + audioData.w;
                if (audioSum < _AudioThreshold * 4.0)
                {
                    // Return black when audio is too low
                    return fixed4(0, 0, 0, 1);
                }
                
                // Create audio-reactive visualization
                float time = _Time.y;
                float3 visualColor = createVisualization(i.uv, time, audioData);
                
                // Apply texture
                float4 texColor = tex2D(_MainTex, i.uv);
                
                // Final color with emission
                float3 finalColor = visualColor * texColor.rgb * _EmissionStrength;
                
                // Scale by overall audio reactivity
                float reactivity = 1.0 + audioSum * 0.25 * _AudioReactivity;
                finalColor *= reactivity;
                
                // Apply fog
                fixed4 col = fixed4(finalColor, 1);
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
    FallBack "Unlit/Texture"
} 