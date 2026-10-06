{*******************************************************************************
  ParticleEngine Demo Wrapper
********************************************************************************
  A minimal threaded VCL Raylib wrapper designed to demonstrate the
  Yutani.Render.Particles unit.
  It handles only the Raylib window, QPC frame pacing, and basic 3D setup,
  while delegating all particle logic to the TYutaniParticleEngine instance.

  Author: Lara Miriam Tamy Reschke / LamitaOne
*******************************************************************************}

unit uParticleEngine;

interface

uses
  System.SysUtils, System.Types, System.Classes, System.Math, System.SyncObjs,
  Winapi.Windows, Winapi.MMSystem, Vcl.Controls, Raylib, rlgl, RayMath,
  Yutani.Render.Particles;

const
  SPIN_THRESHOLD_NS = 2000000; // 2 ms threshold for spin-waiting

type
  // High-resolution timer using QueryPerformanceCounter (QPC)
  THighResTimer = record
    Frequency: Int64;
    procedure Init;
    function GetTicks: Int64; inline;
    procedure HybridWaitUntil(const ATargetTicks, ASpinNanoseconds: Int64);
  end;

  TParticleEngine = class(TThread)
  private
    FParentHandle: HWND;
    FRaylibWnd: HWND;
    FTargetFPS: Integer;
    FRealFPS: Integer;
    FActive: Boolean;
    FWidth, FHeight: Integer;

    // Our actual particle engine instance!
    FParticles: TYutaniParticleEngine;
    FCamera: TCamera3D;

    function GetSolidCubeReady: Boolean; // NEU: Für den Toggle-Button im Formular
    procedure RenderScene;
    procedure SetActive(const Value: Boolean);
  protected
    procedure Execute; override;
  public
    constructor Create(AParentHandle: HWND);
    destructor Destroy; override;

    procedure StartEngine;
    procedure StopEngine;

    // External Triggers
    procedure TriggerExplosion;
    procedure TriggerFog;
    procedure TriggerMaterializeCube(const TargetPos: TVector3);
    procedure TriggerDematerializeCube(const SourcePos: TVector3);

    procedure SetFPS(const FPS: Integer);
    procedure SetDimensions(const W, H: Integer);
    procedure SetRenderShape(ShapeIndex: Integer);
    procedure SetMaxParticles(MaxCount: Integer);

    property RealFPS: Integer read FRealFPS;
    property TargetFPS: Integer read FTargetFPS;
    property Active: Boolean read FActive write SetActive;
    property SolidCubeReady: Boolean read GetSolidCubeReady; // NEU!
  end;

implementation

{ THighResTimer }

procedure THighResTimer.Init;
begin
  if not QueryPerformanceFrequency(Frequency) then
    Frequency := 0;
end;

function THighResTimer.GetTicks: Int64;
begin
  QueryPerformanceCounter(Result);
end;

// Hybrid sleep strategy: Sleep(1) for long waits, SpinWait for short waits
// This prevents thread context switching overhead while maintaining high precision.
procedure THighResTimer.HybridWaitUntil(const ATargetTicks, ASpinNanoseconds: Int64);
var
  SpinTicks, Remaining: Int64;
begin
  if Frequency = 0 then
    Exit;
  SpinTicks := (ASpinNanoseconds * Frequency) div 1000000000;

  Remaining := ATargetTicks - GetTicks;
  while Remaining > SpinTicks do
  begin
    Sleep(1);
    Remaining := ATargetTicks - GetTicks;
  end;

  // Spin-wait the remaining time for exact frame pacing
  while GetTicks < ATargetTicks do
    ;
end;

{ TParticleEngine }

constructor TParticleEngine.Create(AParentHandle: HWND);
begin
  inherited Create(True); // Create suspended
  FreeOnTerminate := False;
  FParentHandle := AParentHandle;
  FTargetFPS := 60;
  FActive := False;
  FWidth := 800;
  FHeight := 600;

  // DO NOT create FParticles here! OpenGL context is not ready yet.
  FParticles := nil;

  // Default camera setup
  FCamera.position := Vector3Create(10.0, 10.0, 10.0);
  FCamera.target := Vector3Create(0, 1, 0);
  FCamera.up := Vector3Create(0, 1, 0);
  FCamera.fovy := 45.0;
  FCamera.projection := CAMERA_PERSPECTIVE;
