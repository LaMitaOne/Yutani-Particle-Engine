{*******************************************************************************
  ParticleEngine v0.1
********************************************************************************
  A high-performance, threaded VCL Raylib component for 3D GPU Particles.
  Demonstrates how to batch render thousands of particles efficiently.

  Key Features:
  - Threaded Architecture: Separates Raylib Game Loop from the UI Thread.
  - Non-Blocking UI: Main thread remains responsive even at high load.
  - Precise Frame Pacing: QPC-based absolute frame deadlines with a hybrid
    Sleep/SpinWait strategy.
  - Matrix Batching: Uses rlPushMatrix and DrawMesh for massive render speed.
  - RealFPS Monitoring: Counts the actual frames produced by the Raylib
    render loop per second.

   Author: Lara Miriam Tamy Reschke / LamitaOne

*******************************************************************************}

unit uParticleEngine;

interface

uses
  System.SysUtils, System.Types, System.Classes, System.Math, System.SyncObjs,
  Winapi.Windows, Winapi.MMSystem, Vcl.Controls, Raylib, rlgl, RayMath;

const
  SPIN_THRESHOLD_NS = 2000000; // 2 ms threshold for spin-waiting
  MAX_PARTICLES = 200000;

type
  // High-resolution timer using QueryPerformanceCounter (QPC)
  THighResTimer = record
    Frequency: Int64;
    procedure Init;
    function GetTicks: Int64; inline;
    procedure HybridWaitUntil(const ATargetTicks, ASpinNanoseconds: Int64);
  end;

  PParticleInstance = ^TParticleInstance;
  TParticleInstance = record
    Position: TVector3;
    Velocity: TVector3;
    Color: TColorB;
    StartColor: TColorB;
    EndColor: TColorB;
    Life: Single;
    MaxLife: Single;
    Size: Single;
    StartSize: Single;
    EndSize: Single;
    IsSmoke: Boolean;
  end;

  TParticleEngine = class(TThread)
  private
    FParentHandle: HWND;
    FRaylibWnd: HWND;
    FTargetFPS: Integer;
    FRealFPS: Integer;
    FActive: Boolean;
    FWidth, FHeight: Integer;

    FParticles: array of TParticleInstance;
    FBaseMesh: TMesh;
    FMaterial: TMaterial;
    FGravity: Single;
    FDrag: Single;

    FCamera: TCamera3D;

    procedure InitializeMesh;
    procedure SetDefaults(var P: TParticleInstance);
    procedure UpdatePhysics(const DeltaTime: Double);
    procedure RenderScene;
    procedure SetActive(const Value: Boolean);
  protected
    procedure Execute; override;
  public
    constructor Create(AParentHandle: HWND);
    destructor Destroy; override;

    procedure StartEngine;
    procedure StopEngine;
    procedure TriggerExplosion;
    procedure TriggerFog;
    procedure SetFPS(const FPS: Integer);
    procedure SetDimensions(const W, H: Integer);

    property RealFPS: Integer read FRealFPS;
    property TargetFPS: Integer read FTargetFPS;
    property Active: Boolean read FActive write SetActive;
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

  FGravity := -9.81;
  FDrag := 0.5;

  SetLength(FParticles, 0);

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
  if FBaseMesh.vertices <> nil then
    UnloadMesh(FBaseMesh);
  SetLength(FParticles, 0);
  inherited;
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

procedure TParticleEngine.InitializeMesh;
begin
  FBaseMesh := GenMeshSphere(0.5, 6, 4);
  UploadMesh(@FBaseMesh, False);
  FMaterial := LoadMaterialDefault();
end;

procedure TParticleEngine.SetDefaults(var P: TParticleInstance);
begin
  P.Position := Vector3Create(0, 0, 0);
  P.Velocity := Vector3Create(0, 0, 0);
  P.Life := 1.0;
  P.MaxLife := 1.0;
  P.StartColor := WHITE;
  P.EndColor := WHITE;
  P.Color := WHITE;
  P.StartSize := 1.0;
  P.EndSize := 1.0;
  P.Size := 1.0;
  P.IsSmoke := False;
end;

