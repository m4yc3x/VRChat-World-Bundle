// **************************************************
// ************* Mayce's Quest Shaders **************
// **************************************************
// https://github.com/m4yc3x

Shader "Mayce/AudioLink/AudioLinkD_Vertex"
{
    Properties
    {
        [Header(Base Properties)]
        _MainTex ("Texture", 2D) = "white" {}
        _EmissionIntensity ("Emission Intensity", Range(0,10)) = 2
        
        [Header(Tunnel Properties)]
        _TunnelSpeed ("Tunnel Speed", Range(0,2)) = 0.2
        _TunnelScale ("Tunnel Scale", Range(0.1,10)) = 2
        _TunnelDepth ("Tunnel Depth", Range(0.1,4)) = 1
        _TunnelTwist ("Tunnel Twist", Range(0,2)) = 0.3
        _AudioSpeedIntensity ("Audio Speed Intensity", Range(0,2)) = 0.15
        _PatternIntensity ("Pattern Intensity", Range(0,1)) = 0.8
        _PatternScale ("Pattern Scale", Range(0.1,5)) = 1.5
        _RotationSpeed ("Rotation Speed", Range(0,2)) = 0.15
        _AudioRotationIntensity ("Audio Rotation Intensity", Range(0,2)) = 0.25
        _SmoothingFactor ("Smoothing Factor", Range(0,0.99)) = 0.85
        
        [Header(Color Properties)]
        [HDR] _BackgroundColor ("Background Color", Color) = (0.02,0.05,0.1,1)
        [HDR] _PatternColor1 ("Pattern Color 1", Color) = (0.7,0.2,0.3,1)
        [HDR] _PatternColor2 ("Pattern Color 2", Color) = (0.2,0.5,0.8,1)
        _ColorSpeed ("Color Speed", Range(0,2)) = 0.4
        
        [Header(Audio Properties)]
        _AudioSmoothing ("Audio Smoothing", Range(0,0.95)) = 0.8
        _BassIntensity ("Bass Intensity", Range(0,2)) = 0.7
        _MidIntensity ("Mid Intensity", Range(0,2)) = 0.6
        _TrebleIntensity ("Treble Intensity", Range(0,2)) = 0.5
        
        [Header(Electric Effect)]
        _ElectricIntensity ("Electric Intensity", Range(0,1)) = 0.4
        _ElectricSpeed ("Electric Speed", Range(0,5)) = 2
        _ElectricWidth ("Electric Width", Range(0,1)) = 0.1
        [HDR] _ElectricColor ("Electric Color", Color) = (0.1,0.2,0.4,1)
        _ElectricScale ("Electric Scale", Range(1,10)) = 3
        _AudioElectricIntensity ("Audio Electric Intensity", Range(0,2)) = 0.7
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
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 viewDir : TEXCOORD1;
                UNITY_FOG_COORDS(2)
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _EmissionIntensity;
            float _TunnelSpeed;
            float _TunnelScale;
            float _TunnelDepth;
            float _TunnelTwist;
            float _AudioSpeedIntensity;
            float _PatternIntensity;
            float _PatternScale;
            float _RotationSpeed;
            float _AudioRotationIntensity;
            float _SmoothingFactor;
            float4 _BackgroundColor;
            float4 _PatternColor1;
            float4 _PatternColor2;
            float _ColorSpeed;
            float _AudioSmoothing;
            float _BassIntensity;
            float _MidIntensity;
            float _TrebleIntensity;
            float _ElectricIntensity;
            float _ElectricSpeed;
            float _ElectricWidth;
            float4 _ElectricColor;
            float _ElectricScale;
            float _AudioElectricIntensity;

            // Improved noise function
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
                float3 m = max(0.5 - float3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0);
                m = m*m;
                m = m*m;
                float3 x = 2.0 * frac(p * C.www) - 1.0;
                float3 h = abs(x) - 0.5;
                float3 ox = floor(x + 0.5);
                float3 a0 = x - ox;
                m *= 1.79284291400159 - 0.85373472095314 * (a0*a0 + h*h);
                float3 g;
                g.x  = a0.x  * x0.x  + h.x  * x0.y;
                g.yz = a0.yz * x12.xz + h.yz * x12.yw;
                return 130.0 * dot(m, g);
            }

            float2 rotate2D(float2 p, float angle) {
                float s = sin(angle);
                float c = cos(angle);
                float2x2 rot = float2x2(c, -s, s, c);
                return mul(rot, p);
            }

            float smoothAudioValue(float audioValue, float smoothing) {
                static float lastValue = 0;
                float smoothedValue = lerp(lastValue, audioValue, 1 - smoothing);
                lastValue = smoothedValue;
                return smoothedValue;
            }

            float2 tunnelEffect(float2 uv, float time, float4 audio) {
                float2 center = uv;
                
                // Smooth out audio values
                float smoothBass = smoothAudioValue(audio.x, _SmoothingFactor);
                float smoothMids = smoothAudioValue(audio.y, _SmoothingFactor);
                
                // Smoother rotation with reduced audio influence
                float baseRotation = time * _RotationSpeed;
                float audioRotation = smoothBass * _AudioRotationIntensity;
                float rotationAngle = baseRotation + sin(audioRotation) * 0.5; // Use sin for smoother transitions
                center = rotate2D(center, rotationAngle);
                
                float dist = length(center);
                float angle = atan2(center.y, center.x);
                
                // Smoother forward motion
                float audioSpeed = 1.0 + smoothBass * 0.15 * _AudioSpeedIntensity;
                float z = frac(time * _TunnelSpeed * 0.5 * audioSpeed);
                
                // Gentler twist with smoothed audio
                float twistAmount = _TunnelTwist * (1.0 + smoothBass * 0.1);
                float twist = angle + z * twistAmount;
                
                // Smoother tunnel depth
                float tunnelDist = _TunnelDepth / (dist + 0.8);
                
                float2 baseCoords = float2(
                    twist,
                    tunnelDist + z
                );
                
                // Smoother pattern rotation
                float patternRotation = smoothMids * 0.1 * _AudioRotationIntensity;
                baseCoords = rotate2D(baseCoords, sin(patternRotation) * 0.3); // Use sin for smoother rotation
                
                return baseCoords * _TunnelScale;
            }

            float electricBolt(float2 uv, float time, float4 audio) {
                float2 scaledUV = uv * _ElectricScale;
                
                // Smoother electric movement
                float smoothBass = smoothAudioValue(audio.x, _SmoothingFactor);
                float speed = _ElectricSpeed * (1.0 + smoothBass * 0.2);
                
                float noise1 = snoise(scaledUV + float2(time * speed * 0.5, 0));
                float noise2 = snoise(scaledUV * 1.5 - float2(time * speed * 0.3, 0));
                
                float electric = abs(noise1 * noise2);
                electric = smoothstep(_ElectricWidth, 0.0, electric);
                
                float audioIntensity = (smoothBass + smoothAudioValue(audio.y, _SmoothingFactor)) * 0.5 * _AudioElectricIntensity;
                float timeVary = sin(time * 1.5 + noise1 * 2.0) * 0.5 + 0.5;
                
                return electric * timeVary * (1.0 + audioIntensity) * _ElectricIntensity;
            }

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

            float3 RGBtoHSV(float3 RGB) {
                float3 HSV = 0;
                float M = max(RGB.r, max(RGB.g, RGB.b));
                float m = min(RGB.r, min(RGB.g, RGB.b));
                float C = M - m;
                
                if (C > 0) {
                    if (M == RGB.r) HSV.x = fmod((RGB.g - RGB.b) / C, 6.0);
                    else if (M == RGB.g) HSV.x = (RGB.b - RGB.r) / C + 2.0;
                    else HSV.x = (RGB.r - RGB.g) / C + 4.0;
                    HSV.x /= 6.0;
                }
                
                HSV.y = (M > 0) ? C / M : 0;
                HSV.z = M;
                
                return HSV;
            }

            float3 getComplementaryColor(float3 baseColor) {
                float3 hsv = RGBtoHSV(baseColor);
                hsv.x = fmod(hsv.x + 0.5, 1.0); // Shift hue by 180 degrees
                return HSVtoRGB(hsv);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.viewDir = normalize(mul(unity_ObjectToWorld, v.vertex).xyz - _WorldSpaceCameraPos);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // Initialize audio data with smoothing
                float4 audioData = 0;
                static float4 prevAudioData = 0;
                
                if (AudioLinkIsAvailable())
                {
                    float4 newAudioData = float4(
                        AudioLinkData(ALPASS_AUDIOBASS).r * _BassIntensity,
                        AudioLinkData(ALPASS_AUDIOLOWMIDS).r * _MidIntensity,
                        AudioLinkData(ALPASS_AUDIOHIGHMIDS).r * _MidIntensity,
                        AudioLinkData(ALPASS_AUDIOTREBLE).r * _TrebleIntensity
                    );
                    
                    audioData = lerp(prevAudioData, newAudioData, 1 - _AudioSmoothing);
                    prevAudioData = audioData;
                }
                
                float time = _Time.y;
                float2 uv = i.uv * 2 - 1;
                
                float2 tunnelUV = tunnelEffect(uv, time, audioData);
                
                // Generate smoother pattern
                float pattern = 0;
                float scale = _PatternScale;
                float amp = 0.5;
                
                for(int i = 0; i < 3; i++) {
                    // Smoother layer rotation
                    float smoothMids = smoothAudioValue(audioData.y, _SmoothingFactor);
                    float layerRotation = time * (0.05 + i * 0.03) + smoothMids * 0.15;
                    float2 rotatedUV = rotate2D(tunnelUV, sin(layerRotation) * 0.3);
                    pattern += snoise(rotatedUV * scale) * amp;
                    scale *= 2.0;
                    amp *= 0.5;
                }
                
                pattern = saturate(pattern * 0.5 + 0.5) * _PatternIntensity;
                
                // Color cycling for pattern
                float colorTime = time * _ColorSpeed;
                float3 patternColor = lerp(
                    _PatternColor1.rgb,
                    _PatternColor2.rgb,
                    sin(colorTime) * 0.5 + 0.5
                );
                
                // Create background with depth
                float2 centeredUV = uv * 0.5 + 0.5;
                float depth = length(centeredUV - 0.5);
                float3 backgroundColor = _BackgroundColor.rgb * (1.0 - depth * 0.5);
                
                // Mix pattern and background
                float3 finalColor = lerp(
                    backgroundColor,
                    patternColor * (1.0 + audioData.x * 0.5),
                    pattern
                );
                
                // Generate electric effect with complementary colors
                float electric = electricBolt(tunnelUV, time, audioData);
                float3 complementaryColor = getComplementaryColor(patternColor);
                float3 electricColor = complementaryColor * (1.0 + audioData.x * 0.3);
                finalColor = lerp(finalColor, electricColor, electric);
                
                // Add subtle audio-reactive glow
                float glow = pattern * audioData.w * 0.3;
                finalColor += glow * patternColor;
                
                // Apply emission with audio boost
                float audioBoost = length(audioData) * 0.2;
                finalColor *= _EmissionIntensity * (1 + audioBoost);
                
                // Return black if no audio
                if (length(audioData) < 0.01) return fixed4(0,0,0,1);
                
                fixed4 final = fixed4(finalColor, 1);
                UNITY_APPLY_FOG(i.fogCoord, final);
                return final;
            }
            ENDCG
        }
    }
    FallBack "Unlit/Texture"
}
