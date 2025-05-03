// **************************************************
// ************* Mayce's Quest Shaders **************
// **************************************************
// https://github.com/m4yc3x

Shader "Mayce/AudioLink/AudioLinkH_Vertex"
{
    Properties
    {
        [Header(Base Properties)]
        _MainTex ("Texture", 2D) = "white" {}
        _EmissionStrength ("Emission Strength", Range(0,5)) = 1.5
        
        [Header(Organic Pattern)]
        _PatternScale ("Pattern Scale", Range(0.1, 10)) = 3.0
        _PatternSpeed ("Pattern Speed", Range(0, 2)) = 0.5
        _PatternDetail ("Pattern Detail", Range(1, 5)) = 2
        _OrganicEdge ("Organic Edge", Range(0, 1)) = 0.7
        _TurbulenceAmount ("Turbulence", Range(0, 2)) = 0.8
        
        [Header(Liquid Flow)]
        _FlowSpeed ("Flow Speed", Range(0, 2)) = 0.7
        _FlowAmplitude ("Flow Amplitude", Range(0, 1)) = 0.4
        _WavesScale ("Waves Scale", Range(1, 20)) = 8
        _WaveSpeed ("Wave Speed", Range(0, 2)) = 0.6
        
        [Header(Color Settings)]
        [HDR] _PrimaryColor ("Primary Color", Color) = (0.1, 0.3, 0.8, 1)
        [HDR] _SecondaryColor ("Secondary Color", Color) = (0.0, 0.5, 0.9, 1)
        [HDR] _AccentColor ("Accent Color", Color) = (0.0, 0.8, 1.0, 1)
        _ColorCycleSpeed ("Color Cycle Speed", Range(0, 1)) = 0.3
        _GradientScale ("Gradient Scale", Range(0.1, 5)) = 1.2
        
        [Header(Audio Reactivity)]
        _BassImpact ("Bass Impact", Range(0, 2)) = 1.0
        _MidImpact ("Mid Impact", Range(0, 1)) = 0.6
        _HighImpact ("High Impact", Range(0, 1)) = 0.4
        _AudioReactivity ("Overall Reactivity", Range(0, 1)) = 0.8
        _AudioThreshold ("Audio Threshold", Range(0, 0.3)) = 0.05
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
            float _EmissionStrength;
            
            float _PatternScale, _PatternSpeed, _PatternDetail;
            float _OrganicEdge, _TurbulenceAmount;
            
            float _FlowSpeed, _FlowAmplitude;
            float _WavesScale, _WaveSpeed;
            
            float4 _PrimaryColor, _SecondaryColor, _AccentColor;
            float _ColorCycleSpeed, _GradientScale;
            
            float _BassImpact, _MidImpact, _HighImpact;
            float _AudioReactivity, _AudioThreshold;

            // Optimized hash function
            float hash(float2 p)
            {
                p = frac(p * float2(123.34, 456.21));
                p += dot(p, p + 45.32);
                return frac(p.x * p.y);
            }

            // Hash function for cellular noise - MUST be defined before it's used
            float2 hash22(float2 p) 
            {
                // Simpler implementation that doesn't rely on other functions
                float3 p3 = frac(float3(p.xyx) * float3(443.897, 441.423, 437.195));
                p3 += dot(p3, p3.yzx + 19.19);
                return frac((p3.xx+p3.yz)*p3.zy);
            }

            // Improved 2D simplex noise for more organic patterns
            float3 mod289(float3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
            float2 mod289(float2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
            float3 permute(float3 x) { return mod289(((x*34.0)+1.0)*x); }

            float snoise(float2 v) {
                const float4 C = float4(0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439);
                float2 i  = floor(v + dot(v, C.yy));
                float2 x0 = v - i + dot(i, C.xx);
                float2 i1 = (x0.x > x0.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
                float4 x12 = x0.xyxy + C.xxzz;
                x12.xy -= i1;
                i = mod289(i);
                float3 p = permute(permute(i.y + float3(0.0, i1.y, 1.0)) + i.x + float3(0.0, i1.x, 1.0));
                float3 m = max(0.5 - float3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
                m = m*m;
                m = m*m;
                float3 x = 2.0 * frac(p * C.www) - 1.0;
                float3 h = abs(x) - 0.5;
                float3 ox = floor(x + 0.5);
                float3 a0 = x - ox;
                m *= 1.79284291400159 - 0.85373472095314 * (a0*a0 + h*h);
                float3 g;
                g.x = a0.x * x0.x + h.x * x0.y;
                g.yz = a0.yz * x12.xz + h.yz * x12.yw;
                return 130.0 * dot(m, g);
            }

            // Fast cellular noise for cell-like patterning
            float cellular(float2 p) {
                float2 i = floor(p);
                float2 f = frac(p);
                
                float minDist = 1.0;
                
                // Simple cellular noise - check 9 neighboring cells
                for (int y = -1; y <= 1; y++) {
                    for (int x = -1; x <= 1; x++) {
                        // Compute a stable random position for this cell
                        float2 cellPos = float2(x, y);
                        float2 cellCenter = i + cellPos;
                        
                        // Generate a pseudo-random position within the cell
                        float2 hashVal;
                        hashVal.x = frac(sin(dot(cellCenter, float2(127.1, 311.7))) * 43758.5453);
                        hashVal.y = frac(sin(dot(cellCenter, float2(269.5, 183.3))) * 43758.5453);
                        
                        // Compute distance from fragment to this point
                        float2 pointPos = cellPos + hashVal;
                        float2 diff = pointPos - f;
                        float dist = length(diff);
                        
                        // Keep minimum distance
                        minDist = min(minDist, dist);
                    }
                }
                
                return minDist;
            }
            
            // Rotation matrix
            float2x2 rotate2D(float angle) {
                float s = sin(angle);
                float c = cos(angle);
                return float2x2(c, -s, s, c);
            }
            
            // Domain warping for liquid motion
            float2 domainWarp(float2 uv, float time, float strength, float4 audioData) {
                // Apply audio-reactive strength
                float audioStr = strength * (1.0 + audioData.x * _BassImpact);
                
                // First level of warping
                float2 offset1 = float2(
                    snoise(float2(uv.x * 0.7 + time * 0.3, uv.y * 0.9 - time * 0.4)),
                    snoise(float2(uv.x * 0.8 - time * 0.2, uv.y * 0.7 + time * 0.5))
                ) * audioStr;
                
                // First warp
                float2 warped = uv + offset1 * 0.2;
                
                // Second level with higher frequency modulated by mids
                float midStr = 1.0 + audioData.y * _MidImpact * 0.5;
                float2 offset2 = float2(
                    snoise(float2(warped.x * 1.3 * midStr - time * 0.2, warped.y * 1.2 + time * 0.3)),
                    snoise(float2(warped.x * 1.2 + time * 0.3, warped.y * 1.3 * midStr - time * 0.2))
                ) * audioStr * 0.7;
                
                // Final warped coordinates
                return uv + offset1 * 0.2 + offset2 * 0.1;
            }
            
            // Organic wave pattern generation based on sine/cosine waves
            float organicWaves(float2 uv, float time, float4 audioData) {
                // Audio-reactive wave parameters
                float bass = 1.0 + audioData.x * _BassImpact * 2.0;
                float mids = 1.0 + audioData.y * _MidImpact;
                
                // Primary waves with different phases and frequencies
                float wave1 = sin(uv.x * _WavesScale + time * _WaveSpeed) * 0.5;
                float wave2 = cos(uv.y * (_WavesScale * 1.5) + time * _WaveSpeed * 0.5) * 0.3;
                
                // Bass-influenced wave
                float bassWave = sin(length(uv - 0.5) * (_WavesScale * bass) - time * _WaveSpeed * 1.2) * 0.4 * bass;
                
                // Audio-reactive turbulence
                float turbulence = 0;
                if (audioData.x > 0.2) {
                    float turbAmt = _TurbulenceAmount * audioData.x;
                    turbulence = snoise(uv * (_WavesScale * 0.5) + time * (_WaveSpeed * 2.0)) * turbAmt;
                }
                
                // Combine waves with audio-reactivity
                return (wave1 + wave2) * mids + bassWave + turbulence;
            }
            
            // Fractal noise with audio reactivity
            float fractalNoise(float2 p, float detail, float4 audioData) {
                float value = 0.0;
                float amplitude = 0.5;
                float frequency = 1.0;
                
                // Audio-reactive frequency modulation
                float freqMod = 1.0 + audioData.x * 0.5 + audioData.y * 0.3;
                
                // Use integer iteration with fixed limit for better optimization
                UNITY_UNROLL
                for(int i = 0; i < 5; i++) {
                    if (i >= detail) break;
                    
                    // Apply subtle rotation for organic feel
                    float2x2 rot = rotate2D(0.3 * i + _Time.y * 0.1);
                    float2 rotated = mul(rot, p * frequency * freqMod);
                    
                    // Add noise layer
                    value += snoise(rotated) * amplitude;
                    
                    // Adjust for next octave
                    amplitude *= 0.5;
                    frequency *= 2.0;
                }
                
                // Normalize to 0-1 range
                return value * 0.5 + 0.5;
            }
            
            // HSV to RGB conversion for color manipulation
            float3 HSVtoRGB(float3 HSV) {
                float3 RGB = 0;
                float C = HSV.z * HSV.y;
                float H = HSV.x * 6;
                float X = C * (1 - abs(fmod(H, 2) - 1));
                
                if (H < 1) RGB = float3(C, X, 0);
                else if (H < 2) RGB = float3(X, C, 0);
                else if (H < 3) RGB = float3(0, C, X);
                else if (H < 4) RGB = float3(0, X, C);
                else if (H < 5) RGB = float3(X, 0, C);
                else RGB = float3(C, 0, X);
                
                return RGB + (HSV.z - C);
            }
            
            // Generate organic-looking colors with audio reactivity
            float3 getOrganicColors(float pattern, float edge, float time, float4 audioData) {
                // Create time-based color cycling
                float cycle = frac(time * _ColorCycleSpeed);
                
                // Generate hue shifts based on audio and pattern
                float hueShift1 = frac(cycle + audioData.y * 0.1);
                float hueShift2 = frac(cycle + 0.33 + audioData.z * 0.05);
                float hueShift3 = frac(cycle + 0.66 - audioData.x * 0.1);
                
                // Create dynamic colors based on HSV
                float3 color1 = lerp(_PrimaryColor.rgb, HSVtoRGB(float3(hueShift1, 0.7, 0.9)), 0.6);
                float3 color2 = lerp(_SecondaryColor.rgb, HSVtoRGB(float3(hueShift2, 0.8, 0.8)), 0.6);
                float3 color3 = lerp(_AccentColor.rgb, HSVtoRGB(float3(hueShift3, 0.9, 0.7)), 0.6);
                
                // Gradient mapping based on pattern value and audio
                float3 gradColor;
                float t = frac(pattern * _GradientScale + audioData.x * 0.2);
                
                if (t < 0.33) {
                    gradColor = lerp(color1, color2, t * 3.0);
                } else if (t < 0.66) {
                    gradColor = lerp(color2, color3, (t - 0.33) * 3.0);
                } else {
                    gradColor = lerp(color3, color1, (t - 0.66) * 3.0);
                }
                
                // Edge highlighting with accent color
                float3 edgeColor = lerp(gradColor, color3 * (1.0 + audioData.z), edge * (0.7 + audioData.y * 0.5));
                
                // Apply audio-reactive brightness
                float brightness = 1.0 + (audioData.x * 0.2 + audioData.y * 0.1 + audioData.z * 0.1) * _AudioReactivity;
                edgeColor *= brightness;
                
                // Add subtle oscillation
                float pulse = sin(time * 2.0 + pattern * 6.28) * 0.5 + 0.5;
                edgeColor *= 0.9 + pulse * 0.2 * (1.0 + audioData.y * 0.5);
                
                return edgeColor;
            }
            
            // Generate organic pattern with liquid motion
            float3 createOrganicPattern(float2 uv, float time, float4 audioData) {
                // Check audio reactivity threshold
                float audioIntensity = 0.0;
                if (length(audioData) > _AudioThreshold) {
                    audioIntensity = length(audioData) * _AudioReactivity;
                }
                
                // Apply domain warping for liquid-like motion
                float2 warpedUV = domainWarp(uv, time * _FlowSpeed, _FlowAmplitude, audioData);
                
                // Create organic wave pattern
                float waves = organicWaves(warpedUV, time, audioData);
                
                // Generate fractal noise pattern with audio reactivity
                float noise = fractalNoise(warpedUV * _PatternScale, _PatternDetail, audioData);
                
                // Add cellular pattern for organic cell-like structures modulated by high frequencies
                float cells = cellular(warpedUV * (_PatternScale * 2.0) + float2(time * 0.1, time * -0.15));
                cells = smoothstep(0.0, 0.4 + audioData.z * _HighImpact * 0.3, cells);
                
                // Combine patterns with audio-reactivity for final organic pattern
                float combinedPattern = lerp(noise, waves, 0.4 + audioData.y * 0.2);
                combinedPattern = lerp(combinedPattern, cells, 0.3 + audioData.z * _HighImpact * 0.2);
                
                // Create edge definition with organic feel
                float edge = smoothstep(_OrganicEdge - 0.1, _OrganicEdge + 0.1, combinedPattern);
                edge = lerp(edge, 1.0 - edge, step(0.5, sin(time * 0.2)));
                
                // Apply audio-reactive turbulence to edge definition
                if (audioData.x > 0.3) {
                    float turbulence = snoise(warpedUV * 5.0 + time) * audioData.x;
                    edge = lerp(edge, turbulence, audioData.x * 0.3);
                }
                
                // Generate colors based on organic pattern and audio
                float3 color = getOrganicColors(combinedPattern, edge, time, audioData);
                
                return color;
            }

            v2f vert (appdata v)
            {
                v2f o;
                
                // Audio-reactive vertex displacement
                float4 audioData = float4(0,0,0,0);
                if (AudioLinkIsAvailable())
                {
                    audioData.x = AudioLinkData(ALPASS_AUDIOBASS).r;
                    audioData.y = AudioLinkData(ALPASS_AUDIOLOWMIDS).r;
                    
                    // Only apply displacement if audio exceeds threshold
                    if (audioData.x > _AudioThreshold || audioData.y > _AudioThreshold * 0.5)
                    {
                        // Apply subtle vertex displacement for organic movement
                        float displacement = (audioData.x * _BassImpact * 0.15 + audioData.y * _MidImpact * 0.05) * _AudioReactivity;
                        
                        // Create more interesting displacement
                        float noise = snoise(float2(v.uv.x * 3.0 + _Time.y * 0.2, v.uv.y * 3.0 - _Time.y * 0.3)) * 0.5 + 0.5;
                        displacement *= noise * 2.0;
                        
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
                // Fast path if AudioLink not available
                if (!AudioLinkIsAvailable())
                {
                    // Return pure black when no audio is available
                    return fixed4(0, 0, 0, 1);
                }
                
                // Sample AudioLink data
                float4 audioData;
                audioData.x = AudioLinkData(ALPASS_AUDIOBASS).r;         // Bass
                audioData.y = AudioLinkData(ALPASS_AUDIOLOWMIDS).r;      // Low-mid
                audioData.z = AudioLinkData(ALPASS_AUDIOHIGHMIDS).r;     // High-mid
                audioData.w = AudioLinkData(ALPASS_AUDIOTREBLE).r;       // Treble
                
                // Early out if there's no significant audio
                float audioSum = audioData.x + audioData.y + audioData.z + audioData.w;
                if (audioSum < _AudioThreshold * 4)
                {
                    // Return pure black when audio is too low
                    return fixed4(0, 0, 0, 1);
                }
                
                // Create audio-reactive organic pattern
                float time = _Time.y * _PatternSpeed;
                float3 organicColor = createOrganicPattern(i.uv, time, audioData);
                
                // Apply texture
                float4 texColor = tex2D(_MainTex, i.uv);
                
                // Final color with emission and texture
                float3 finalColor = organicColor * texColor.rgb * _EmissionStrength;
                
                // Scale by audio reactivity
                finalColor *= 1.0 + audioSum * 0.2 * _AudioReactivity;
                
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