end;

destructor TParticleEngine.Destroy;
begin
  StopEngine;
  // Free the particle engine if it was created in the Execute method
  if Assigned(FParticles) then
    FreeAndNil(FParticles);
  inherited;
end;

function TParticleEngine.GetSolidCubeReady: Boolean;
begin
  if Assigned(FParticles) then
    Result := FParticles.SolidCubeReady
  else
    Result := False;
end;

procedure TParticleEngine.SetDimensions(const W, H: Integer);
begin
  FWidth := W;
  FHeight := H;
  if FRaylibWnd <> 0 then
    SetWindowPos(FRaylibWnd, 0, 0, 0, FWidth, FHeight, SWP_NOZORDER or SWP_NOACTIVATE);
end;

procedure TParticleEngine.SetActive(const Value: Boolean);
begin
  if FActive <> Value then
  begin
    FActive := Value;
    if FActive then
    begin
      if Suspended then
        Start;
    end;
  end;
end;

procedure TParticleEngine.StartEngine;
begin
  Active := True;
end;

procedure TParticleEngine.StopEngine;
begin
  Active := False;
end;

procedure TParticleEngine.SetFPS(const FPS: Integer);
begin
  if FTargetFPS <> FPS then
    FTargetFPS := FPS;
end;

procedure TParticleEngine.SetRenderShape(ShapeIndex: Integer);
begin
  if Assigned(FParticles) then
  begin
    case ShapeIndex of
      0: FParticles.RenderShape := rsBillboard2D;
      1: FParticles.RenderShape := rsCube;
      2: FParticles.RenderShape := rsSphere;
    end;
  end;
end;

procedure TParticleEngine.SetMaxParticles(MaxCount: Integer);
begin
  if Assigned(FParticles) then
    FParticles.SetMaxParticles(MaxCount);
end;

procedure TParticleEngine.TriggerExplosion;
begin
  if Assigned(FParticles) then
    FParticles.EmitExplosion(Vector3Create(0, 1, 0), 10000, RED);
end;

procedure TParticleEngine.TriggerFog;
begin
  if Assigned(FParticles) then
    FParticles.EmitSmoke(Vector3Create(0, 1, 0), 5000, GRAY);
end;

procedure TParticleEngine.TriggerMaterializeCube(const TargetPos: TVector3);
begin
  if Assigned(FParticles) then
    FParticles.EmitMaterializeCube(TargetPos);
end;

procedure TParticleEngine.TriggerDematerializeCube(const SourcePos: TVector3);
begin
  if Assigned(FParticles) then
    FParticles.EmitDematerializeCube(SourcePos);
end;

procedure TParticleEngine.RenderScene;
var
  FpsStr: AnsiString;
  PartStr: AnsiString;
begin
  BeginDrawing();
  ClearBackground(BLACK);

  // Enable depth testing for 3D, disable backface culling for fragmented meshes
  rlEnableDepthTest();
  rlDisableBackfaceCulling();

  BeginMode3D(FCamera);
  DrawGrid(20, 1.0);

  // Draw the solid Cube ONLY if the materialization process is complete!
  if Assigned(FParticles) and FParticles.SolidCubeReady then
  begin
    DrawCube(Vector3Create(0, 0.5, 0), 1.0, 1.0, 1.0, BLUE);
    DrawCubeWires(Vector3Create(0, 0.5, 0), 1.0, 1.0, 1.0, DARKBLUE);
  end;

  // Delegate rendering entirely to our Yutani Particle Engine!
  if Assigned(FParticles) then
    FParticles.Render;

  EndMode3D();

  // Restore default states for 2D UI text rendering
  rlEnableBackfaceCulling();
  rlDisableDepthTest();

  FpsStr := AnsiString(Format('FPS: %d', [FRealFPS]));
  DrawText(PAnsiChar(FpsStr), 10, 10, 20, GREEN);

  if Assigned(FParticles) then
  begin
    PartStr := AnsiString(Format('Particles: %d', [FParticles.ParticleCount]));
    DrawText(PAnsiChar(PartStr), 10, 40, 20, YELLOW);
  end;

  EndDrawing();

  // Force VCL to update the parent control where Raylib is embedded
  if FRaylibWnd <> 0 then
    RedrawWindow(FRaylibWnd, nil, 0, RDW_INVALIDATE or RDW_UPDATENOW);
