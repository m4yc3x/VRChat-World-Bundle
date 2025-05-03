using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class DancingFireflies : UdonSharpBehaviour
{
    [Header("Required References")]
    [Tooltip("Reference to the particle system component (REQUIRED)")]
    public ParticleSystem particleSystem;
    
    [Header("Appearance")]
    [Tooltip("Base color of the fireflies")]
    public Color baseColor = new Color(0.5f, 0.0f, 1.0f, 1.0f); // Purple
    
    [Tooltip("Emission intensity when audio is quiet")]
    public float minEmissionIntensity = 0.5f;
    
    [Tooltip("Maximum emission intensity when audio is loud")]
    public float maxEmissionIntensity = 5.0f;
    
    [Header("Movement")]
    [Tooltip("Base movement speed")]
    public float baseSpeed = 0.5f;
    
    [Tooltip("Maximum additional speed from audio")]
    public float audioSpeedBoost = 1.0f;
    
    [Tooltip("Sine wave amplitude for horizontal movement")]
    public float waveAmplitude = 2.0f;
    
    [Tooltip("Frequency of the sine wave")]
    public float waveFrequency = 1.0f;
    
    [Tooltip("Vertical movement range")]
    public float heightVariation = 1.0f;
    
    [Header("Emission")]
    [Tooltip("Base rate of particle emission")]
    public float baseEmissionRate = 10f;
    
    [Tooltip("Lifetime of particles in seconds")]
    public float particleLifetime = 10f;
    
    [Tooltip("Size of firefly particles")]
    public float particleSize = 0.15f;
    
    // AudioLink reference
    [Header("Audio")]
    [Tooltip("Reference to AudioLink GameObject (optional, will find automatically if left empty)")]
    public GameObject audioLinkGameObject;

    // Internal references
    private ParticleSystem.MainModule mainModule;
    private ParticleSystem.EmissionModule emissionModule;
    private ParticleSystem.ColorOverLifetimeModule colorModule;
    private Vector3 initialPosition;
    
    // Audio reactivity
    private float audioAmplitude = 0f;
    private float bassMagnitude = 0f;
    private float trebleMagnitude = 0f;
    
    void Start()
    {
        // Store the initial position
        initialPosition = transform.position;
        
        // Try to find AudioLink if not assigned
        if (audioLinkGameObject == null)
        {
            audioLinkGameObject = GameObject.Find("AudioLink");
        }
        
        // Make sure we have a reference to a particle system
        if (particleSystem != null)
        {
            // Cache the module references
            mainModule = particleSystem.main;
            emissionModule = particleSystem.emission;
            colorModule = particleSystem.colorOverLifetime;
            
            // Configure the particle system
            ConfigureParticleSystem();
        }
        else
        {
            Debug.LogError("[DancingFireflies] Particle System reference is required. Please assign a Particle System in the inspector.");
        }
    }
    
    void Update()
    {
        if (particleSystem == null) return;
        
        UpdateAudioData();
        UpdateParticleSystem();
    }
    
    private void ConfigureParticleSystem()
    {
        // Configure main settings
        mainModule.loop = true;
        mainModule.startLifetime = particleLifetime;
        mainModule.startSpeed = 0f; // We'll move particles in code
        mainModule.startSize = particleSize;
        mainModule.startColor = baseColor;
        
        // Configure emission
        emissionModule.rateOverTime = baseEmissionRate;
        
        // Configure color over lifetime if it's enabled
        if (colorModule.enabled)
        {
            // Create gradient for fade in/out
            Gradient gradient = new Gradient();
            gradient.SetKeys(
                new GradientColorKey[] { 
                    new GradientColorKey(baseColor, 0.0f),
                    new GradientColorKey(baseColor, 0.2f),
                    new GradientColorKey(baseColor, 0.8f),
                    new GradientColorKey(baseColor, 1.0f) 
                },
                new GradientAlphaKey[] { 
                    new GradientAlphaKey(0f, 0.0f),
                    new GradientAlphaKey(1f, 0.2f),
                    new GradientAlphaKey(1f, 0.8f),
                    new GradientAlphaKey(0f, 1.0f)
                }
            );
            colorModule.color = new ParticleSystem.MinMaxGradient(gradient);
        }
        
        // Start the system
        particleSystem.Play();
    }
    
    private void UpdateAudioData()
    {
        if (IsAudioLinkAvailable())
        {
            // Get AudioLink UdonBehaviour
            UdonBehaviour audioLink = (UdonBehaviour)audioLinkGameObject.GetComponent(typeof(UdonBehaviour));
            
            // Sample AudioLink data for each frequency band
            // Note: These variable names must match the ones in the AudioLink script
            if (audioLink != null)
            {
                // Try to get AudioLink data - use fallbacks if variables don't exist
                var bassVar = audioLink.GetProgramVariable("bass");
                bassMagnitude = bassVar != null ? (float)bassVar : 0f;
                
                var lowMidVar = audioLink.GetProgramVariable("lowMid");
                float lowMidMagnitude = lowMidVar != null ? (float)lowMidVar : 0f;
                
                var highMidVar = audioLink.GetProgramVariable("highMid");
                float highMidMagnitude = highMidVar != null ? (float)highMidVar : 0f;
                
                var trebleVar = audioLink.GetProgramVariable("treble");
                trebleMagnitude = trebleVar != null ? (float)trebleVar : 0f;
                
                // Combine for overall amplitude
                audioAmplitude = (bassMagnitude + lowMidMagnitude + highMidMagnitude + trebleMagnitude) * 0.25f;
                
                // Apply some dampening and smoothing
                audioAmplitude = Mathf.Clamp01(audioAmplitude);
                bassMagnitude = Mathf.Clamp01(bassMagnitude);
                trebleMagnitude = Mathf.Clamp01(trebleMagnitude);
            }
        }
        else
        {
            // Fade out audio reactivity if AudioLink is not available
            audioAmplitude = Mathf.Lerp(audioAmplitude, 0f, Time.deltaTime);
            bassMagnitude = Mathf.Lerp(bassMagnitude, 0f, Time.deltaTime);
            trebleMagnitude = Mathf.Lerp(trebleMagnitude, 0f, Time.deltaTime);
        }
    }
    
    private void UpdateParticleSystem()
    {
        if (particleSystem == null) return;
        
        // Update emission intensity based on audio
        Color currentColor = baseColor * Mathf.Lerp(minEmissionIntensity, maxEmissionIntensity, audioAmplitude);
        mainModule.startColor = currentColor;
        
        // Update emission rate based on audio
        float currentEmissionRate = baseEmissionRate * (1f + audioAmplitude * 2f);
        emissionModule.rateOverTime = currentEmissionRate;
        
        // Get access to particle data
        ParticleSystem.Particle[] particles = new ParticleSystem.Particle[mainModule.maxParticles];
        int numParticles = particleSystem.GetParticles(particles);
        
        if (numParticles <= 0) return;
        
        float time = Time.time;
        float audioSpeedMultiplier = 1f + (audioAmplitude * audioSpeedBoost);
        
        for (int i = 0; i < numParticles; i++)
        {
            // Generate unique offset for this particle based on its ID
            float particleOffset = (float)i / numParticles * 6.28f; // 0 to 2π
            
            // Calculate sine wave movement
            float sineWave = Mathf.Sin((time * waveFrequency + particleOffset) * audioSpeedMultiplier) * waveAmplitude;
            
            // Calculate vertical movement (affected by bass)
            float verticalOffset = Mathf.Sin((time * 0.7f + particleOffset * 1.3f) * (1f + bassMagnitude)) * heightVariation;
            
            // Calculate forward movement
            float forwardSpeed = baseSpeed * audioSpeedMultiplier;
            
            // Apply accumulated movement
            Vector3 newVelocity = new Vector3(
                sineWave * (1f + trebleMagnitude * 0.5f), // Horizontal sine wave affected by treble
                verticalOffset, // Vertical movement affected by bass
                forwardSpeed // Forward movement
            );
            
            particles[i].velocity = newVelocity;
        }
        
        // Apply particle changes
        particleSystem.SetParticles(particles, numParticles);
    }
    
    // Helper method to check if AudioLink is available
    private bool IsAudioLinkAvailable()
    {
        return audioLinkGameObject != null;
    }
}
