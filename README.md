# Yutani-Particle-Engine
  A high-performance, threaded VCL Raylib component for 3D GPU Particles. Demonstrates how to batch render thousands of particles efficiently.
      
Yutani-Particle-Engine v0.3    
     
A custom, high-performance 3D particle engine written in pure Delphi.     
        
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/LaMitaOne/Yutani-Particle-Engine)     
       
<img width="983" height="695" alt="Unbenannt" src="https://github.com/user-attachments/assets/480ba8bb-ee24-41d3-b90d-ac62cb68f408" />
      
70k particles, 57fps at ryzen 4500u      
     
Instead of relying on complex GPU compute shaders or bloated external VFX engines, this project implements a highly optimized, CPU-driven particle simulation that feeds directly into Raylib's internal render batching system. It is designed to spawn and render thousands of particles in real-time without dropping frames.      
      
🚀 Key Features     

Matrix-Batched Rendering: Instead of issuing thousands of individual draw calls, the engine uses `rlPushMatrix`, `rlTranslatef`, and `rlScalef` in combination with `DrawMesh`/`DrawTriangle3D`. Raylib's internal RenderBatch groups these effortlessly, allowing for massive performance.      
2D/3D Hybrid Support: The engine includes a dynamic setting to switch between render shapes. Users can choose 2D Billboards (flattened quads facing the camera), 3D Cubes, or 3D Spheres. 2D Billboards are significantly faster and ideal for dense smoke or fire, utilizing only 4 vertices per particle.     
Custom Physics Simulation: Implements basic Euler integration for particle kinematics, including gravity, drag (air resistance), and lifespan progression.    
Per-Particle State Lerp: Smoothly interpolates size and color (RGBA) from spawn to death, allowing for realistic fading smoke and cooling fireballs.     
Zero-Gravity Smoke: Specific emitters (like smoke) can bypass gravity entirely, allowing them to linger and rise naturally.     
Real-time Generation: Particles are spawned, simulated, and culled entirely at runtime without any pre-computation.     
Pre-Allocated Memory: Arrays are pre-allocated to their maximum capacity to prevent memory fragmentation and CPU overhead during massive spawn bursts.    
Thread-Safe: Utilizes a `TCriticalSection` to prevent array resize crashes when emitting particles from external VCL UI threads.     
     
📦 The Sample Project    
    
To demonstrate the engine in action, a demo application is included.    
Start: Clicking Start Engine initializes the 3D scene.    
The Scene: A 3D grid is rendered, acting as the stage for the particles.    
Fog: Clicking Fog instantly spawns 5,000 low-alpha, zero-gravity gray particles spread across a wide area, simulating a dense fog bank that slowly rises and fades.    
Expl: Clicking Expl triggers a massive explosion, spawning 10,000 red fire particles and applying outward velocity, gravity, and air resistance.    
Performance Tuning: A TrackBar at the top allows you to dynamically change the Target FPS of the render thread (from 1 up to 5000 FPS) to test the engine's limits.    
    
📁 Repository Structure    
Yutani.Render.Particles.pas - The core engine unit (can be dropped into any Raylib project).    
uParticleEngine.pas - The threaded engine wrapper handling the QPC frame pacing and rendering loop.    
Unit1.pas - The VCL demo form containing the UI controls.    
    
🛠️ Requirements    
Delphi: Tested with Delphi 12 (should work on Delphi 10.4 and newer due to record operator syntax).    
Raylib Pascal Bindings: Required to compile the included sample application (Raylib, rlgl, RayMath).    
Raylib DLL: The compiled raylib.dll must be in the executable directory.    
