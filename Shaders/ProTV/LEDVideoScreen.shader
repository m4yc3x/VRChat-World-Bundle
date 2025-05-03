// **************************************************
// ************* Mayce's Quest Shaders **************
// **************************************************
// Go to the Main Screen material and substitute the shader with this one.
// https://github.com/m4yc3x

Shader "Mayce/ProTV/LEDVideoScreen"
{
    Properties
    {
        _MainTex("Standby Texture", 2D) = "black" {}
        _SoundTex("Sound-Only Texture", 2D) = "grey" {}
        _VideoTex("Video Texture (Render Texture from the TV goes here)", 2D) = "" {}
        _Aspect("Target Aspect Ratio (0 to ignore)", Float) = 1.77777
        _Brightness("Screen Brightness", Float) = 1
        _GIBrightness("Global Illumination Brightness", Float) = 3
        [Enum(Disabled, 0, Standard, 1, Dynamic, 2)] _Mirror("Mirror Flip Mode", Float) = 1
        [Enum(None, 0, Side by Side, 1, Side By Side Swapped, 2, Over Under, 3, Over Under Swapped, 4)] _3D("Standby 3D Mode", Float) = 0
        [Enum(Half Size 3D, 2, Full Size 3D, 0)] _Wide("Standby 3D Mode Size", Float) = 2
        [ToggleUI] _Force2D("Force Standby to 2D", Float) = 0
        [ToggleUI] _Clip("Clip Aspect", Float) = 0
        [ToggleUI] _Fog("Enable Fog", Float) = 1
        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Culling", Int) = 2
        
        // LED Simulation Properties
        _LEDSize("LED Size (pixels)", Float) = 4
        _LEDSpacing("LED Spacing", Float) = 0.1
        _LEDBrightness("LED Brightness", Float) = 1.5
        _LEDBlur("LED Blur", Range(0, 1)) = 0.2
    }
    SubShader
    {
        Tags
        {
            "PerformanceChecks" = "False"
        }
        Pass
        {
            Name "STANDARD"
            Tags
            {
                "Queue" = "AlphaTest+50" "LightMode" = "ForwardBase"
            }
            Cull [_Cull]
            CGPROGRAM
            // GPU Instancing support https://docs.unity3d.com/2022.3/Documentation/Manual/gpu-instancing-shader.html
            #pragma multi_compile_instancing
            #pragma multi_compile_fog
            #pragma vertex vertBase
            #pragma fragment fragBase
            #include "Packages/dev.architech.protv/Resources/Shaders/ProTVCore.cginc"

            // Use explicit sampler state to deal with the texture resizing
            Texture2D _VideoTex;
            SamplerState sampler_VideoTex;
            float4 _VideoTex_ST;
            float4x4 _VideoData;

            float _Clip;
            float _Aspect;
            float _Brightness;
            
            // LED Simulation Variables
            float _LEDSize;
            float _LEDSpacing;
            float _LEDBrightness;
            float _LEDBlur;

            struct vertdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct fragdata
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
                // fog support
                UNITY_FOG_COORDS(1)
            };

            fragdata vertBase(vertdata v)
            {
                fragdata o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_OUTPUT(fragdata, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.vertex = UnityObjectToClipPos(v.vertex);
                // fog support
                UNITY_TRANSFER_FOG(o, o.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 SampleLED(float2 uv, float2 ledPos, float2 ledSize, float4 videoColor)
            {
                // Calculate which third of the LED we're in (R,G,B)
                float3 subPixelMask = float3(0,0,0);
                float subPixelWidth = ledSize.x / 3.0;
                float localX = (uv.x - (ledPos.x - ledSize.x * 0.5)) / ledSize.x;
                
                // Add gaps between sub-pixels by shrinking each mask region
                float gapSize = 0.1; // 10% gap between sub-pixels
                float subPixelRegion = (1.0/3.0) * (1.0 - gapSize);
                float offset = gapSize / 6.0; // Center the shrunk regions
                
                // Determine which sub-pixel we're in with gaps
                if (localX < (1.0/3.0 - offset) && localX > offset) 
                    subPixelMask.r = 1.0;
                else if (localX < (2.0/3.0 - offset) && localX > (1.0/3.0 + offset)) 
                    subPixelMask.g = 1.0;
                else if (localX < (1.0 - offset) && localX > (2.0/3.0 + offset)) 
                    subPixelMask.b = 1.0;
                
                // Calculate distance from center of sub-pixel vertically
                float2 subPixelCenter = ledPos;
                subPixelCenter.x = ledPos.x - ledSize.x * 0.5 + subPixelWidth * (
                    localX < 1.0/3.0 ? 0.5 :
                    localX < 2.0/3.0 ? 1.5 :
                    2.5
                );
                
                float2 dist = abs(uv - subPixelCenter);
                dist.x /= subPixelWidth;
                dist.y /= ledSize.y;
                float d = max(dist.x, dist.y);
                
                // Apply blur to LED edges
                float ledIntensity = smoothstep(0.5 + _LEDBlur, 0.5 - _LEDBlur, d);
                
                // Apply the sub-pixel mask to the video color
                float3 maskedColor = videoColor.rgb * subPixelMask * ledIntensity * _LEDBrightness;
                
                // Add a slight glow effect between sub-pixels
                float glow = smoothstep(0.7, 0.3, d) * 0.2;
                maskedColor += videoColor.rgb * glow;
                
                return float4(maskedColor, videoColor.a);
            }

            float4 fragBase(const fragdata i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                // Calculate LED grid
                float2 ledSize = float2(_LEDSize, _LEDSize) / _ScreenParams.xy;
                float2 ledSpacing = float2(_LEDSpacing, _LEDSpacing) / _ScreenParams.xy;
                float2 totalSize = ledSize + ledSpacing;
                
                // Find the nearest LED position
                float2 ledPos = floor(i.uv / totalSize) * totalSize + ledSize * 0.5;
                
                // Sample the video texture at LED position
                fragproc data;
                data.inputUV = ledPos;
                data.videoTexture = _VideoTex;
                data.videoSampler = sampler_VideoTex;
                data.videoST = _VideoTex_ST;
                data.videoData = _VideoData;
                data.outputAspect = _Aspect;
                data.removeBorders = _Clip;
                float4 videoColor = ProcessFragment(data);
                
                // Sample the LED with RGB sub-pixels
                float4 tex = SampleLED(i.uv, ledPos, ledSize, videoColor);
                
                // Apply brightness adjustment
                tex = tex * _Brightness;
                
                // Apply fog
                #if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
                    if (_Fog) UNITY_APPLY_FOG(i.fogCoord, tex);
                #endif
                
                return tex;
            }
            ENDCG
        }

        // ------------------------------------------------------------------
        // Extracts information for lightmapping, GI (emission, albedo, ...)
        // This pass is not used during regular rendering.
        Pass
        {
            Name "META"
            Tags
            {
                "LightMode" = "Meta"
            }

            Cull Off

            CGPROGRAM
            #pragma vertex vert_meta
            #pragma fragment frag_meta2

            #pragma shader_feature EDITOR_VISUALIZATION
            #include "UnityStandardMeta.cginc"
            #include "Packages/dev.architech.protv/Resources/Shaders/ProTVCore.cginc"

            // Use explicit sampler state to deal with the texture resizing
            Texture2D _VideoTex;
            SamplerState sampler_VideoTex;
            float4 _VideoTex_ST;
            float4x4 _VideoData;

            float _Clip;
            float _Aspect;
            float _Brightness;
            float _GIBrightness;

            float4 frag_meta2(const v2f_meta i): SV_Target
            {
                UnityMetaInput o = (UnityMetaInput)0;

                fragproc procData;
                procData.inputUV = i.uv;
                procData.videoTexture = _VideoTex;
                procData.videoSampler = sampler_VideoTex;
                procData.videoST = _VideoTex_ST;
                procData.videoData = _VideoData;
                procData.outputAspect = _Aspect;
                procData.removeBorders = _Clip;
                float4 tex = ProcessFragment(procData);

                #ifdef EDITOR_VISUALIZATION
                    o.Albedo = half3(tex.rgb) * _Brightness;
                    o.VizUV = i.vizUV;
                    o.LightCoord = i.lightCoord;
                #else
                o.Albedo = half3(tex.rgb) * _Brightness;
                #endif
                o.Emission = half3(tex.rgb) * _GIBrightness;
                return UnityMetaFragment(o);
            }
            ENDCG
        }

        Pass
        {
            Name "SHADOWCASTER"
            Tags
            {
                "LightMode" = "ShadowCaster"
            }
            CGPROGRAM
            #pragma vertex vertShadow
            #pragma fragment fragShadow
            #pragma multi_compile_instancing
            #pragma multi_compile_shadowcaster
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            v2f vertShadow(const appdata v)
            {
                v2f o = (v2f)0;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                return o;
            }

            float4 fragShadow(v2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                return 0;
            }
            ENDCG
        }
    }
    FallBack "VertexLit"
    CustomEditor "VideoScreenGUI"
}