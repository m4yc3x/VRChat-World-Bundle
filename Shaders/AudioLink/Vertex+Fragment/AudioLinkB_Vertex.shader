// **************************************************
// ************* Mayce's Quest Shaders **************
// **************************************************
// https://github.com/m4yc3x

Shader "Mayce/AudioLink/AudioLinkB_Vertex"
{
    Properties
    {
        [Header(Base Properties)]
        _MainTex ("Texture", 2D) = "white" {}
        _EmissionColor ("Emission Color", Color) = (1,1,1,1)
        _EmissionIntensity ("Emission Intensity", Range(0,20)) = 5
        
        [Header(Color Settings)]
        [HDR] _PrimaryColor ("Primary Color", Color) = (0.5,0.8,1,1)
        [HDR] _SecondaryColor ("Secondary Color", Color) = (1,0.2,0.5,1)
        [HDR] _AccentColor ("Accent Color", Color) = (1,0.5,0.2,1)
        _ColorBlend ("Color Blend Factor", Range(0,1)) = 0.5
        _ColorCycleSpeed ("Color Cycle Speed", Range(0,2)) = 0.3
        
        [Header(Pattern Settings)]
        _PatternScale ("Pattern Scale", Range(0.1,50)) = 10
        _PatternSpeed ("Pattern Speed", Range(0,5)) = 1
        _PatternDetail ("Pattern Detail", Range(1,10)) = 3
        _PatternDeformation ("Pattern Deformation", Range(0,5)) = 1.2
        
        [Header(Audio Reactivity)]
        _AudioThreshold ("Audio Threshold", Range(0,0.5)) = 0.05
        _DisplacementAmount ("Displacement Amount", Range(0,1)) = 0.3
        _AudioReactivity ("Audio Reactivity", Range(0,1)) = 0.8
        _AudioSharpness ("Audio Sharpness", Range(1,20)) = 8
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
            
            // AudioLink includes
            #include "Packages/com.llealloo.audiolink/Runtime/Shaders/AudioLink.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float3 worldPos : TEXCOORD2;
                float3 normal : TEXCOORD3;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _EmissionColor;
            float _EmissionIntensity;
            float4 _PrimaryColor;
            float4 _SecondaryColor;
            float4 _AccentColor;
            float _ColorBlend;
            float _ColorCycleSpeed;
            float _PatternScale;
            float _PatternSpeed;
            float _PatternDetail;
            float _PatternDeformation;
            float _AudioThreshold;
            float _DisplacementAmount;
            float _AudioReactivity;
            float _AudioSharpness;

            // Simplex noise functions - more organic than sin/cos
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

            // Domain warping for more complex patterns
            float2 domainWarp(float2 uv, float time, float strength) {
                float2 offset1 = float2(
                    snoise(float2(uv.x * 0.7 + time * 0.3, uv.y * 0.9 - time * 0.4)),
                    snoise(float2(uv.x * 0.8 - time * 0.2, uv.y * 0.7 + time * 0.5))
                );
                
                float2 warped = uv + offset1 * strength;
                
                float2 offset2 = float2(
                    snoise(float2(warped.x * 1.3 - time * 0.2, warped.y * 1.2 + time * 0.3)),
                    snoise(float2(warped.x * 1.2 + time * 0.3, warped.y * 1.3 - time * 0.2))
                );
                
                return uv + offset1 * strength + offset2 * strength * 0.5;
            }

            // HSV to RGB conversion for smooth color cycling
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

            // Audio reactive pattern
            float audioPattern(float2 uv, float time, float4 audioData, float scale, float detail) {
                // Use audio data to control the pattern
                float bassInfluence = audioData.x;
                float midInfluence = audioData.y;
                float highInfluence = audioData.z;
                
                // Calculate base coordinates with audio influence
                float2 baseUV = uv * scale;
                
                // Apply domain warping based on audio
                float2 warpStrength = _PatternDeformation * float2(
                    bassInfluence * 2.0,
                    midInfluence * 1.5
                );
                
                float2 warpedUV = domainWarp(baseUV, time, warpStrength.x);
                
                // Create multiple layers of noise with different scales for detail
                float pattern = 0;
                float amplitude = 1.0;
                float frequency = 1.0;
                
                for (int i = 0; i < detail; i++) {
                    pattern += snoise(warpedUV * frequency) * amplitude;
                    warpedUV = domainWarp(warpedUV, time * 1.5, warpStrength.y * 0.5);
                    amplitude *= 0.5;
                    frequency *= 2.0;
                }
                
                // Normalize to 0-1 range and apply audio reactivity
                pattern = pattern * 0.5 + 0.5;
                
                // Enhance contrast based on audio sharpness
                float contrast = lerp(1.0, _AudioSharpness, highInfluence);
                pattern = saturate((pattern - 0.5) * contrast + 0.5);
                
                return pattern;
            }

            // Smooth step with audio-reactive threshold
            float audioStep(float value, float audioInfluence) {
                float threshold = _AudioThreshold * (1.0 - audioInfluence * 0.8);
                return smoothstep(threshold, threshold + 0.1, value);
            }

            v2f vert (appdata v)
            {
                v2f o;
                
                // Initialize audio values
                float4 audioData = float4(0,0,0,0);
                float audioSum = 0;
                
                // Check if AudioLink is available
                if (AudioLinkIsAvailable())
                {
                    // Sample different frequency bands
                    audioData.x = AudioLinkData(ALPASS_AUDIOBASS).r;         // Bass
                    audioData.y = AudioLinkData(ALPASS_AUDIOLOWMIDS).r;      // Low-mid
                    audioData.z = AudioLinkData(ALPASS_AUDIOHIGHMIDS).r;     // High-mid
                    audioData.w = AudioLinkData(ALPASS_AUDIOTREBLE).r;       // Treble
                    
                    audioSum = audioData.x + audioData.y + audioData.z + audioData.w;
                }
                
                // Apply vertex displacement using both normal and tangent for more organic movement
                float3 displacement = float3(0,0,0);
                
                if (audioSum > _AudioThreshold) {
                    // Create more organic displacement using multiple frequency bands
                    displacement = v.normal * audioData.x * _DisplacementAmount;
                    displacement += normalize(cross(v.normal, v.tangent.xyz)) * audioData.y * _DisplacementAmount * 0.5;
                    displacement *= _AudioReactivity;
                }
                
                float4 displacedVertex = v.vertex + float4(displacement, 0);
                
                o.vertex = UnityObjectToClipPos(displacedVertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.normal = UnityObjectToWorldNormal(v.normal);
                UNITY_TRANSFER_FOG(o, o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // Initialize audio values
                float4 audioData = float4(0,0,0,0);
                float audioSum = 0;
                
                // Check if AudioLink is available before sampling
                if (AudioLinkIsAvailable())
                {
                    // Sample AudioLink data using AudioLink functions
                    audioData.x = AudioLinkData(ALPASS_AUDIOBASS).r;         // Bass
                    audioData.y = AudioLinkData(ALPASS_AUDIOLOWMIDS).r;      // Low-mid
                    audioData.z = AudioLinkData(ALPASS_AUDIOHIGHMIDS).r;     // High-mid
                    audioData.w = AudioLinkData(ALPASS_AUDIOTREBLE).r;       // Treble
                    
                    audioSum = audioData.x + audioData.y + audioData.z + audioData.w;
                }
                
                // Early out if audio is below threshold - keep it black
                if (audioSum <= _AudioThreshold * 4) {
                    return fixed4(0,0,0,1);
                }
                
                // Time variables
                float time = _Time.y * _PatternSpeed;
                
                // Create advanced organic pattern with audio reactivity
                float pattern = audioPattern(i.uv, time, audioData, _PatternScale, _PatternDetail);
                
                // Apply audio threshold to pattern visibility
                float patternVisibility = audioStep(pattern, audioData.x);
                
                // Calculate time for color cycling
                float colorCycleTime = _Time.y * _ColorCycleSpeed;
                
                // Cycle the primary color through hue space over time
                float primaryHue = frac(colorCycleTime * 0.1);
                float3 primaryHSV = float3(primaryHue, 0.8, 1.0);
                float3 cycledPrimary = lerp(_PrimaryColor.rgb, HSVtoRGB(primaryHSV), 0.7);
                
                // Cycle the secondary color with offset
                float secondaryHue = frac(colorCycleTime * 0.1 + 0.33); // 1/3 through color wheel
                float3 secondaryHSV = float3(secondaryHue, 0.8, 1.0);
                float3 cycledSecondary = lerp(_SecondaryColor.rgb, HSVtoRGB(secondaryHSV), 0.7);
                
                // Cycle the accent color with different offset
                float accentHue = frac(colorCycleTime * 0.1 + 0.66); // 2/3 through color wheel
                float3 accentHSV = float3(accentHue, 0.8, 1.0);
                float3 cycledAccent = lerp(_AccentColor.rgb, HSVtoRGB(accentHSV), 0.7);
                
                // Create flowing colors based on audio frequencies
                float3 flowColor1 = cycledPrimary * (1.0 + audioData.z * 2.0);
                float3 flowColor2 = cycledSecondary * (1.0 + audioData.w * 2.0);
                float3 accentColor = cycledAccent * (1.0 + audioData.y * 2.0);
                
                // Mix colors based on pattern and audio
                float colorMix = sin(i.uv.x * 3.14 + i.uv.y * 2.0 + time) * 0.5 + 0.5;
                colorMix = lerp(colorMix, pattern, _ColorBlend);
                
                float3 baseColor = lerp(flowColor1, flowColor2, colorMix);
                
                // Add accent color for highlights based on high frequencies
                float highlight = pow(pattern, 4.0) * audioData.w * 2.0;
                baseColor = lerp(baseColor, accentColor, highlight);
                
                // Apply texture
                fixed4 texColor = tex2D(_MainTex, i.uv);
                
                // Adjust brightness based on audio energy
                float brightness = (audioSum * 0.25) * _AudioReactivity;
                
                // Final color with emission intensity affected by audio
                fixed4 col = fixed4(baseColor * _EmissionColor.rgb * texColor.rgb * patternVisibility, 1);
                col.rgb *= _EmissionIntensity * brightness;
                
                // Apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
    
    // Fallback shader in case the above isn't supported
    FallBack "Unlit/Texture"
    
    CustomEditor "ShaderGUI" // Optional: specify a custom editor for the shader
}
