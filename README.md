# Mayce's VRChat World Bundle

A comprehensive collection of shaders, games, and scripts for enhancing your VRChat worlds.

## Features

### AudioLink Shaders
A collection of audio-reactive shaders that respond to music in your world:

- **Fragment Only** - Lightweight audio-reactive shaders with minimal performance impact
  - AudioLinkA_FragmentOnly.shader
  - AudioLinkB_FragmentOnly.shader
  - AudioLinkC_FragmentOnly.shader

- **Vertex+Fragment** - More advanced audio visualization with vertex deformation
  - AudioLinkA_Vertex.shader
  - AudioLinkB_Vertex.shader
  - AudioLinkC_Vertex.shader
  - AudioLinkD_Vertex.shader
  - AudioLinkE_Vertex.shader
  - AudioLinkF_Vertex.shader
  - AudioLinkG_Vertex.shader
  - AudioLinkH_Vertex.shader

- **Raymarched (PC Only)** - High-end visual effects using raymarching techniques
  - AudioLink_RaymarchA.shader
  - AudioLink_RaymarchB.shader

### ProTV Integration
- **LEDVideoScreen.shader** - Creates a realistic LED screen effect for ProTV displays

### Truth or Dare Game
- Complete prefab with conversation starter questions
- Easily customizable for different themes or question sets
- Great for social worlds and party environments

### Particle Systems
Custom Udon scripts for creating dynamic particle effects:
- **DancingStars.cs** - Creates star-like particles
- **DancingFireflies.cs** - Generates firefly effects
- **FireflySystemUdon.cs** - Lightweight firefly system for ambient atmosphere

## Installation

1. Import the files or unitypackage
2. Add AudioLink to your project if you haven't already (required for audio-reactive features)
3. Import ProTV if you plan to use the LED screen shader

## Usage

### AudioLink Shaders
1. Create a new material
2. Select one of the included AudioLink shaders (i.e. Mayce/AudioLink/AudioLinkA_FragmentOnly)
3. Apply the material to objects in your world
4. Adjust parameters to achieve your desired effect

### Truth or Dare Game
1. Drag the TruthOrDareGame prefab into your scene
2. Position it where players can easily access it
3. Customize the questions in the inspector if desired

### Particle Systems
1. Create a new particle system in Unity
2. Attach the corresponding script (DancingStars, DancingFireflies, or FireflySystemUdon)
3. Configure parameters in the inspector

## Requirements
- Unity 2022.3.31f1 or newer
- VRChat SDK3
- AudioLink v0.2.5+ (for audio-reactive features)
- ProTV (for LED screen shader)

## Credits
Created by Mayce (m4yc3x)
- GitHub: https://github.com/m4yc3x

## License
Free for personal and commercial use in VRChat worlds.
Redistribution or resale of these assets is strictly prohibited.