end;

procedure TParticleEngine.Execute;
var
  Timer: THighResTimer;
  Freq, FrameTicks: Int64;
  NextFrame, NowTicks, LastFrameTicks: Int64;
  DeltaSec: Double;
  FrameCount: Integer;
  LastFpsTime: Int64;
  WindowName: AnsiString;
begin
  // Increase Windows timer resolution for Sleep(1) accuracy
  {$IFDEF MSWINDOWS}
  timeBeginPeriod(1);
  {$ENDIF}
  try
    SetConfigFlags(FLAG_MSAA_4X_HINT);

    // Generate a unique window name to prevent handle collisions
    WindowName := AnsiString('ParticleEngine_' + IntToStr(IntPtr(Self)));
    InitWindow(FWidth, FHeight, PAnsiChar(WindowName));

    // Retrieve the newly created Raylib window handle and embed it into VCL
    FRaylibWnd := FindWindowA(nil, PAnsiChar(WindowName));
    if (FRaylibWnd <> 0) and (FParentHandle <> 0) then
    begin
      Winapi.Windows.SetParent(FRaylibWnd, FParentHandle);
      SetWindowLong(FRaylibWnd, GWL_STYLE, WS_CHILD or WS_VISIBLE);
      SetWindowPos(FRaylibWnd, 0, 0, 0, FWidth, FHeight, SWP_NOZORDER or SWP_NOACTIVATE);
    end;

    // CRITICAL FIX: Initialize Particle Engine HERE!
    // The OpenGL context is now active, so VRAM uploads (GenMeshSphere) will work.
    FParticles := TYutaniParticleEngine.Create;
    FParticles.Camera := FCamera;
    FParticles.RenderShape := rsBillboard2D;
    FParticles.SetMaxParticles(100000);

    // Initialize frame pacing timers
    Timer.Init;
    Freq := Timer.Frequency;
    if Freq <= 0 then
      Freq := 10000000;

    NowTicks := Timer.GetTicks;
    LastFrameTicks := NowTicks;
    NextFrame := NowTicks;
    LastFpsTime := NowTicks;
    FrameCount := 0;

    // Main Raylib Loop
    while not Terminated do
    begin
      if WindowShouldClose() then
        Break;

      NowTicks := Timer.GetTicks;
      DeltaSec := (NowTicks - LastFrameTicks) / Freq;
      LastFrameTicks := NowTicks;

      // Clamp delta time to avoid physics tunnelling on lag spikes
      if (DeltaSec <= 0) or (DeltaSec > 0.25) then
        DeltaSec := 1 / 60;

      if FActive then
      begin
        // Delegate updating to our Yutani Particle Engine!
        if Assigned(FParticles) then
          FParticles.Update(DeltaSec);
      end;

      RenderScene;

      // Real FPS calculation
      Inc(FrameCount);
      if (NowTicks - LastFpsTime) >= Freq then
      begin
        FRealFPS := Round(FrameCount * Freq / (NowTicks - LastFpsTime));
        FrameCount := 0;
        LastFpsTime := NowTicks;
      end;

      // Calculate exact deadline for the next frame
      if FTargetFPS > 0 then
        FrameTicks := Round(Freq / FTargetFPS)
      else
        FrameTicks := Freq div 60;

      NextFrame := NextFrame + FrameTicks;

      // If we are falling behind, reset NextFrame to current time to prevent fast-catching
      NowTicks := Timer.GetTicks;
      if (NowTicks - NextFrame) > Freq then
        NextFrame := NowTicks;

      // Wait precisely until the next frame deadline
      Timer.HybridWaitUntil(NextFrame, SPIN_THRESHOLD_NS);
    end;

  finally
    // Free the engine BEFORE we close the window!
    FreeAndNil(FParticles);

    if FRaylibWnd <> 0 then
      CloseWindow();

    {$IFDEF MSWINDOWS}
    timeEndPeriod(1);
    {$ENDIF}
  end;
end;

end.
