{*******************************************************************************
  Yutani Particle Demo Form v0.2
********************************************************************************
  VCL Wrapper demonstrating the Yutani Particle engine.
  Dynamically constructs UI controls and embeds the threaded Raylib renderer.
   Author: Lara Miriam Tamy Reschke / LamitaOne
*******************************************************************************}

unit Unit1;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms,
  Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls, uparticleengine;

type
  TForm1 = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormResize(Sender: TObject);
  private
    FEngine: TparticleEngine;
    btnStart: TButton;
    btnFog: TButton;
    btnExpl: TButton;
    pnlUI: TPanel;
    pnlRender: TPanel;
    tbFPS: TTrackBar;
    lblFPS: TLabel;
    cbRenderShape: TComboBox;
    FPSTimer: TTimer;
    tbMaxParticles: TTrackBar;
    lblMaxParticles: TLabel;

    procedure OnStartClick(Sender: TObject);
    procedure OnFogClick(Sender: TObject);
    procedure OnExplClick(Sender: TObject);
    procedure OnFPSTracking(Sender: TObject);
    procedure OnFPSTimer(Sender: TObject);
    procedure OnShapeChange(Sender: TObject);
    procedure OnMaxParticlesChange(Sender: TObject);
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation
{$R *.dfm}

procedure TForm1.FormCreate(Sender: TObject);
begin
  Caption := 'Yutani Particle Demo';
  Self.DoubleBuffered := True;
  Width := 1000; // Breiter gemacht für die neue Trackbar
  Height := 700;

  // 1. Render Panel: Hosts the Raylib child window
  pnlRender := TPanel.Create(Self);
  pnlRender.Parent := Self;
  pnlRender.Align := alClient;
  pnlRender.BevelOuter := bvNone;
  pnlRender.Caption := '';

  // 2. UI Panel: Contains buttons and trackbar
  pnlUI := TPanel.Create(Self);
  pnlUI.Parent := Self;
  pnlUI.Align := alTop;
  pnlUI.Height := 65;
  pnlUI.BevelOuter := bvNone;
  pnlUI.Caption := '';
  pnlUI.DoubleBuffered := True;
  pnlUI.BringToFront;

  // 3. Start Button
  btnStart := TButton.Create(Self);
  btnStart.Parent := pnlUI;
  btnStart.Caption := 'Start Engine';
  btnStart.Width := 120;
  btnStart.Left := 20;
  btnStart.Top := 10;
  btnStart.OnClick := OnStartClick;

  // 4. Fog Button
  btnFog := TButton.Create(Self);
  btnFog.Parent := pnlUI;
  btnFog.Caption := 'Fog';
  btnFog.Width := 80;
  btnFog.Left := 150;
  btnFog.Top := 10;
  btnFog.OnClick := OnFogClick;

  // 5. Explode Button
  btnExpl := TButton.Create(Self);
  btnExpl.Parent := pnlUI;
  btnExpl.Caption := 'Expl';
  btnExpl.Width := 80;
  btnExpl.Left := 240;
  btnExpl.Top := 10;
  btnExpl.OnClick := OnExplClick;

  // 6. FPS Label
  lblFPS := TLabel.Create(Self);
  lblFPS.Parent := pnlUI;
  lblFPS.Caption := 'Target: 60 | Real: 0 FPS';
  lblFPS.Left := 340;
  lblFPS.Top := 15;
  lblFPS.Width := 200;
  lblFPS.Font.Size := 10;

  // 7. FPS TrackBar
  tbFPS := TTrackBar.Create(Self);
  tbFPS.Parent := pnlUI;
  tbFPS.Min := 1;
  tbFPS.Max := 5000;
  tbFPS.Position := 60;
  tbFPS.Width := 120;
  tbFPS.Left := 540;
  tbFPS.Top := 10;
  tbFPS.OnChange := OnFPSTracking;

  // 8. Render Shape Combobox
  cbRenderShape := TComboBox.Create(Self);
  cbRenderShape.Parent := pnlUI;
  cbRenderShape.Style := csDropDownList;
  cbRenderShape.Left := 680;
  cbRenderShape.Top := 10;
  cbRenderShape.Width := 80;
  cbRenderShape.Items.Add('2D');
  cbRenderShape.Items.Add('Cube');
  cbRenderShape.Items.Add('Sphere');
  cbRenderShape.ItemIndex := 0;
  cbRenderShape.OnChange := OnShapeChange;

  // 9. Max Particles Label (NEU)
  lblMaxParticles := TLabel.Create(Self);
  lblMaxParticles.Parent := pnlUI;
  lblMaxParticles.Caption := 'Max Particles: 100000';
  lblMaxParticles.Left := 780;
  lblMaxParticles.Top := 3;
  lblMaxParticles.Width := 150;
  lblMaxParticles.Font.Size := 10;

  // 10. Max Particles TrackBar (NEU)
  tbMaxParticles := TTrackBar.Create(Self);
  tbMaxParticles.Parent := pnlUI;

  tbMaxParticles.Min := 0;       // 0 means 1 (clamped internally)
  tbMaxParticles.Max := 200000;  // 200k is plenty to test limits
  tbMaxParticles.Position := 100000;
  tbMaxParticles.Width := 150;
  tbMaxParticles.Left := 830;
  tbMaxParticles.Top := 33;
  tbMaxParticles.OnChange := OnMaxParticlesChange;

  // 11. UI Update Timer
  FPSTimer := TTimer.Create(Self);
  FPSTimer.Interval := 500;
  FPSTimer.OnTimer := OnFPSTimer;
  FPSTimer.Enabled := True;

  // Instantiate engine and bind to Render Panel handle
  FEngine := TparticleEngine.Create(pnlRender.Handle);
  FEngine.SetDimensions(pnlRender.Width, pnlRender.Height);