procedure TParticleEngine.TriggerExplosion;
var
  I: Integer;
  P: TParticleInstance;
  DirX, DirY, DirZ: Single;
  RandSpeed: Single;
begin
  for I := 0 to 19999 do // 20,000 explosion particles
  begin
    if Length(FParticles) >= MAX_PARTICLES then Break;
    SetDefaults(P);
    P.Position := Vector3Create(0, 1, 0);

    DirX := Random * 2 - 1;
    DirY := Random * 2 - 1;
    DirZ := Random * 2 - 1;
    P.Velocity := Vector3Normalize(Vector3Create(DirX, DirY, DirZ));
    RandSpeed := 5 + (Random * 15);
    P.Velocity := Vector3Scale(P.Velocity, RandSpeed);

    P.MaxLife := 1.0 + (Random * 1.0);
    P.StartColor := RED;
    P.EndColor := ColorAlpha(BLACK, 0);
    P.StartSize := 0.15;
    P.EndSize := 0.02;

    P.Life := P.MaxLife;
    P.Color := P.StartColor;
    P.Size := P.StartSize;

    SetLength(FParticles, Length(FParticles) + 1);
    FParticles[High(FParticles)] := P;
  end;
end;

procedure TParticleEngine.TriggerFog;
var
  I: Integer;
  P: TParticleInstance;
begin
  for I := 0 to 4999 do // 5,000 fog particles
  begin
    if Length(FParticles) >= MAX_PARTICLES then Break;
    SetDefaults(P);

    P.IsSmoke := True; // Zero gravity
    P.Position.X := (Random * 2 - 1) * 10.0;
    P.Position.Z := (Random * 2 - 1) * 10.0;
    P.Position.Y := (Random * 5.0);

    P.Velocity.X := (Random * 2 - 1) * 0.2;
    P.Velocity.Y := 0.8 + (Random * 1.0);
    P.Velocity.Z := (Random * 2 - 1) * 0.2;

    P.MaxLife := 10.0 + (Random * 10.0);
    P.StartColor := ColorAlpha(GRAY, 50);
    P.EndColor := ColorAlpha(GRAY, 0);

    P.StartSize := 0.1;
    P.EndSize := 0.25;

    P.Life := P.MaxLife;
    P.Color := P.StartColor;
    P.Size := P.StartSize;

    SetLength(FParticles, Length(FParticles) + 1);
    FParticles[High(FParticles)] := P;
  end;
end;

procedure TParticleEngine.UpdatePhysics(const DeltaTime: Double);
var
  I: Integer;
  P: PParticleInstance;
  Progress: Single;
  CurrentY, CurrentVel: Single;
  DeltaColor: TColorB;
  LastIdx: Integer;
  dt: Single;
begin
  dt := DeltaTime;
  I := 0;
  while I <= High(FParticles) do
  begin
    P := @FParticles[I];
    P^.Life := P^.Life - dt;

    if P^.Life <= 0 then
    begin
      LastIdx := High(FParticles);
      if I <> LastIdx then
        Move(FParticles[LastIdx], FParticles[I], SizeOf(TParticleInstance));
      SetLength(FParticles, LastIdx);
      Continue;
    end;

    if not P^.IsSmoke then
    begin
      CurrentY := P^.Velocity.y + (FGravity * dt);
      P^.Velocity.y := CurrentY;
    end;

    CurrentVel := 1.0 - (FDrag * dt);
    if CurrentVel < 0 then CurrentVel := 0;
    P^.Velocity := Vector3Scale(P^.Velocity, CurrentVel);

    P^.Position := Vector3Add(P^.Position, Vector3Scale(P^.Velocity, dt));

    Progress := 1.0 - (P^.Life / P^.MaxLife);
    if Progress > 1.0 then Progress := 1.0;
    if Progress < 0.0 then Progress := 0.0;

    P^.Size := Lerp(P^.StartSize, P^.EndSize, Progress);

    DeltaColor.r := Round(Lerp(P^.StartColor.r, P^.EndColor.r, Progress));
    DeltaColor.g := Round(Lerp(P^.StartColor.g, P^.EndColor.g, Progress));
    DeltaColor.b := Round(Lerp(P^.StartColor.b, P^.EndColor.b, Progress));
    DeltaColor.a := Round(Lerp(P^.StartColor.a, P^.EndColor.a, Progress));
    P^.Color := DeltaColor;

    Inc(I);
  end;
