unit Yutani.Render.Particles;

{==============================================================================*
 *  Yutani Particle Engine v0.1 - Thread-Safe Matrix Batched Particle System
 *------------------------------------------------------------------------------
 *  Author : Lara Miriam Tamy Reschke / LamitaOne
 *
 *  Description:
 *    A robust, high-performance particle system using Raylib's standard
 *    matrix transformations. Uses rlPushMatrix and DrawMesh, which Raylib
 *    internally batches for massive render speed.
 *    Includes a TCriticalSection to prevent array resize crashes when
 *    emitting particles from external threads.
 *==============================================================================}

{$POINTERMATH ON}

interface

uses
  System.SysUtils, System.Classes, System.Math, System.SyncObjs,
  Raylib, RayMath, rlgl;

type
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
    IsSmoke: Boolean; // To handle zero-gravity for smoke
  end;

  TParticleEmissionType = (etExplosion, etSmoke, etSpark, etBeam);

  TYutaniParticleEngine = class
  private
    FParticles: array of TParticleInstance;
    FLock: TCriticalSection;
    FBaseMesh: TMesh;
    FMaterial: TMaterial;
    FGravity: Single;
    FDrag: Single;

    procedure InitializeBaseMesh;
    procedure SetDefaults(var P: TParticleInstance);
  public
    constructor Create;
    destructor Destroy; override;

    function ParticleCount: Integer;

    procedure Update(const dt: Single);
    procedure Render;

    procedure Emit(const Pos: TVector3; EmissionType: TParticleEmissionType;
      Count: Integer; const BaseColor: TColorB);
    procedure EmitExplosion(const Pos: TVector3; Count: Integer; const BaseColor: TColorB);
    procedure EmitSmoke(const Pos: TVector3; Count: Integer; const BaseColor: TColorB);
    procedure EmitSparks(const Pos: TVector3; Count: Integer; const BaseColor: TColorB);
    procedure EmitBeamSparkles(const Pos: TVector3; Count: Integer; const BaseColor: TColorB);

    property Gravity: Single read FGravity write FGravity;
    property Drag: Single read FDrag write FDrag;
  end;

implementation

const
  MAX_PARTICLES = 1000000; // 1 Million cap

{ TYutaniParticleEngine }

constructor TYutaniParticleEngine.Create;
begin
  inherited Create;
  SetLength(FParticles, 0);
  FLock := TCriticalSection.Create;

  FGravity := -9.81;
  FDrag := 0.5; // Low drag so particles flow smoothly

  InitializeBaseMesh;
end;

destructor TYutaniParticleEngine.Destroy;
begin
  FLock.Enter;
  try
    SetLength(FParticles, 0);
  finally
    FLock.Leave;
  end;
  FLock.Free;

  if FBaseMesh.vertices <> nil then
    UnloadMesh(FBaseMesh);

  inherited;
end;

procedure TYutaniParticleEngine.InitializeBaseMesh;
begin
  // Very low poly unit sphere (radius 0.5)
  FBaseMesh := GenMeshSphere(0.5, 6, 4);
  UploadMesh(@FBaseMesh, False);

  // Create a safe default material
  FMaterial := LoadMaterialDefault();
end;

procedure TYutaniParticleEngine.SetDefaults(var P: TParticleInstance);
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

procedure TYutaniParticleEngine.Emit(const Pos: TVector3; EmissionType: TParticleEmissionType;
  Count: Integer; const BaseColor: TColorB);
var
  i: Integer;
  P: TParticleInstance;
  RandSpeed: Single;
  DirX, DirY, DirZ: Single;
begin
  FLock.Enter;
  try
    for i := 0 to Count - 1 do
    begin
      if Length(FParticles) >= MAX_PARTICLES then Break;

      SetDefaults(P);
      P.Position := Pos;

      case EmissionType of
        etExplosion:
          begin
            DirX := Random * 2 - 1;
            DirY := Random * 2 - 1;
            DirZ := Random * 2 - 1;
            P.Velocity := Vector3Normalize(Vector3Create(DirX, DirY, DirZ));
            RandSpeed := 5 + (Random * 15);
            P.Velocity := Vector3Scale(P.Velocity, RandSpeed);
            P.MaxLife := 1.0 + (Random * 1.0);
            P.StartColor := BaseColor;
            P.EndColor := ColorAlpha(BLACK, 0);
            P.StartSize := 0.15;
            P.EndSize := 0.02;
          end;
        etSmoke:
          begin
            P.IsSmoke := True;
            P.Position.x := Pos.x + ((Random * 2 - 1) * 15.0);
            P.Position.z := Pos.z + ((Random * 2 - 1) * 15.0);
            P.Position.y := Pos.y + (Random * 5.0);

            P.Velocity.x := (Random * 2 - 1) * 0.2;
            P.Velocity.y := 0.5 + (Random * 0.8);
            P.Velocity.z := (Random * 2 - 1) * 0.2;

            P.MaxLife := 8.0 + (Random * 7.0);

            P.StartColor := ColorAlpha(BaseColor, 30);
            P.EndColor := ColorAlpha(BaseColor, 0);

            P.StartSize := 0.1;
            P.EndSize := 0.25;
          end;
        etSpark:
          begin
            DirX := Random * 2 - 1;
            DirY := Abs(Random * 2 - 1);
            DirZ := Random * 2 - 1;
            P.Velocity := Vector3Normalize(Vector3Create(DirX, DirY, DirZ));
            RandSpeed := 10 + (Random * 20);
            P.Velocity := Vector3Scale(P.Velocity, RandSpeed);
            P.MaxLife := 0.3 + (Random * 0.5);
            P.StartColor := BaseColor;
            P.EndColor := ColorAlpha(RED, 0);
            P.StartSize := 0.05;
            P.EndSize := 0.01;
          end;
        etBeam:
          begin
            P.Position.x := Pos.x + (Random * 2 - 1) * 1.5;
            P.Position.y := Pos.y + (Random * 100);
            P.Position.z := Pos.z + (Random * 2 - 1) * 1.5;
            P.Velocity.y := -1.0 - (Random * 2);
            P.MaxLife := 1.5 + (Random * 1.0);
            P.StartColor := WHITE;
            P.EndColor := ColorAlpha(BaseColor, 0);
            P.StartSize := 0.05;
            P.EndSize := 0.01;
          end;
      end;

      P.Life := P.MaxLife;
      P.Color := P.StartColor;
      P.Size := P.StartSize;

      SetLength(FParticles, Length(FParticles) + 1);
      FParticles[High(FParticles)] := P;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TYutaniParticleEngine.EmitExplosion(const Pos: TVector3; Count: Integer; const BaseColor: TColorB);