end;

procedure TForm1.FormResize(Sender: TObject);
begin
  if Assigned(FEngine) and Assigned(pnlRender) then
    FEngine.SetDimensions(pnlRender.Width, pnlRender.Height);
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  if Assigned(FEngine) then
  begin
    FEngine.StopEngine;
    FEngine.Terminate;
    FEngine.WaitFor;
    FEngine.Free;
  end;
end;

procedure TForm1.OnStartClick(Sender: TObject);
begin
  if Assigned(FEngine) then
  begin
    FEngine.StartEngine;
    FEngine.SetRenderShape(0);
    FEngine.SetMaxParticles(tbMaxParticles.Position); // Starte mit dem Trackbar-Wert
  end;
end;

procedure TForm1.OnFogClick(Sender: TObject);
begin
  if Assigned(FEngine) then
    FEngine.TriggerFog;
end;

procedure TForm1.OnExplClick(Sender: TObject);
begin
  if Assigned(FEngine) then
    FEngine.TriggerExplosion;
end;

procedure TForm1.OnFPSTracking(Sender: TObject);
begin
  if Assigned(FEngine) and Assigned(tbFPS) then
    FEngine.SetFPS(Round(tbFPS.Position));
end;

procedure TForm1.OnFPSTimer(Sender: TObject);
begin
  if Assigned(FEngine) and Assigned(lblFPS) then
    lblFPS.Caption := Format('Target: %d | Real: %d FPS', [FEngine.TargetFPS, FEngine.RealFPS]);
end;

procedure TForm1.OnShapeChange(Sender: TObject);
begin
  if Assigned(FEngine) and Assigned(cbRenderShape) then
    FEngine.SetRenderShape(cbRenderShape.ItemIndex);
end;

procedure TForm1.OnMaxParticlesChange(Sender: TObject);
begin
  // 1. Update the label IMMEDIATELY before sending the command to the thread!
  lblMaxParticles.Caption := Format('Max Particles: %d', [tbMaxParticles.Position]);

  // 2. Force the VCL to draw the label right now
  lblMaxParticles.Repaint;

  // 3. NOW send the command to the Raylib Thread
  // Because this happens after the label is drawn, the UI won't freeze!
  if Assigned(FEngine) then
    FEngine.SetMaxParticles(tbMaxParticles.Position);
end;

end.
