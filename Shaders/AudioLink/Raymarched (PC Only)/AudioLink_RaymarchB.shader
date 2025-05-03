// **************************************************
// **************** Mayce's Shaders *****************
// **************************************************
// https://github.com/m4yc3x

Shader "Mayce/AudioLink/AudioLink_RaymarchB"
{
    Properties
    {
        [Header(Saturn Properties)]
        _PlanetRadius ("Planet Radius", Range(1,5)) = 2.5
        _RingInnerRadius ("Ring Inner Radius", Range(0.001,6)) = 3.5
        _RingOuterRadius ("Ring Outer Radius", Range(0.001,10)) = 6.5
        _RingThickness ("Ring Thickness", Range(0.01,0.5)) = 0.1
        
        [Header(Colors)]
        [HDR] _PlanetColor1 ("Planet Base Color", Color) = (0.9, 0.7, 0.4, 1)
        [HDR] _PlanetColor2 ("Planet Accent Color", Color) = (0.8, 0.5, 0.3, 1)
        [HDR] _RingColor1 ("Ring Inner Color", Color) = (0.7, 0.6, 0.4, 1)
        [HDR] _RingColor2 ("Ring Outer Color", Color) = (0.5, 0.4, 0.3, 1)
        _ColorBlend ("Color Blend", Range(0,1)) = 0.5
        _BandDetail ("Band Detail", Range(1,10)) = 5
        _PlanetDetail ("Planet Detail", Range(0,2)) = 0.7
        
        [Header(Animation)]
        _RotationSpeed ("Rotation Speed", Range(0,1)) = 0.2
        _RingRotationSpeed ("Ring Rotation Speed", Range(0,1)) = 0.1
        
        [Header(Rendering)]
        _EmissionIntensity ("Emission Intensity", Range(0,3)) = 1.0
        _MaxSteps ("Max Ray Steps", Range(10,200)) = 64
        _MaxDistance ("Max Ray Distance", Range(10,50)) = 30
        _SurfaceDistance ("Surface Distance", Range(0.001,0.1)) = 0.01
        
        [Header(AudioLink)]
        _AudioSmoothing ("Audio Smoothing", Range(0,0.95)) = 0.8
        _BassIntensity ("Bass Ring Effect", Range(0,2)) = 0.7
        _MidIntensity ("Mid Ring Effect", Range(0,2)) = 0.6
        _TrebleIntensity ("Treble Ring Effect", Range(0,2)) = 0.5
        _RingAmplitude ("Ring Wave Amplitude", Range(0,1)) = 0.3
        _RingFrequency ("Ring Wave Frequency", Range(1,20)) = 8
        
        [Header(Lighting)]
        _LightIntensity ("Light Intensity", Range(0,2)) = 1.2
        _AmbientLight ("Ambient Light", Range(0,1)) = 0.3
        _SpecularPower ("Specular Power", Range(1,50)) = 8
        _SpecularIntensity ("Specular Intensity", Range(0,2)) = 1.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        Cull Back // Changed from Front to Back since we're looking at the inside face

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
                float4 vertex : SV_POSITION;
                float3 ro : TEXCOORD1;
                float3 hitPos : TEXCOORD2;
                float3 normal : TEXCOORD3;
                UNITY_FOG_COORDS(4)
            };

            float _PlanetRadius;
            float _RingInnerRadius;
            float _RingOuterRadius;
            float _RingThickness;
            float4 _PlanetColor1;
            float4 _PlanetColor2;
            float4 _RingColor1;
            float4 _RingColor2;
            float _ColorBlend;
            float _BandDetail;
            float _PlanetDetail;
            float _RotationSpeed;
            float _RingRotationSpeed;
            float _EmissionIntensity;
            float _MaxSteps;
            float _MaxDistance;
            float _SurfaceDistance;
            float _AudioSmoothing;
            float _BassIntensity;
            float _MidIntensity;
            float _TrebleIntensity;
            float _RingAmplitude;
            float _RingFrequency;
            float _LightIntensity;
            float _AmbientLight;
            float _SpecularPower;
            float _SpecularIntensity;

            // Audio data smoothing
            float smoothAudioValue(float audioValue, float smoothing) {
                static float lastValue = 0;
                float smoothedValue = lerp(lastValue, audioValue, 1 - smoothing);
                lastValue = smoothedValue;
                return smoothedValue;
            }

            // Smooth minimum function for blending
            float smin(float a, float b, float k) {
                float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
                return lerp(b, a, h) - k * h * (1.0 - h);
            }

            // Rotation matrix
            float2x2 rot2D(float angle) {
                float s = sin(angle);
                float c = cos(angle);
                return float2x2(c, -s, s, c);
            }

            // Simplex noise functions for temporal distortion
            float3 mod289_3D(float3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
            float4 mod289_4D(float4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
            float4 permute_4D(float4 x) { return mod289_4D(((x*34.0)+1.0)*x); }
            float4 taylorInvSqrt(float4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

            float snoise_3D(float3 v) {
                const float2 C = float2(1.0/6.0, 1.0/3.0);
                const float4 D = float4(0.0, 0.5, 1.0, 2.0);

                // First corner
                float3 i  = floor(v + dot(v, C.yyy));
                float3 x0 = v - i + dot(i, C.xxx);

                // Other corners
                float3 g = step(x0.yzx, x0.xyz);
                float3 l = 1.0 - g;
                float3 i1 = min(g.xyz, l.zxy);
                float3 i2 = max(g.xyz, l.zxy);

                float3 x1 = x0 - i1 + C.xxx;
                float3 x2 = x0 - i2 + C.yyy;
                float3 x3 = x0 - D.yyy;

                // Permutations
                i = mod289_3D(i);
                float4 p = permute_4D(permute_4D(permute_4D(
                    i.z + float4(0.0, i1.z, i2.z, 1.0))
                    + i.y + float4(0.0, i1.y, i2.y, 1.0))
                    + i.x + float4(0.0, i1.x, i2.x, 1.0));

                // Gradients: 7x7 points over a square, mapped onto an octahedron.
                // The ring size 17*17 = 289 is close to a multiple of 49 (49*6 = 294)
                float n_ = 0.142857142857;
                float3 ns = n_ * D.wyz - D.xzx;

                float4 j = p - 49.0 * floor(p * ns.z * ns.z);

                float4 x_ = floor(j * ns.z);
                float4 y_ = floor(j - 7.0 * x_);

                float4 x = x_ *ns.x + ns.yyyy;
                float4 y = y_ *ns.x + ns.yyyy;
                float4 h = 1.0 - abs(x) - abs(y);

                float4 b0 = float4(x.xy, y.xy);
                float4 b1 = float4(x.zw, y.zw);

                float4 s0 = floor(b0)*2.0 + 1.0;
                float4 s1 = floor(b1)*2.0 + 1.0;
                float4 sh = -step(h, float4(0,0,0,0));

                float4 a0 = b0.xzyw + s0.xzyw*sh.xxyy;
                float4 a1 = b1.xzyw + s1.xzyw*sh.zzww;

                float3 p0 = float3(a0.xy, h.x);
                float3 p1 = float3(a0.zw, h.y);
                float3 p2 = float3(a1.xy, h.z);
                float3 p3 = float3(a1.zw, h.w);

                // Normalise gradients
                float4 norm = taylorInvSqrt(float4(dot(p0,p0), dot(p1,p1), dot(p2,p2), dot(p3,p3)));
                p0 *= norm.x;
                p1 *= norm.y;
                p2 *= norm.z;
                p3 *= norm.w;

                // Mix final noise value
                float4 m = max(0.6 - float4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
                m = m * m;
                return 42.0 * dot(m*m, float4(dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3)));
            }

            // Temporal distortion function
            float3 temporalDistortion(float3 pos, float time, float4 audioData) {
                float bassValue = smoothAudioValue(audioData.x, _AudioSmoothing) * _BassIntensity;
                float midValue = smoothAudioValue(audioData.y, _AudioSmoothing) * _MidIntensity;
                float highValue = smoothAudioValue(audioData.w, _AudioSmoothing) * _TrebleIntensity;
                
                // Scale position for noise sampling (reduced scale for larger distortions)
                float3 scaledPos = pos * 0.15;
                
                // Create time-varying offsets with faster movement
                float timeScale = time * 0.5;
                float3 timeOffset = float3(timeScale * 0.7, timeScale * 0.9, timeScale * 0.5);
                
                // Sample noise at different frequencies and amplitudes with increased effect
                float noise1 = snoise_3D(scaledPos + timeOffset) * bassValue * 1.0;
                float noise2 = snoise_3D(scaledPos * 2.0 - timeOffset) * midValue * 0.7;
                float noise3 = snoise_3D(scaledPos * 4.0 + float3(timeOffset.y, timeOffset.z, timeOffset.x)) * highValue * 0.5;
                
                // Combine noise samples with increased amplitude
                return float3(
                    noise1 + noise2 * 0.7 + noise3 * 0.3,
                    noise2 + noise3 * 0.7 + noise1 * 0.3,
                    noise3 + noise1 * 0.7 + noise2 * 0.3
                ) * 2.0; // Overall increased effect
            }

            // Saturn's noise pattern for banding
            float planetNoise(float3 p, float bands) {
                // Create horizontal bands
                float bandNoise = sin(p.y * bands) * 0.5 + 0.5;
                
                // Add some distortion to the bands
                float distortion = sin(p.x * 3.0 + p.z * 2.0) * 0.1;
                bandNoise += distortion;
                
                return bandNoise;
            }

            // Ring noise pattern
            float ringNoise(float2 p, float time, float4 audioData) {
                // Basic ring pattern
                float dist = length(p);
                float angle = atan2(p.y, p.x);
                
                // Create bands in the rings
                float bands = sin(angle * 15.0) * 0.5 + 0.5;
                
                // Add time-based animation
                bands += sin(angle * 8.0 + time * 0.5) * 0.3;
                
                // Add audio reactivity to the bands
                float bassValue = smoothAudioValue(audioData.x, _AudioSmoothing) * _BassIntensity;
                float midValue = smoothAudioValue(audioData.y, _AudioSmoothing) * _MidIntensity;
                float trebleValue = smoothAudioValue(audioData.w, _AudioSmoothing) * _TrebleIntensity;
                
                // Audio-reactive ring waves
                float audioWave = sin(angle * _RingFrequency + time * 2.0) * bassValue * _RingAmplitude;
                audioWave += sin(angle * (_RingFrequency * 1.5) - time) * midValue * (_RingAmplitude * 0.7);
                audioWave += sin(angle * (_RingFrequency * 2.5) + time * 1.5) * trebleValue * (_RingAmplitude * 0.5);
                
                // Combine all effects
                return bands + audioWave;
            }

            // Signed Distance Functions
            float sdSphere(float3 p, float r) {
                return length(p) - r;
            }

            float sdRings(float3 p, float innerRadius, float outerRadius, float thickness, float time, float4 audioData) {
                // Rings should be flat on XZ plane
                float2 q = float2(length(p.xz), p.y);
                
                // Get audio values
                float bassValue = smoothAudioValue(audioData.x, _AudioSmoothing) * _BassIntensity;
                float lowMidValue = smoothAudioValue(audioData.y, _AudioSmoothing) * _MidIntensity;
                float highMidValue = smoothAudioValue(audioData.z, _AudioSmoothing) * _MidIntensity;
                float trebleValue = smoothAudioValue(audioData.w, _AudioSmoothing) * _TrebleIntensity;
                
                // Define base radius for each ring with much larger spacing
                float baseRadius = innerRadius;
                float ringGap = 1.5; // Large gap between rings
                
                float bassRingRadius = baseRadius + 0.0;  // Closest to planet
                float lowMidRingRadius = baseRadius + ringGap * 2.0;  // Second ring
                float highMidRingRadius = baseRadius + ringGap * 4.0;  // Third ring
                float trebleRingRadius = baseRadius + ringGap * 6.0;  // Outermost ring
                
                // Individual ring thicknesses
                float bassThickness = thickness * 1.2 * (1.0 + bassValue * 0.5);
                float lowMidThickness = thickness * 1.0 * (1.0 + lowMidValue * 0.4);
                float highMidThickness = thickness * 0.8 * (1.0 + highMidValue * 0.3);
                float trebleThickness = thickness * 0.6 * (1.0 + trebleValue * 0.2);
                
                // Calculate individual ring distances
                float bassRing = abs(length(p.xz) - bassRingRadius) - 0.4;
                float lowMidRing = abs(length(p.xz) - lowMidRingRadius) - 0.3;
                float highMidRing = abs(length(p.xz) - highMidRingRadius) - 0.2;
                float trebleRing = abs(length(p.xz) - trebleRingRadius) - 0.1;
                
                // Calculate angle for wave effects
                float angle = atan2(p.z, p.x);
                
                // Add wave patterns to each ring
                float bassWave = sin(angle * _RingFrequency + time * 2.0) * bassValue * _RingAmplitude * 0.2;
                float lowMidWave = sin(angle * (_RingFrequency * 1.5) - time * 1.5) * lowMidValue * _RingAmplitude * 0.15;
                float highMidWave = sin(angle * (_RingFrequency * 2.0) + time) * highMidValue * _RingAmplitude * 0.1;
                float trebleWave = sin(angle * (_RingFrequency * 2.5) - time * 0.5) * trebleValue * _RingAmplitude * 0.05;
                
                // Apply waves to rings
                bassRing -= bassWave;
                lowMidRing -= lowMidWave;
                highMidRing -= highMidWave;
                trebleRing -= trebleWave;
                
                // Apply vertical thickness to each ring
                bassRing = max(bassRing, abs(p.y) - bassThickness);
                lowMidRing = max(lowMidRing, abs(p.y) - lowMidThickness);
                highMidRing = max(highMidRing, abs(p.y) - highMidThickness);
                trebleRing = max(trebleRing, abs(p.y) - trebleThickness);
                
                // Combine rings using smooth minimum with a larger smoothing factor
                float k = 0.2; // Larger smoothing factor for softer blending
                float ring = bassRing;
                ring = smin(ring, lowMidRing, k);
                ring = smin(ring, highMidRing, k);
                ring = smin(ring, trebleRing, k);
                
                // Ensure rings stay separated from the planet
                float planetDist = length(p) - _PlanetRadius;
                float gap = 1.2; // Larger gap between planet and first ring
                ring = max(ring, -planetDist + gap);
                
                return ring;
            }

            // Scene distance function - optimized for Saturn and rings only
            float getDist(float3 p, float time, float4 audioData) {
                // Tilt Saturn to show rings at proper angle - rotate around X axis
                float tiltAngle = 0.4; // about 23 degrees
                float2x2 tiltMatrix = rot2D(tiltAngle);
                p.yz = mul(tiltMatrix, p.yz);
                
                // Rotate the scene
                p.xz = mul(rot2D(time * _RotationSpeed), p.xz);
                
                // Audio reactivity for planet size
                float bassValue = smoothAudioValue(audioData.x, _AudioSmoothing) * _BassIntensity;
                float midValue = smoothAudioValue(audioData.y, _AudioSmoothing) * _MidIntensity;
                
                // Scale planet based on audio - subtle effect (max 15% increase)
                float planetScale = 1.0 + bassValue * 0.15;
                
                // Calculate Saturn sphere with audio reactive size
                float saturn = sdSphere(p, _PlanetRadius * planetScale);
                
                // Calculate rings with audio reactivity - keep rings flat on XZ plane
                float3 ringPos = p;
                
                // Apply different rotation to rings
                ringPos.xz = mul(rot2D(time * _RingRotationSpeed), ringPos.xz);
                
                // Force rings to be thinner, with subtle audio reactivity in thickness
                // Base thickness with audio modulation (subtle, max +30% on peaks)
                float ringThicknessMod = _RingThickness * 0.3 * (1.0 + midValue * 0.3);
                
                // Use a more accurate ring SDF with audio-reactive thickness
                float rings = sdRings(ringPos, max(_PlanetRadius * planetScale + 0.7, _RingInnerRadius), 
                                      _RingOuterRadius, ringThicknessMod, time, audioData);
                
                // Return minimum distance but ensure the rings don't blend with the planet
                return min(saturn, rings);
            }

            // Determine material (0 = saturn, 1 = rings)
            int getMaterial(float3 p, float time, float4 audioData) {
                // Rotate just like in getDist to match
                p.xz = mul(rot2D(time * _RotationSpeed), p.xz);
                
                float saturn = sdSphere(p, _PlanetRadius);
                
                float3 ringPos = p;
                ringPos.xz = mul(rot2D(time * _RingRotationSpeed), ringPos.xz);
                float rings = sdRings(ringPos, _RingInnerRadius, _RingOuterRadius, _RingThickness, time, audioData);
                
                return (saturn < rings) ? 0 : 1;
            }

            // Get normal through numerical gradient (optimized with fewer samples)
            float3 getNormal(float3 p, float time, float4 audioData) {
                float2 e = float2(0.01, 0);
                
                // Use central differences for better accuracy with fewer samples
                float3 n = float3(
                    getDist(p + e.xyy, time, audioData) - getDist(p - e.xyy, time, audioData),
                    getDist(p + e.yxy, time, audioData) - getDist(p - e.yxy, time, audioData),
                    getDist(p + e.yyx, time, audioData) - getDist(p - e.yyx, time, audioData)
                );
                
                return normalize(n);
            }

            // Ray marching function (optimized with dynamic step size)
            float rayMarch(float3 ro, float3 rd, float time, float4 audioData, out int material) {
                float dO = 0;
                float lastDist = 1e10;
                material = -1;
                
                // Use a smaller minimum step size for better detail
                float stepMultiplier = 0.4;
                
                for(int i = 0; i < _MaxSteps; i++) {
                    float3 p = ro + rd * dO;
                    float dS = getDist(p, time, audioData);
                    
                    // Dynamic step size - smaller near surfaces, larger in empty space
                    // Use a more cautious step size to prevent overstepping thin features
                    dO += dS * stepMultiplier;
                    
                    // Increase step multiplier more gradually
                    stepMultiplier = min(0.9, stepMultiplier + 0.005);
                    
                    // Exit conditions
                    if(dO > _MaxDistance) break;
                    
                    // Use a stricter surface distance for the rings
                    float surfDist = _SurfaceDistance;
                    if(length(p.xz) > _PlanetRadius && abs(p.y) < _RingThickness * 2) {
                        surfDist = _SurfaceDistance * 0.5; // More precise for rings
                    }
                    
                    // If we're close enough to the surface
                    if(dS < surfDist) {
                        material = getMaterial(p, time, audioData);
                        break;
                    }
                    
                    lastDist = dS;
                }
                
                return dO;
            }

            // Calculate lighting
            float3 calculateLighting(float3 p, float3 rd, float3 normal, int material, float time, float4 audioData) {
                // Light position (sun-like, above and to the side)
                float3 lightPos = float3(10, 8, -5);
                float3 lightDir = normalize(lightPos - p);
                
                // Base diffuse lighting
                float diffuse = max(0, dot(normal, lightDir));
                diffuse = pow(diffuse, 0.8); // Soften diffuse
                
                // Specular lighting
                float3 reflectDir = reflect(-lightDir, normal);
                float spec = pow(max(0, dot(reflectDir, -rd)), _SpecularPower);
                float specular = spec * _SpecularIntensity;
                
                // Get material colors based on position and audio
                float3 color;
                float bassValue = smoothAudioValue(audioData.x, _AudioSmoothing) * _BassIntensity;
                float midValue = smoothAudioValue(audioData.y, _AudioSmoothing) * _MidIntensity;
                float trebleValue = smoothAudioValue(audioData.w, _AudioSmoothing) * _TrebleIntensity;
                
                if(material == 0) { // Saturn
                    // Create banded appearance for Saturn
                    float noise = planetNoise(p, _BandDetail);
                    
                    // Mix colors based on noise
                    float3 planetColor = lerp(_PlanetColor1.rgb, _PlanetColor2.rgb, noise);
                    
                    // Add some subtle audio reactivity to planet color
                    float colorPulse = bassValue * 0.15 + midValue * 0.1;
                    planetColor *= 1.0 + colorPulse;
                    
                    color = planetColor;
                    // Adjust specular for planet
                    specular *= 0.7;
                }
                else { // Rings
                    // Project point onto xz plane for ring UV
                    float2 ringUV = normalize(p.xz);
                    
                    // Calculate distance from center for color gradient
                    float dist = length(p.xz);
                    float ringGradient = saturate((dist - _RingInnerRadius) / (_RingOuterRadius - _RingInnerRadius));
                    
                    // Get noise pattern for rings
                    float noise = ringNoise(ringUV, time, audioData);
                    
                    // Mix ring colors
                    float3 ringColor = lerp(_RingColor1.rgb, _RingColor2.rgb, ringGradient);
                    
                    // Apply noise and audio effect to ring color - more subtle
                    ringColor *= 1.0 + noise * 0.3; // Reduce noise influence
                    
                    // Make audio reactivity more subtle to maintain consistent ring appearance
                    float ringColorMod = bassValue * 0.15 + midValue * 0.1 + trebleValue * 0.05;
                    ringColor *= 1.0 + ringColorMod;
                    
                    // Make rings more translucent by reducing brightness
                    color = ringColor * 0.9;
                    
                    // Rings are more reflective
                    specular *= 1.2;
                }
                
                // Combine lighting
                float3 finalColor = color * (_AmbientLight + diffuse * _LightIntensity) + specular * float3(1,1,1);
                return finalColor;
            }

            // Calculate shooting stars
            float4 getShootingStar(float2 uv, float time, float4 audioData, inout float brightness) {
                // Get audio reactivity data
                float trebleValue = smoothAudioValue(audioData.w, _AudioSmoothing) * _TrebleIntensity;
                float midValue = smoothAudioValue(audioData.y, _AudioSmoothing) * _MidIntensity;
                
                // Number of potential shooting stars (2-5 based on audio levels)
                int numStars = 2 + ceil(trebleValue * 3);
                
                // Initialize color
                float4 color = float4(0, 0, 0, 0);
                
                // Saturn's center in UV space (assuming it's centered)
                float2 saturnCenter = float2(0.5, 0.5);
                
                // Loop through potential shooting stars
                for(int i = 0; i < numStars; i++) {
                    // Each star has a different seed
                    float seed = 567.89 + i * 43.21;
                    
                    // Create a semi-random time offset for this star
                    float timeOffset = frac(sin(seed) * 12345.67);
                    
                    // Create a cycle for this star (varied durations)
                    float cycleDuration = 2.0 + frac(sin(seed * 7.89) * 3.0);
                    float cycleTime = frac((time + timeOffset) / cycleDuration);
                    
                    // Star is visible during a larger part of its cycle (based on audio reactivity)
                    float starVisibility = step(0.6 - midValue * 0.3, cycleTime);
                    
                    // Generate a random angle for the star's direction (full 360 degrees)
                    float angle = frac(sin(seed * 1.234 + time * 0.05) * 6.283) * 6.283185307179586;
                    
                    // Calculate the trail direction (perpendicular to movement)
                    float2 trailDir = normalize(float2(cos(angle), sin(angle)));
                    // Movement direction is perpendicular to trail
                    float2 moveDir = float2(-trailDir.y, trailDir.x);
                    
                    // Starting position (near Saturn's center with some variation)
                    float randomRadius = frac(sin(seed * 9.876) * 0.15); // Small random radius from center
                    float startAngle = frac(sin(seed * 3.456 + time * 0.1) * 6.283) * 6.283185307179586;
                    float2 offset = float2(cos(startAngle), sin(startAngle)) * randomRadius;
                    float2 basePos = saturnCenter + offset;
                    
                    // Calculate current position based on movement direction
                    float starProgress = (cycleTime - (0.6 - midValue * 0.3)) * (3.0 + i * 0.5); // Adjusted speed
                    float2 moveOffset = moveDir * starProgress;
                    float2 pos = basePos + moveOffset;
                    
                    // Calculate trail points perpendicular to movement
                    float trailLength = 0.2 + trebleValue * 0.15 + frac(sin(seed) * 0.1); // Longer trail length
                    float2 trailStart = pos - trailDir * (trailLength * 0.5);
                    float2 trailEnd = pos + trailDir * (trailLength * 0.5);
                    
                    // Line segment distance calculation
                    float2 pa = uv - trailStart;
                    float2 ba = trailEnd - trailStart;
                    float h = saturate(dot(pa, ba) / dot(ba, ba));
                    float2 d = pa - ba * h;
                    float dist = length(d);
                    
                    // Calculate width of trail (much thinner, with slight taper)
                    float baseWidth = 0.0005; // Much thinner base width
                    float tipWidth = 0.001; // Slightly wider at the tip
                    float width = lerp(baseWidth, tipWidth, h) + trebleValue * 0.0005;
                    
                    // Star brightness (falls off from center outward)
                    float fade = pow(1.0 - starProgress * 0.5, 1.5);
                    float starBrightness = smoothstep(width, 0.0, dist) * fade * starVisibility;
                    
                    // Distance from center fade (more gradual fade for longer trails)
                    float centerDist = length(pos - saturnCenter);
                    float centerFade = smoothstep(1.2, 0.4, centerDist); // Adjusted fade distances
                    starBrightness *= centerFade;
                    
                    // Add to total brightness for this pixel
                    brightness += starBrightness;
                    
                    // Star color - brighter core with colored tail
                    float3 starColor = float3(
                        1.0, // Brighter white core
                        0.98 + frac(sin(seed * 2.34) * 0.1),
                        0.95 + frac(sin(seed * 3.45) * 0.15)
                    );
                    
                    // Add subtle color variation along the trail
                    float3 tailColor = float3(
                        0.8 + frac(sin(seed * 1.23) * 0.2),
                        0.85 + frac(sin(seed * 2.34) * 0.15),
                        0.9
                    );
                    starColor = lerp(tailColor, starColor, abs(h - 0.5) * 2); // Brightest in the middle
                    
                    // Add this star to the result
                    color.rgb += starColor * starBrightness * 2.0; // Increased brightness
                }
                
                return color;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                
                // Set up camera position and view direction like in MusicVisualizerRaymarched shader
                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                
                // Position camera at a good viewing distance, slightly elevated
                o.ro = float3(0, 0, -12); // Fixed camera position in front of the cone
                o.hitPos = worldPos; // Let rays go toward each vertex of the cone
                o.normal = UnityObjectToWorldNormal(v.normal);
                
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
                
                // Generate starfield pattern - use a multi-layered approach for more natural stars
                float2 uv = i.uv;
                float stars = 0;
                
                // Create multi-layered stars
                for (int j = 0; j < 3; j++) {
                    float scale = 10.0 + j * 20.0;
                    float2 seed = uv * scale;
                    stars += pow(frac(sin(dot(seed, float2(12.9898 + j * 10.0, 78.233 + j * 20.0))) * 43758.5453), 20.0 + j * 10.0) * (0.15 - j * 0.03);
                }
                
                // Direct ray setup - match MusicVisualizerRaymarched approach
                float3 ro = i.ro;
                float3 rd = normalize(i.hitPos - ro);
                
                // Apply temporal distortion to both ray origin and direction
                float3 distortion = temporalDistortion(rd, time, audioData);
                ro += distortion * 0.3; // Apply distortion to ray origin
                rd += distortion * 0.5; // Increased distortion effect on ray direction
                rd = normalize(rd); // Renormalize after distortion
                
                // Position Saturn - create a scene offset 
                float3 sceneOffset = float3(0, 0, 6); // Move the scene forward in front of the camera
                
                // Perform ray marching with the adjusted scene
                int material;
                float d = rayMarch(ro - sceneOffset, rd, time, audioData, material);
                
                // Start with starfield as background
                float3 col = float3(0.01, 0.01, 0.05) + stars;
                
                // Add shooting stars
                float shootingStarBrightness = 0;
                float4 shootingStars = getShootingStar(uv, time, audioData, shootingStarBrightness);
                col += shootingStars.rgb;
                
                // Render Saturn if ray hit something
                if (d < _MaxDistance) {
                    float3 p = ro - sceneOffset + rd * d;
                    float3 normal = getNormal(p, time, audioData);
                    
                    // Calculate lighting
                    float3 planetCol = calculateLighting(p, rd, normal, material, time, audioData);
                    
                    // Apply emission intensity
                    planetCol *= _EmissionIntensity;
                    
                    // Apply distance fog - match MusicVisualizerRaymarched approach
                    float fogFactor = 1.0 - saturate(d / _MaxDistance);
                    planetCol = lerp(float3(0.01, 0.01, 0.03), planetCol, fogFactor);
                    
                    // Replace background completely where Saturn is visible
                    col = planetCol;
                }
                
                // Prevent over-saturation
                col = saturate(col);
                
                fixed4 final = fixed4(col, 1);
                UNITY_APPLY_FOG(i.fogCoord, final);
                return final;
            }
            ENDCG
        }
    }
}