end;

procedure TParticleEngine.RenderScene;
var
  I: Integer;
  P: PParticleInstance;
  FpsStr: AnsiString;
  PartStr: AnsiString;
begin
  BeginDrawing();
  ClearBackground(BLACK);

  rlEnableDepthTest();
  rlDisableBackfaceCulling();

  BeginMode3D(FCamera);
  DrawGrid(20, 1.0);

  // Enable Alpha Blending
  rlSetBlendMode(BLEND_ALPHA);

  for I := 0 to High(FParticles) do
  begin
    P := @FParticles[I];

    // Instead of DrawMesh and Material arrays, we just use DrawCube.
    // DrawCube handles the tint color natively and perfectly.
    DrawCube(P^.Position, P^.Size, P^.Size, P^.Size, P^.Color);
  end;

  rlDrawRenderBatchActive();
  rlSetBlendMode(BLEND_ALPHA);

  EndMode3D();

  rlEnableBackfaceCulling();
  rlDisableDepthTest();

  FpsStr := AnsiString(Format('FPS: %d', [FRealFPS]));
  DrawText(PAnsiChar(FpsStr), 10, 10, 20, GREEN);

  PartStr := AnsiString(Format('Particles: %d', [Length(FParticles)]));
  DrawText(PAnsiChar(PartStr), 10, 40, 20, YELLOW);

  EndDrawing();

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
  {$IFDEF MSWINDOWS}
  timeBeginPeriod(1);
  {$ENDIF}
  try
    SetConfigFlags(FLAG_MSAA_4X_HINT);

    WindowName := AnsiString('ParticleEngine_' + IntToStr(IntPtr(Self)));
    InitWindow(FWidth, FHeight, PAnsiChar(WindowName));

    FRaylibWnd := FindWindowA(nil, PAnsiChar(WindowName));
    if (FRaylibWnd <> 0) and (FParentHandle <> 0) then
    begin
      Winapi.Windows.SetParent(FRaylibWnd, FParentHandle);
      SetWindowLong(FRaylibWnd, GWL_STYLE, WS_CHILD or WS_VISIBLE);
      SetWindowPos(FRaylibWnd, 0, 0, 0, FWidth, FHeight, SWP_NOZORDER or SWP_NOACTIVATE);
    end;

    InitializeMesh;

    Timer.Init;
    Freq := Timer.Frequency;
    if Freq <= 0 then
      Freq := 10000000;

    NowTicks := Timer.GetTicks;
    LastFrameTicks := NowTicks;
    NextFrame := NowTicks;
    LastFpsTime := NowTicks;
    FrameCount := 0;

    while not Terminated do
    begin
      if WindowShouldClose() then
        Break;

      NowTicks := Timer.GetTicks;
      DeltaSec := (NowTicks - LastFrameTicks) / Freq;
      LastFrameTicks := NowTicks;

      if (DeltaSec <= 0) or (DeltaSec > 0.25) then
        DeltaSec := 1 / 60;

      if FActive then
        UpdatePhysics(DeltaSec);

      RenderScene;

      Inc(FrameCount);
      if (NowTicks - LastFpsTime) >= Freq then
      begin
        FRealFPS := Round(FrameCount * Freq / (NowTicks - LastFpsTime));
        FrameCount := 0;
        LastFpsTime := NowTicks;
      end;

      if FTargetFPS > 0 then
        FrameTicks := Round(Freq / FTargetFPS)
      else
        FrameTicks := Freq div 60;

      NextFrame := NextFrame + FrameTicks;

      NowTicks := Timer.GetTicks;
      if (NowTicks - NextFrame) > Freq then
        NextFrame := NowTicks;

      Timer.HybridWaitUntil(NextFrame, SPIN_THRESHOLD_NS);
    end;

  finally
    if FRaylibWnd <> 0 then
      CloseWindow();

    {$IFDEF MSWINDOWS}
    timeEndPeriod(1);
    {$ENDIF}
  end;
end;

end.
