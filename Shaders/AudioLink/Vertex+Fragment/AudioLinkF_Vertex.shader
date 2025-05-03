// **************************************************
// ************* Mayce's Quest Shaders **************
// **************************************************
// https://github.com/m4yc3x

Shader "Mayce/AudioLink/AudioLinkF_Vertex"
{
    Properties
    {
        [Header(Base Properties)]
        _MainTex ("Texture", 2D) = "white" {}
        _EmissionStrength ("Emission Strength", Range(0,5)) = 1.0
        
        [Header(Color Properties)]
        [HDR] _Color1 ("Color 1", Color) = (0.05,0.2,0.5,1)
        [HDR] _Color2 ("Color 2", Color) = (0.2,0.05,0.3,1)
        [HDR] _Color3 ("Color 3", Color) = (0.5,0.05,0.2,1)
        _ColorSpread ("Color Spread", Range(0.1,5.0)) = 2.0
        _ColorSpeed ("Color Flow Speed", Range(0,2)) = 0.5
        
        [Header(Field Properties)]
        _FieldScale ("Field Scale", Range(0.1,10)) = 3.0
        _FieldDetail ("Field Detail", Range(1,5)) = 2
        _FlowSpeed ("Flow Speed", Range(0,2)) = 0.5
        _FlowStrength ("Flow Strength", Range(0,2)) = 0.8
        
        [Header(AudioLink Reactivity)]
        _BassDistortion ("Bass Distortion", Range(0,2)) = 0.8
        _MidInfluence ("Mid Frequency Influence", Range(0,1)) = 0.5
        _HighFreqBrightness ("High Frequency Brightness", Range(0,1)) = 0.3
        _AudioReactivity ("Overall Reactivity", Range(0,1)) = 0.7
        _ThresholdBass ("Bass Threshold", Range(0,0.3)) = 0.05
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
            float4 _Color1, _Color2, _Color3;
            float _ColorSpread, _ColorSpeed;
            float _FieldScale, _FieldDetail, _FlowSpeed, _FlowStrength;
            float _BassDistortion, _MidInfluence, _HighFreqBrightness;
            float _AudioReactivity, _ThresholdBass;

            // Optimized hash function
            float hash(float2 p)
            {
                p = frac(p * float2(123.34, 456.21));
                p += dot(p, p + 45.32);
                return frac(p.x * p.y);
            }

            // Simplex noise functions for more liquid-like effects
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

            // Multi-level domain warping for liquid-like distortion
            float2 liquidWarp(float2 uv, float time, float bassAmount) 
            {
                // First level of warping
                float2 offset1 = float2(
                    snoise(float2(uv.x * 0.7 + time * 0.3, uv.y * 0.9 - time * 0.4)),
                    snoise(float2(uv.x * 0.8 - time * 0.2, uv.y * 0.7 + time * 0.5))
                );
                
                // Scale offset by bass (with multiplier for stronger effect)
                float bassMultiplier = 1.0 + bassAmount * 2.0 * _BassDistortion;
                offset1 *= bassMultiplier;
                
                // First warp
                float2 warped = uv + offset1 * 0.2;
                
                // Second level with higher frequency
                float2 offset2 = float2(
                    snoise(float2(warped.x * 1.3 - time * 0.2, warped.y * 1.2 + time * 0.3)),
                    snoise(float2(warped.x * 1.2 + time * 0.3, warped.y * 1.3 - time * 0.2))
                );
                
                // Add subtle bass-driven animation to second warp
                offset2 *= 0.5 * bassMultiplier;
                
                // Combine warps
                return uv + offset1 * 0.2 + offset2 * 0.1;
            }

            // Fast and efficient 2D noise
            float noise(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                
                // Cubic Hermite curve for smooth interpolation
                float2 u = f * f * (3.0 - 2.0 * f);
                
                // Four corners
                float a = hash(i);
                float b = hash(i + float2(1.0, 0.0));
                float c = hash(i + float2(0.0, 1.0));
                float d = hash(i + float2(1.0, 1.0));
                
                return lerp(lerp(a, b, u.x), lerp(c, d, u.x), u.y);
            }

            // Optimized fractal noise (limited iterations for performance)
            float fractalNoise(float2 p, float detail)
            {
                float value = 0.0;
                float amplitude = 0.5;
                float frequency = 1.0;
                
                // Use integer iteration with fixed limit for better optimization
                UNITY_UNROLL
                for(int i = 0; i < 5; i++)
                {
                    if (i >= detail) break;
                    value += noise(p * frequency) * amplitude;
                    amplitude *= 0.5;
                    frequency *= 2.0;
                }
                
                // Make noise more contrasted for smaller, sharper blobs
                return smoothstep(0.3, 0.7, value);
            }

            // Rotation matrix for directional flow
            float2x2 rotate2D(float angle)
            {
                float s = sin(angle);
                float c = cos(angle);
                return float2x2(c, -s, s, c);
            }

            // Enhanced edge detection for bass distortion
            float detectEdges(float field, float bassAmount)
            {
                // Create sharp edges that can be distorted
                float edge = smoothstep(0.4, 0.6, field);
                
                // Enhance edge contrast based on bass
                return smoothstep(0.1 * bassAmount, 1.0 - 0.1 * bassAmount, edge);
            }

            // Field distortion based on audio with enhanced edge distortion
            float2 distortField(float2 p, float time, float bassAmount)
            {
                // Apply liquid-like bass-driven warping first
                p = liquidWarp(p, time, bassAmount);
                
                // Create directional flow with rotation
                float2x2 rot = rotate2D(time * 0.2 + bassAmount * 0.5);
                
                // Primary flow distortion
                float2 flow = float2(
                    noise(p * 0.8 + float2(time * 0.3, 0.0)),
                    noise(p * 0.8 + float2(0.0, time * 0.3))
                );
                
                // Add high-frequency noise for smaller detail distortion
                flow += float2(
                    noise(p * 3.0 + float2(time * 0.7, 0.0)),
                    noise(p * 3.0 + float2(0.0, time * 0.7))
                ) * 0.3;
                
                // Apply rotation and scale for more interesting movement
                flow = mul(rot, flow) * (_FlowStrength + bassAmount * _BassDistortion * 1.5);
                
                return p + flow;
            }

            // Smart color blending to avoid over-exposure
            float3 blendColors(float3 a, float3 b, float t)
            {
                // Use a non-linear blend to prevent over-exposure
                t = smoothstep(0.0, 1.0, t);
                
                // Calculate a perceptually smoother blend
                float3 blend = lerp(a, b, t);
                
                // Tone down intensity to avoid over-saturation
                float luminance = dot(blend, float3(0.299, 0.587, 0.114));
                return lerp(blend, blend / (luminance + 0.001) * 0.8, 0.3);
            }

            // HSV to RGB conversion for rainbow cycling
            float3 HSVtoRGB(float3 HSV)
            {
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
            
            // Generate rainbow colors based on audio data and time
            float3 getRainbowColor(float time, float4 audioData)
            {
                // Base hue cycles through the rainbow over time
                float hue = frac(time * _ColorSpeed * 0.1);
                
                // Audio influence on hue - different bands affect different aspects
                float audioHueShift = 
                    audioData.x * 0.1 +   // Bass shifts hue slightly
                    audioData.y * 0.05;   // Low mids add subtle variation
                
                // Create full rainbow hue with audio influence
                float finalHue = frac(hue + audioHueShift);
                
                // Saturation modulated by mid frequencies
                float saturation = 0.7 + audioData.y * 0.3;
                
                // Value (brightness) influenced by high frequencies
                float value = 0.8 + audioData.z * 0.2 + audioData.w * 0.2;
                
                // Convert HSV to RGB for final color
                return HSVtoRGB(float3(finalHue, saturation, value));
            }

            // Dynamic color cycling with rainbow spectrum
            float3 getCycledColors(float time, float3 color1, float3 color2, float3 color3, float4 audioData)
            {
                // Generate rainbow colors based on time and audio
                float3 rainbowColor1 = getRainbowColor(time, audioData);
                float3 rainbowColor2 = getRainbowColor(time + 0.33, audioData);
                float3 rainbowColor3 = getRainbowColor(time + 0.66, audioData);
                
                // Use the rainbow colors instead of the fixed colors
                // but blend with the original colors to maintain some identity
                float3 blendedColor1 = lerp(color1, rainbowColor1, 0.8);
                float3 blendedColor2 = lerp(color2, rainbowColor2, 0.8);
                float3 blendedColor3 = lerp(color3, rainbowColor3, 0.8);
                
                // More prominent time-based cycling
                float cycle = frac(time * _ColorSpeed * 0.5);
                
                // Create smooth transitions between all three colors
                float3 result;
                
                if (cycle < 0.33) {
                    // Transition from color1 to color2
                    float t = cycle / 0.33;
                    result = lerp(blendedColor1, blendedColor2, smoothstep(0.0, 1.0, t));
                } 
                else if (cycle < 0.66) {
                    // Transition from color2 to color3
                    float t = (cycle - 0.33) / 0.33;
                    result = lerp(blendedColor2, blendedColor3, smoothstep(0.0, 1.0, t));
                }
                else {
                    // Transition from color3 to color1
                    float t = (cycle - 0.66) / 0.34;
                    result = lerp(blendedColor3, blendedColor1, smoothstep(0.0, 1.0, t));
                }
                
                return result;
            }

            // Generate flowing dark/transparent abstract shapes with enhanced bass reactivity
            float getAbstractShapes(float2 uv, float time, float4 audioData)
            {
                // Enhanced bass influence - make it even stronger
                float bassResponse = smoothstep(_ThresholdBass, 0.3, audioData.x) * audioData.x;
                float bassIntensity = bassResponse * 5.0; // Increased from 3.0 to 5.0
                
                // Create base shape pattern with different frequency than the main field
                float2 shapesUV = uv * 1.7; // Different scale for variety
                
                // Bass-driven coordinate scaling - much stronger effect
                float scaleModulation = 1.0 + bassResponse * 1.5; // Increased from 0.5 to 1.5
                shapesUV *= lerp(1.0, scaleModulation, bassResponse);
                
                // INCREASED CORRELATION: Make shape movement speed DIRECTLY tied to bass intensity
                // Much stronger response to bass in the time scale
                float timeScale = bassResponse * 2.0; // Now completely bass-driven (removed base value)
                
                // Add bass-driven rapid movements when bass hits hard
                float2 rapidMovement = float2(0,0);
                if (bassResponse > 0.2) {
                    // Only activate during strong bass hits
                    rapidMovement = float2(
                        sin(time * 8.0) * bassResponse * 0.4,
                        cos(time * 7.0) * bassResponse * 0.5
                    );
                }
                
                // Combined movement with rapid bass response
                float2 shapeOffset = float2(
                    sin(time * (timeScale + 0.05)) * 0.4, // Increased amplitude from 0.3 to 0.4
                    cos(time * (timeScale * 0.75)) * 0.4  // Increased amplitude from 0.3 to 0.4
                ) + rapidMovement;
                
                // ENHANCED DISTORTION: Much stronger bass-driven distortion 
                float bassDistortion = bassResponse * 3.0; // Greatly increased from 1.2 to 3.0
                float2 distortedShapeUV = shapesUV + shapeOffset;
                
                // Apply more extreme bass-reactive turbulence
                distortedShapeUV += float2(
                    sin(distortedShapeUV.y * 3.0 + time * 0.3) * bassDistortion,
                    cos(distortedShapeUV.x * 3.0 + time * 0.2) * bassDistortion
                );
                
                // Add stronger bass pulse distortion with sharper response curve
                float bassPulse = pow(sin(time * 4.0) * 0.5 + 0.5, 2) * bassResponse * 2.0;
                distortedShapeUV += float2(bassPulse * 0.5, bassPulse * 0.4); // Increased from 0.2 to 0.5/0.4
                
                // Add sudden kicks on bass transients
                float bassTransient = max(0, bassResponse - smoothstep(0, 0.1, frac(time * 0.2))); 
                distortedShapeUV += bassTransient * float2(0.3, -0.2);
                
                // Generate several overlapping shape layers with different parameters
                // Bass now affects the noise frequency for more dynamic movement
                float bassFreqMultiplier = 1.0 + bassResponse * 2.0; // Increased from 0.8 to 2.0
                float shape1 = snoise(distortedShapeUV * (1.0 * bassFreqMultiplier) - float2(time * 0.1, 0));
                float shape2 = snoise(distortedShapeUV * (0.5 * bassFreqMultiplier) + float2(0, time * 0.08));
                float shape3 = snoise(distortedShapeUV * (2.0 * bassFreqMultiplier) + float2(time * 0.15, time * 0.1));
                
                // Add high-frequency distortion during bass hits
                if (bassResponse > 0.15) {
                    float highFreqNoise = snoise(distortedShapeUV * 8.0 * bassResponse);
                    shape1 = lerp(shape1, shape1 * 0.8 + highFreqNoise * 0.4, bassResponse);
                    shape2 = lerp(shape2, shape2 * 0.8 + highFreqNoise * 0.3, bassResponse);
                }
                
                // Bass-reactive shape formation thresholds with more extreme values
                // When bass hits, shapes become more defined with sharper edges
                float threshold1 = lerp(0.15, 0.3, bassResponse); // More extreme upper bound
                float threshold2 = lerp(0.35, 0.5, bassResponse); // More extreme upper bound
                
                // First layer - larger flowing shapes - now more reactive to bass
                float layer1 = smoothstep(threshold1, threshold2 + 0.1, shape1);
                
                // Second layer - medium abstract forms
                float layer2 = smoothstep(0.4, 0.6, shape2);
                
                // Third layer - smaller detailed elements
                float layer3 = smoothstep(0.35, 0.45, shape3);
                
                // Combine layers with audio-reactive weights
                // Bass has much stronger influence on the shape composition
                float midFreqWeight = audioData.y * 0.4;
                float highFreqWeight = audioData.z * 0.3;
                float bassWeight = bassResponse * 3.0; // Increased from 1.8 to 3.0
                
                float combinedShape = layer1 * (0.7 + bassWeight * 0.7) + // Increased multiplier from 0.5 to 0.7
                                    layer2 * (0.5 + midFreqWeight) - 
                                    layer3 * (0.4 + highFreqWeight);
                
                // Add bass-reactive pulsing to the shapes with stronger pulse
                combinedShape += sin(time * 6.0) * bassResponse * 0.4; // Increased from 4.0 to 6.0 and 0.2 to 0.4
                
                // Threshold and smooth the result - adjust threshold based on bass
                float shapeThreshold = lerp(0.3, 0.6, bassResponse * 0.7); // Increased upper bound and multiplier
                
                // Return with enhanced contrast when bass hits
                float smoothingRange = 0.3 + bassResponse * 0.5; // Dynamic smoothing based on bass
                return smoothstep(shapeThreshold, shapeThreshold + smoothingRange, abs(combinedShape));
            }

            // Audio visualization field
            float3 createField(float2 uv, float time, float4 audioData)
            {
                // Precompute bass and mid response
                float bassResponse = smoothstep(_ThresholdBass, 0.3, audioData.x) * audioData.x;
                float midResponse = audioData.y * _MidInfluence;
                
                // Apply liquid warping directly to UV coordinates based on bass
                float2 liquidUV = uv;
                if (bassResponse > 0.05) {
                    // Apply stronger liquid effect when bass is prominent
                    liquidUV = liquidWarp(uv, time, bassResponse);
                }
                
                // Scale up for smaller, more frequent blobs
                float blobScale = _FieldScale * 2.0;
                
                // Distort field using bass (with threshold for more punch)
                float2 distortedUV = distortField(liquidUV * blobScale, time * _FlowSpeed, bassResponse);
                
                // Add liquid ripples based on bass - creates wave-like pattern
                float ripplePattern = 0;
                if (bassResponse > 0.1) {
                    float rippleFreq = 8.0 + bassResponse * 10.0;
                    float rippleSpeed = time * (1.0 + bassResponse * 2.0);
                    float dist = length(liquidUV - 0.5) * 2.0;
                    ripplePattern = sin(dist * rippleFreq - rippleSpeed) * 0.5 + 0.5;
                    ripplePattern *= smoothstep(1.0, 0.0, dist); // Fade out at edges
                }
                
                // Create primary field pattern
                float field = fractalNoise(distortedUV, _FieldDetail);
                
                // Add dynamic flow with audio reactivity
                float2 flowOffset = float2(
                    sin(time * 0.4 + liquidUV.y * 3.0) * 0.5,
                    cos(time * 0.5 + liquidUV.x * 3.0) * 0.5
                ) * (1.0 + midResponse);
                
                // Secondary layer with different scale and flow for more detail
                float field2 = fractalNoise((distortedUV + flowOffset) * 2.0, _FieldDetail);
                
                // Third layer for even more detail and frequency
                float field3 = fractalNoise((distortedUV - flowOffset * 0.7) * 3.5, max(1, _FieldDetail - 1.0));
                
                // Combine fields with varying weights
                float combinedField = lerp(field, field2, 0.4 + bassResponse * 0.2);
                combinedField = lerp(combinedField, field3, 0.3);
                
                // Add ripple pattern when bass hits
                combinedField = lerp(combinedField, ripplePattern, bassResponse * 0.4);
                
                // Apply edge detection with bass distortion
                float edgeField = detectEdges(combinedField, bassResponse);
                combinedField = lerp(combinedField, edgeField, bassResponse * 0.7);
                
                // Get cycling base colors with rainbow spectrum
                float3 cycledBaseColors = getCycledColors(time, _Color1.rgb, _Color2.rgb, _Color3.rgb, audioData);
                
                // Create color variations based on the field pattern
                float t1 = frac(combinedField * _ColorSpread + time * _ColorSpeed);
                float t2 = frac(combinedField * _ColorSpread * 0.7 + time * _ColorSpeed * 1.5);
                
                // Rainbow-based secondary colors
                float3 rainbowColor1 = getRainbowColor(time + t1 * 0.5, audioData);
                float3 rainbowColor2 = getRainbowColor(time + 0.5 + t2 * 0.5, audioData);
                
                // Apply color transitions that preserve color integrity but with enhanced cycling
                float3 color1to2 = blendColors(cycledBaseColors, rainbowColor1, t1);
                float3 color2to3 = blendColors(rainbowColor1, rainbowColor2, t2);
                
                // Final color mix with pattern-based and time-varying factor
                float mixFactor = sin(time * 0.5 + combinedField * 3.14) * 0.5 + 0.5;
                float3 finalColor = blendColors(color1to2, color2to3, mixFactor);
                
                // Generate flowing abstract shapes with enhanced bass reactivity
                float abstractShapes = getAbstractShapes(uv, time, audioData);
                
                // Apply dark/transparent shapes as a multiplicative mask
                // Strong bass makes shapes more prominent and darker
                float shapeMask = 1.0 - abstractShapes * (0.9 + bassResponse * 1.2); // Increased from 0.8/0.8 to 0.9/1.2
                
                // Create stronger pulsing edge highlights around the shapes when bass hits
                float shapeEdge = smoothstep(0.05, 0.15, abstractShapes) - smoothstep(0.6, 0.85, abstractShapes);
                float edgeGlow = shapeEdge * bassResponse * 4.0; // Increased multiplier from 2.0 to 4.0
                
                // Apply mask with audio-reactive intensity
                finalColor *= shapeMask;
                
                // Add subtle edge highlight for bass-reactive effect
                finalColor += edgeGlow * 0.2 * getRainbowColor(time * 2.0, audioData);
                
                // Audio-reactive brightness highlights
                float highFreqEffect = audioData.z * 0.3 + audioData.w * 0.7;
                finalColor *= 1.0 + highFreqEffect * _HighFreqBrightness;
                
                // Add more contrast to the pattern
                float contrastPattern = pow(abs(combinedField * 2.0 - 1.0), 1.5) * sign(combinedField - 0.5) * 0.5 + 0.5;
                finalColor *= 0.7 + contrastPattern * 0.6;
                
                return finalColor;
            }

            v2f vert (appdata v)
            {
                v2f o;
                
                // Audio-reactive vertex displacement (minimal for performance)
                float4 audioData = float4(0,0,0,0);
                if (AudioLinkIsAvailable())
                {
                    audioData.x = AudioLinkData(ALPASS_AUDIOBASS).r;
                    
                    // Only apply displacement if bass exceeds threshold (for visual punch)
                    if (audioData.x > _ThresholdBass)
                    {
                        // Minimal, optimized displacement
                        float displacement = (audioData.x - _ThresholdBass) * 0.2 * _AudioReactivity;
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
                    // Return black when no audio is available instead of default colors
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
                if (audioSum < 0.05)
                {
                    // Return black when audio is too low
                    return fixed4(0, 0, 0, 1);
                }
                
                // Create audio-reactive field
                float time = _Time.y;
                float3 fieldColor = createField(i.uv, time, audioData);
                
                // Apply texture
                float4 texColor = tex2D(_MainTex, i.uv);
                
                // Final color with emission and texture
                float3 finalColor = fieldColor * texColor.rgb * _EmissionStrength;
                
                // Scale by audio reactivity
                finalColor *= 1.0 + audioSum * 0.25 * _AudioReactivity;
                
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
