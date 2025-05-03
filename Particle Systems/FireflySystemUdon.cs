using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

[RequireComponent(typeof(ParticleSystem))]
public class FireflySystemUdon : UdonSharpBehaviour
{
    private ParticleSystem fireflyParticles;
    
    [Header("Firefly Settings")]
    public float spawnAreaSize = 10f;        // Size of the cubic area where fireflies spawn
    public int maxFireflies = 50;            // Maximum number of fireflies
    public float minSpeed = 0.2f;            // Minimum movement speed
    public float maxSpeed = 0.5f;            // Maximum movement speed
    public float glowMinIntensity = 0.2f;    // Minimum light intensity
    public float glowMaxIntensity = 1.0f;    // Maximum light intensity
    public float glowCycleSpeed = 1f;        // How fast the glow cycles
    public float fireflyLifetime = 10f;      // How long each firefly lives
    public float spawnRate = 5f;             // How many fireflies spawn per second
    
    void Start()
    {
        // Changed from OnEnable to Start for Udon compatibility
        fireflyParticles = GetComponent<ParticleSystem>();
        SetupParticleSystem();
    }

    public void SetupParticleSystem()
    {
        // Stop and clear before reconfiguring
        fireflyParticles.Stop();
        fireflyParticles.Clear();

        var main = fireflyParticles.main;
        main.loop = true;
        main.playOnAwake = true;
        main.maxParticles = maxFireflies;
        main.startLifetime = fireflyLifetime;  // Set finite lifetime
        main.startSpeed = 0f; // We'll control movement through velocity over lifetime
        main.startSize = 0.1f; // Small size for fireflies
        main.startColor = new Color(1f, 1f, 0.5f, 1f); // Slightly yellow tint
        main.simulationSpace = ParticleSystemSimulationSpace.World;
        main.cullingMode = ParticleSystemCullingMode.AlwaysSimulate;

        // Emission setup - continuous spawn rate instead of burst
        var emission = fireflyParticles.emission;
        emission.enabled = true;
        emission.rateOverTime = spawnRate;
        emission.SetBursts(new ParticleSystem.Burst[0]); // Clear any bursts

        // Shape setup
        var shape = fireflyParticles.shape;
        shape.enabled = true;
        shape.shapeType = ParticleSystemShapeType.Box;
        shape.scale = new Vector3(spawnAreaSize, spawnAreaSize, spawnAreaSize);

        // Movement setup
        var velocityOverLifetime = fireflyParticles.velocityOverLifetime;
        velocityOverLifetime.enabled = true;
        velocityOverLifetime.space = ParticleSystemSimulationSpace.World;
        
        // Random movement in all directions
        velocityOverLifetime.x = new ParticleSystem.MinMaxCurve(-maxSpeed, maxSpeed);
        velocityOverLifetime.y = new ParticleSystem.MinMaxCurve(-maxSpeed, maxSpeed);
        velocityOverLifetime.z = new ParticleSystem.MinMaxCurve(-maxSpeed, maxSpeed);

        // Color over lifetime for glowing effect with fade in/out
        var colorOverLifetime = fireflyParticles.colorOverLifetime;
        colorOverLifetime.enabled = true;
        
        // Create a curve that fades in, glows, and fades out
        Gradient gradient = new Gradient();
        gradient.SetKeys(
            new GradientColorKey[] { 
                new GradientColorKey(Color.white, 0.0f),
                new GradientColorKey(Color.white, 1.0f) 
            },
            new GradientAlphaKey[] {
                new GradientAlphaKey(0f, 0.0f),              // Start invisible
                new GradientAlphaKey(glowMaxIntensity, 0.1f), // Fade in
                new GradientAlphaKey(glowMaxIntensity, 0.4f), // Stay bright
                new GradientAlphaKey(glowMinIntensity, 0.5f), // Dim
                new GradientAlphaKey(glowMaxIntensity, 0.6f), // Brighten
                new GradientAlphaKey(glowMaxIntensity, 0.9f), // Stay bright
                new GradientAlphaKey(0f, 1.0f)               // Fade out
            }
        );
        
        colorOverLifetime.color = gradient;

        // Ensure the renderer is set up correctly
        var renderer = fireflyParticles.GetComponent<ParticleSystemRenderer>();
        renderer.renderMode = ParticleSystemRenderMode.Billboard;
        renderer.sortMode = ParticleSystemSortMode.Distance;

        // Start the system
        fireflyParticles.Play();
    }
}