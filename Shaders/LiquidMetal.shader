// **************************************************
// ************* Mayce's Quest Shaders **************
// **************************************************
// https://github.com/m4yc3x

Shader "Mayce/LiquidMetal"
{
    Properties
    {
        [Header(Base Properties)]
        _Color ("Liquid Color", Color) = (0.0, 0.0, 0.0, 0.8)
        _WaterDepth ("Liquid Depth", Range(0, 2)) = 0.5
        _Glossiness ("Smoothness", Range(0,1)) = 0.9
        _Metallic ("Metallic", Range(0,1)) = 0.0
        
        [Header(Wave Properties)]
        _WaveAmplitude ("Wave Amplitude", Range(0, 1)) = 0.05
        _WaveFrequency ("Wave Frequency", Range(0, 10)) = 2.0
        _WaveSpeed ("Wave Speed", Range(0, 5)) = 1.0
        
        [Header(Ripple Properties)]
        _RippleScale ("Ripple Scale", Range(0.1, 20)) = 5.0
        _RippleSpeed ("Ripple Speed", Range(0, 2)) = 0.5
        _RippleStrength ("Ripple Strength", Range(0, 1)) = 0.3
        _RippleDetail ("Ripple Detail", Range(1, 5)) = 3
        
        [Header(Reflection Properties)]
        _ReflectionStrength ("Reflection Strength", Range(0, 1)) = 0.7
        _Distortion ("Distortion", Range(0, 2)) = 0.5
    }
    
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        LOD 200
        
        // Base pass - handles lighting, reflections
        CGPROGRAM
        #pragma surface surf Standard fullforwardshadows alpha:fade
        #pragma target 3.0
        
        #include "UnityCG.cginc"
        
        struct Input
        {
            float2 uv_MainTex;
            float3 worldPos;
            float3 worldRefl;
            float3 viewDir;
            INTERNAL_DATA
        };
        
        fixed4 _Color;
        half _Glossiness;
        half _Metallic;
        float _WaveAmplitude;
        float _WaveFrequency;
        float _WaveSpeed;
        float _RippleScale;
        float _RippleSpeed;
        float _RippleStrength;
        int _RippleDetail;
        float _ReflectionStrength;
        float _Distortion;
        float _WaterDepth;
        
        // Simplex noise functions for organic ripples
        float3 mod289(float3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
        float2 mod289(float2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
        float3 permute(float3 x) { return mod289(((x*34.0)+1.0)*x); }
        
        float snoise(float2 v) {
            const float4 C = float4(0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439);
            float2 i = floor(v + dot(v, C.yy));
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
        
        // Domain warping for more complex ripple patterns
        float2 domainWarp(float2 uv, float time, float strength) {
            // Add more variation with extra noise layers at different frequencies and rotations
            float2 offset1 = float2(
                snoise(float2(uv.x * 0.7 + time * 0.3, uv.y * 0.9 - time * 0.4)),
                snoise(float2(uv.x * 0.8 - time * 0.2, uv.y * 0.7 + time * 0.5))
            );
            
            float2 warped = uv + offset1 * strength;
            
            float2 offset2 = float2(
                snoise(float2(warped.x * 1.3 - time * 0.2, warped.y * 1.2 + time * 0.3)),
                snoise(float2(warped.x * 1.2 + time * 0.3, warped.y * 1.3 - time * 0.2))
            );
            
            // Add a third layer of distortion to break up repeating patterns
            float2 furtherWarped = warped + offset2 * strength * 0.5;
            
            float2 offset3 = float2(
                snoise(float2(furtherWarped.x * 1.7 + time * 0.15, furtherWarped.y * 1.6 - time * 0.25)) * 0.3,
                snoise(float2(furtherWarped.y * 1.8 - time * 0.15, furtherWarped.x * 1.5 + time * 0.25)) * 0.3
            );
            
            return uv + offset1 * strength + offset2 * strength * 0.5 + offset3 * strength * 0.3;
        }
        
        // Calculate water height at a given point
        float waterHeight(float2 uv, float time) {
            // Base time for organic movement
            float morphTime = _Time.y * _RippleSpeed;
            
            // Calculate base coordinates with continuous morphing
            // Add some variation to the scale to break up repeating patterns
            float scaleVar = _RippleScale * (0.9 + 0.2 * sin(uv.x * 0.5 + uv.y * 0.3 + time * 0.2));
            float2 baseUV = uv * scaleVar;
            
            // Apply domain warping
            float2 warpedUV = domainWarp(baseUV, morphTime, _RippleStrength);
            
            // Create multiple layers of noise with different scales for detail
            float pattern = 0;
            float amplitude = 1.0;
            float frequency = 1.0;
            
            // Use a prime number of layers to avoid repeating patterns
            for (int i = 0; i < _RippleDetail; i++) {
                // Add time-based rotation to each layer with varying speeds for each layer
                float rotSpeed = 0.1 * (i + 1) * (1.0 + 0.2 * sin(morphTime * 0.1 * (i + 1)));
                float2x2 layerRot = float2x2(
                    cos(morphTime * rotSpeed), -sin(morphTime * rotSpeed),
                    sin(morphTime * rotSpeed), cos(morphTime * rotSpeed)
                );
                
                // Add slight variation to UV coordinates for each layer
                float2 layerOffset = float2(
                    sin(morphTime * 0.15 * (i + 1.3)),
                    cos(morphTime * 0.18 * (i + 1.7))
                ) * 0.1 * i;
                
                float2 rotatedUV = mul(layerRot, (warpedUV + layerOffset) * frequency);
                
                // Add slight phase shift for each layer
                float phaseShift = i * 0.7 + morphTime * 0.05 * (i + 1);
                
                pattern += snoise(rotatedUV + phaseShift) * amplitude;
                
                // Vary the amplitude reduction and frequency increase for each layer
                amplitude *= 0.45 + 0.1 * sin(i + morphTime * 0.2);
                frequency *= 1.8 + 0.4 * cos(i * 0.5 + morphTime * 0.1);
            }
            
            // Add some simple waves with different frequencies and phases
            float waves = 0;
            
            // Use multiple wave patterns with different directions and frequencies
            waves += sin(uv.x * _WaveFrequency + uv.y * _WaveFrequency * 0.5 + time * _WaveSpeed) * 0.5;
            waves += cos(uv.y * _WaveFrequency * 0.8 + uv.x * _WaveFrequency * 0.3 + time * _WaveSpeed * 1.3) * 0.3;
            waves += sin(uv.x * _WaveFrequency * 1.2 - uv.y * _WaveFrequency * 0.6 + time * _WaveSpeed * 0.7) * 0.2;
            waves *= _WaveAmplitude;
            
            // Use a different noise layer for additional high-frequency detail
            float2 detailUV = uv * _RippleScale * 3.0;
            float detail = snoise(detailUV + float2(time * 0.4, time * 0.6)) * 0.1 * _RippleStrength;
            
            return pattern * _RippleStrength + waves + detail;
        }
        
        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            float time = _Time.y;
            float2 uv = IN.worldPos.xz * 0.1;
            
            // Calculate water height and normal
            float h = waterHeight(uv, time);
            
            // Calculate normal by sampling heights at adjacent points
            float2 epsilon = float2(0.01, 0);
            float3 normal = normalize(float3(
                waterHeight(uv + epsilon.xy, time) - waterHeight(uv - epsilon.xy, time),
                0.05, // Control normal strength
                waterHeight(uv + epsilon.yx, time) - waterHeight(uv - epsilon.yx, time)
            ));
            
            // Reflection
            float3 worldRefl = WorldReflectionVector(IN, normal);
            float3 reflection = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, worldRefl + normal * _Distortion);
            
            // Fresnel effect for reflection
            float fresnel = pow(1.0 - saturate(dot(normal, normalize(IN.viewDir))), 5.0);
            
            // Apply water properties
            o.Albedo = _Color.rgb * _WaterDepth;
            o.Emission = reflection * _ReflectionStrength * fresnel;
            o.Normal = normal;
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Alpha = _Color.a;
        }
        ENDCG
        
        // Shadow casting pass
        Pass {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            #pragma multi_compile_shadowcaster
            #include "UnityCG.cginc"
            
            struct v2f {
                V2F_SHADOW_CASTER;
                float2 uv : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
            };
            
            float _WaveAmplitude;
            float _WaveFrequency;
            float _WaveSpeed;
            float _RippleScale;
            float _RippleSpeed;
            float _RippleStrength;
            
            // Reuse the noise and water height functions
            float3 mod289(float3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
            float2 mod289(float2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
            float3 permute(float3 x) { return mod289(((x*34.0)+1.0)*x); }
            
            float snoise(float2 v) {
                const float4 C = float4(0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439);
                float2 i = floor(v + dot(v, C.yy));
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
                
                // Add a third layer of distortion to break up repeating patterns
                float2 furtherWarped = warped + offset2 * strength * 0.5;
                
                float2 offset3 = float2(
                    snoise(float2(furtherWarped.x * 1.7 + time * 0.15, furtherWarped.y * 1.6 - time * 0.25)) * 0.3,
                    snoise(float2(furtherWarped.y * 1.8 - time * 0.15, furtherWarped.x * 1.5 + time * 0.25)) * 0.3
                );
                
                return uv + offset1 * strength + offset2 * strength * 0.5 + offset3 * strength * 0.3;
            }
            
            float waterHeight(float2 uv, float time) {
                // Simplified version for shadows
                float morphTime = _Time.y * _RippleSpeed;
                
                // Add variation to scale
                float scaleVar = _RippleScale * (0.9 + 0.2 * sin(uv.x * 0.5 + uv.y * 0.3 + time * 0.2));
                float2 baseUV = uv * scaleVar;
                
                float2 warpedUV = domainWarp(baseUV, morphTime, _RippleStrength);
                
                // Add multi-layered noise for more organic feel
                float pattern = snoise(warpedUV);
                pattern += snoise(warpedUV * 2.1 + float2(0.7, 0.3)) * 0.5;
                pattern += snoise(warpedUV * 4.3 + float2(0.2, 0.8)) * 0.25;
                
                // Multiple wave patterns
                float waves = 0;
                waves += sin(uv.x * _WaveFrequency + uv.y * _WaveFrequency * 0.5 + time * _WaveSpeed) * 0.5;
                waves += cos(uv.y * _WaveFrequency * 0.8 + uv.x * _WaveFrequency * 0.3 + time * _WaveSpeed * 1.3) * 0.3;
                waves += sin(uv.x * _WaveFrequency * 1.2 - uv.y * _WaveFrequency * 0.6 + time * _WaveSpeed * 0.7) * 0.2;
                waves *= _WaveAmplitude;
                
                return pattern * _RippleStrength + waves;
            }
            
            v2f vert(appdata_base v) {
                v2f o;
                float2 worldUV = mul(unity_ObjectToWorld, v.vertex).xz * 0.1;
                float height = waterHeight(worldUV, _Time.y);
                
                // Apply height to vertex
                v.vertex.y += height;
                
                o.uv = v.texcoord;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                return o;
            }
            
            float4 frag(v2f i) : SV_Target {
                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
    CustomEditor "ShaderGUI"
}