begin
  Emit(Pos, etExplosion, Count, BaseColor);
end;

procedure TYutaniParticleEngine.EmitSmoke(const Pos: TVector3; Count: Integer; const BaseColor: TColorB);
begin
  Emit(Pos, etSmoke, Count, BaseColor);
end;

procedure TYutaniParticleEngine.EmitSparks(const Pos: TVector3; Count: Integer; const BaseColor: TColorB);
begin
  Emit(Pos, etSpark, Count, BaseColor);
end;

procedure TYutaniParticleEngine.EmitBeamSparkles(const Pos: TVector3; Count: Integer; const BaseColor: TColorB);
begin
  Emit(Pos, etBeam, Count, BaseColor);
end;

function TYutaniParticleEngine.ParticleCount: Integer;
begin
  FLock.Enter;
  try
    Result := Length(FParticles);
  finally
    FLock.Leave;
  end;
end;

procedure TYutaniParticleEngine.Update(const dt: Single);
var
  i: Integer;
  P: PParticleInstance;
  Progress: Single;
  CurrentY, CurrentVel: Single;
  DeltaColor: TColorB;
  LastIdx: Integer;
begin
  FLock.Enter;
  try
    i := 0;
    while i <= High(FParticles) do
    begin
      P := @FParticles[i];

      P^.Life := P^.Life - dt;

      if P^.Life <= 0 then
      begin
        LastIdx := High(FParticles);
        if i <> LastIdx then
          Move(FParticles[LastIdx], FParticles[i], SizeOf(TParticleInstance));

        SetLength(FParticles, LastIdx);
        Continue;
      end;

      // Apply gravity ONLY if it's not smoke
      if not P^.IsSmoke then
      begin
        CurrentY := P^.Velocity.y + (FGravity * dt);
        P^.Velocity.y := CurrentY;
      end;

      // Apply drag (air resistance)
      CurrentVel := 1.0 - (FDrag * dt);
      if CurrentVel < 0 then CurrentVel := 0;
      P^.Velocity := Vector3Scale(P^.Velocity, CurrentVel);

      // Integrate position
      P^.Position := Vector3Add(P^.Position, Vector3Scale(P^.Velocity, dt));

      // Calculate life progress for Lerp operations
      Progress := 1.0 - (P^.Life / P^.MaxLife);
      if Progress > 1.0 then Progress := 1.0;
      if Progress < 0.0 then Progress := 0.0;

      // Lerp Size
      P^.Size := Lerp(P^.StartSize, P^.EndSize, Progress);

      // Lerp Color
      DeltaColor.r := Round(Lerp(P^.StartColor.r, P^.EndColor.r, Progress));
      DeltaColor.g := Round(Lerp(P^.StartColor.g, P^.EndColor.g, Progress));
      DeltaColor.b := Round(Lerp(P^.StartColor.b, P^.EndColor.b, Progress));
      DeltaColor.a := Round(Lerp(P^.StartColor.a, P^.EndColor.a, Progress));
      P^.Color := DeltaColor;

      Inc(i);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TYutaniParticleEngine.Render;
var
  i: Integer;
  P: PParticleInstance;
begin
  FLock.Enter;
  try
    if Length(FParticles) = 0 then Exit;

    // Enable Alpha Blending
    rlSetBlendMode(BLEND_ALPHA);

    // Draw using standard Raylib primitives.
    // DrawCube handles the tint color natively and safely.
    for i := 0 to High(FParticles) do
    begin
      P := @FParticles[i];

      // DrawCube(Position, Width, Height, Length, Color)
      DrawCube(P^.Position, P^.Size, P^.Size, P^.Size, P^.Color);
    end;

    // Flush batch and restore default blend mode
    rlDrawRenderBatchActive();
    rlSetBlendMode(BLEND_ALPHA);
  finally
    FLock.Leave;
  end;
end;

end.
