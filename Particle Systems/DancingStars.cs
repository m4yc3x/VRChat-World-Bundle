using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class DancingStars : UdonSharpBehaviour
{
    [Header("Particle System")]
    [Tooltip("Reference to the particle system component (REQUIRED)")]
    public ParticleSystem particleSystem;
    
    [Header("Star Appearance")]
    [Tooltip("Base color of the stars")]
    public Color baseColor = new Color(1.0f, 1.0f, 1.0f, 1.0f);
    
    [Tooltip("Accent color for audio-reactive effects")]
    public Color accentColor = new Color(0.2f, 0.5f, 1.0f, 1.0f);
    
    [Tooltip("Size of star particles")]
    public float baseParticleSize = 0.5f;
    
    [Tooltip("Maximum additional size from audio")]
    public float audioSizeBoost = 0.5f;
    
    [Header("Emission Settings")]
    [Tooltip("Base emission rate of particles")]
    public float baseEmissionRate = 100f;
    
    [Tooltip("Maximum additional emission from audio")]
    public float audioEmissionBoost = 150f;
    
    [Tooltip("Lifetime of particles in seconds")]
    public float particleLifetime = 10f;
    
    [Tooltip("Maximum number of particles")]
    public int maxParticles = 2000;
    
    [Header("Movement Settings")]
    [Tooltip("Base movement speed")]
    public float baseSpeed = 0.5f;
    
    [Tooltip("Maximum additional speed from audio")]
    public float audioSpeedBoost = 2.0f;
    
    [Tooltip("Turbulence amount")]
    public float turbulenceAmount = 1.0f;
    
    [Header("Audio Reactivity")]
    [Tooltip("Overall audio reactivity (0-1)")]
    [Range(0, 1)]
    public float audioReactivity = 0.7f;
    
    [Tooltip("How quickly audio response changes")]
    [Range(0.1f, 10f)]
    public float responseSpeed = 5f;
    
    [Header("AudioLink Reference")]
    [Tooltip("Reference to the AudioLink object (optional)")]
    public GameObject audioLinkReference;
    
    // Internal variables
    private ParticleSystem.MainModule mainModule;
    private ParticleSystem.EmissionModule emissionModule;
    private ParticleSystem.ShapeModule shapeModule;
    private ParticleSystem.ColorOverLifetimeModule colorModule;
    
    // Audio values for each frequency band
    private float[] audioValues = new float[4]; // Bass, Low-mid, High-mid, Treble
    private float[] smoothedAudioValues = new float[4];
    private float audioSum = 0f;
    
    // AudioLink references
    private bool audioLinkAvailable = false;
    private UdonBehaviour audioLinkBehaviour;
    
    // Force stars to always be visible
    private bool systemInitialized = false;
    
    void Start()
    {
        if (particleSystem == null)
        {
            Debug.LogError("[DancingStars] Particle System reference is missing!");
            return;
        }
        
        // Find AudioLink
        FindAudioLink();
        
        // Cache module references
        mainModule = particleSystem.main;
        emissionModule = particleSystem.emission;
        shapeModule = particleSystem.shape;
        colorModule = particleSystem.colorOverLifetime;
        
        // Configure the particle system for stars
        SetupParticleSystem();
        
        // Start with particles already visible
        particleSystem.Clear();
        particleSystem.Emit(500);
        
        systemInitialized = true;
        Debug.Log("[DancingStars] System initialized");
    }
    
    void Update()
    {
        if (!systemInitialized) return;
        
        // Get audio data from AudioLink
        UpdateAudioData();
        
        // Update particle properties based on audio
        UpdateParticleEffects();
    }
    
    private void FindAudioLink()
    {
        // First try the direct reference
        if (audioLinkReference != null)
        {
            SetupAudioLinkFromReference(audioLinkReference);
            return;
        }
        
        // Try to find AudioLink by common names
        GameObject foundObject = GameObject.Find("AudioLink");
        if (foundObject != null)
        {
            SetupAudioLinkFromReference(foundObject);
            return;
        }
        
        foundObject = GameObject.Find("/AudioLink");
        if (foundObject != null)
        {
            SetupAudioLinkFromReference(foundObject);
            return;
        }
        
        foundObject = GameObject.Find("AudioLink(Clone)");
        if (foundObject != null)
        {
            SetupAudioLinkFromReference(foundObject);
            return;
        }
        
        Debug.LogWarning("[DancingStars] AudioLink not found. Stars will still be visible but not reactive to audio.");
    }
    
    private void SetupAudioLinkFromReference(GameObject obj)
    {
        audioLinkBehaviour = obj.GetComponent<UdonBehaviour>();
        if (audioLinkBehaviour != null)
        {
            Debug.Log("[DancingStars] Found AudioLink: " + obj.name);
            
            // Check if readback is enabled
            var dataAvailable = audioLinkBehaviour.GetProgramVariable("audioDataAvailable");
            if (dataAvailable != null && (bool)dataAvailable)
            {
                audioLinkAvailable = true;
                Debug.Log("[DancingStars] AudioLink data is available");
            }
            else
            {
                Debug.LogWarning("[DancingStars] AudioLink found but data is not available. Enable readback in AudioLink settings.");
            }
        }
        else
        {
            Debug.LogWarning("[DancingStars] AudioLink object found but has no UdonBehaviour component");
        }
    }
    
    private void SetupParticleSystem()
    {
        // Main module settings
        mainModule.loop = true;
        mainModule.startLifetime = particleLifetime;
        mainModule.startSpeed = baseSpeed;
        mainModule.startSize = baseParticleSize;
        mainModule.startColor = baseColor;
        mainModule.maxParticles = maxParticles;
        mainModule.simulationSpace = ParticleSystemSimulationSpace.World;
        
        // Emission settings - continuous emission rate
        emissionModule.rateOverTime = baseEmissionRate;
        
        // Shape module - emit in a sphere around the system
        shapeModule.shapeType = ParticleSystemShapeType.Sphere;
        shapeModule.radius = 15f;
        shapeModule.radiusThickness = 1f; // Emit from full volume
        
        // Color over lifetime - fade in quickly, stay visible, fade out slowly
        if (colorModule.enabled)
        {
            Gradient gradient = new Gradient();
            gradient.SetKeys(
                new GradientColorKey[] { 
                    new GradientColorKey(baseColor, 0.0f),
                    new GradientColorKey(baseColor, 1.0f)
                },
                new GradientAlphaKey[] { 
                    new GradientAlphaKey(0f, 0.0f),
                    new GradientAlphaKey(1f, 0.1f),
                    new GradientAlphaKey(1f, 0.9f),
                    new GradientAlphaKey(0f, 1.0f)
                }
            );
            colorModule.color = new ParticleSystem.MinMaxGradient(gradient);
        }
        
        // Start the particle system
        if (!particleSystem.isPlaying)
        {
            particleSystem.Play();
        }
    }
    
    private void UpdateAudioData()
    {
        // Default to no audio data
        for (int i = 0; i < 4; i++)
        {
            audioValues[i] = 0f;
        }
        
        // If AudioLink is not available, use simulated values
        if (!audioLinkAvailable || audioLinkBehaviour == null)
        {
            UseSimulatedAudio();
            return;
        }
        
        // Verify AudioLink data is still available
        var dataAvailable = audioLinkBehaviour.GetProgramVariable("audioDataAvailable");
        if (dataAvailable == null || !(bool)dataAvailable)
        {
            audioLinkAvailable = false;
            UseSimulatedAudio();
            return;
        }
        
        // Get audio data array from AudioLink
        float[] audioData = (float[])audioLinkBehaviour.GetProgramVariable("audioData");
        if (audioData == null || audioData.Length < 512)
        {
            UseSimulatedAudio();
            return;
        }
        
        // Get first value from each frequency band
        audioValues[0] = audioData[0]; // Bass (0,0)
        audioValues[1] = audioData[128]; // Low-mid (0,1)
        audioValues[2] = audioData[256]; // High-mid (0,2)
        audioValues[3] = audioData[384]; // Treble (0,3)
        
        // Amplify and clamp values
        for (int i = 0; i < 4; i++)
        {
            audioValues[i] = Mathf.Clamp01(audioValues[i] * 2.0f);
        }
        
        // Smooth values for nicer visual effect
        for (int i = 0; i < 4; i++)
        {
            smoothedAudioValues[i] = Mathf.Lerp(smoothedAudioValues[i], audioValues[i], 
                                               Time.deltaTime * responseSpeed);
        }
        
        // Calculate weighted sum of all frequencies
        audioSum = (smoothedAudioValues[0] + smoothedAudioValues[1] + 
                    smoothedAudioValues[2] + smoothedAudioValues[3]) / 4.0f;
        
        // Ensure there's always some activity
        audioSum = Mathf.Max(0.2f, audioSum);
    }
    
    private void UseSimulatedAudio()
    {
        // Generate fake audio reactivity based on time
        float time = Time.time;
        
        // Bass - slower oscillation
        smoothedAudioValues[0] = 0.3f + Mathf.Sin(time * 0.5f) * 0.3f;
        
        // Low-mid
        smoothedAudioValues[1] = 0.3f + Mathf.Sin(time * 0.7f + 1.0f) * 0.3f;
        
        // High-mid
        smoothedAudioValues[2] = 0.3f + Mathf.Sin(time * 0.9f + 2.0f) * 0.3f;
        
        // Treble - faster oscillation
        smoothedAudioValues[3] = 0.3f + Mathf.Sin(time * 1.1f + 3.0f) * 0.3f;
        
        // Always have some audio activity for visual interest
        audioSum = (smoothedAudioValues[0] + smoothedAudioValues[1] + 
                   smoothedAudioValues[2] + smoothedAudioValues[3]) / 4.0f;
    }
    
    private void UpdateParticleEffects()
    {
        // Get current particles to modify
        ParticleSystem.Particle[] particles = new ParticleSystem.Particle[mainModule.maxParticles];
        int numParticles = particleSystem.GetParticles(particles);
        
        if (numParticles <= 0) return;
        
        // Audio-reactive parameters
        float reactiveEmissionRate = baseEmissionRate + (audioEmissionBoost * audioSum * audioReactivity);
        float reactiveSize = baseParticleSize + (audioSizeBoost * smoothedAudioValues[3] * audioReactivity);
        
        // Update emission rate
        emissionModule.rateOverTime = reactiveEmissionRate;
        
        // Update particle size
        mainModule.startSize = reactiveSize;
        
        // Get audio values for different movement patterns
        float bassValue = smoothedAudioValues[0]; // Bass affects speed
        float midValue = (smoothedAudioValues[1] + smoothedAudioValues[2]) * 0.5f; // Mids affect horizontal motion
        float highValue = smoothedAudioValues[3]; // Highs affect vertical motion
        
        float time = Time.time;
        
        for (int i = 0; i < numParticles; i++)
        {
            // Calculate unique offset for this particle
            float particleOffset = (float)i / numParticles * 6.28f;
            
            // Calculate base speed affected by bass
            float speed = baseSpeed + (audioSpeedBoost * bassValue * audioReactivity);
            
            // Calculate motion direction with audio-reactive turbulence
            float xMotion = Mathf.Sin(time * 0.4f + particleOffset) * 
                          turbulenceAmount * (1.0f + midValue * audioReactivity);
            
            float yMotion = Mathf.Cos(time * 0.6f + particleOffset * 1.3f) * 
                          turbulenceAmount * (1.0f + highValue * audioReactivity);
            
            // Create final velocity
            Vector3 velocity = new Vector3(
                xMotion * speed * 0.5f,
                yMotion * speed * 0.5f,
                speed * 0.5f
            );
            
            // Apply velocity
            particles[i].velocity = velocity;
            
            // Adjust color based on audio
            Color particleColor = Color.Lerp(baseColor, accentColor, audioSum * audioReactivity);
            particleColor *= 1.0f + audioSum * 2.0f * audioReactivity; // Make brighter with audio
            particles[i].startColor = particleColor;
            
            // Scale particle size based on audio - individual particle sizing
            particles[i].startSize = reactiveSize * (0.8f + 0.4f * Mathf.PerlinNoise(i * 0.1f, time * 0.5f));
        }
        
        // Apply all changes to the particle system
        particleSystem.SetParticles(particles, numParticles);
    }
}

