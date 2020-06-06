//
// Graphic Scene Engine, http://glscene.org
//
{
    This shader allows to apply multiple textures, gathering them from existing materials.
    This allows saving resources, since you can reference the textures of any material in
    any materialLibrary.
    Note that actually the component references a Material (not a texture) but
    it uses that material's texture. The referenced material settings will be ignored,
    but the texture's settings (like TextureMode, ImageGamma, ImageBrightness) will be used.
    Instead the local material settings (listed in the collection) will be used.
 }

unit GXS.TextureSharingShader;

interface

uses
  System.Classes,
  System.SysUtils,

  Scene.XOpenGL,
  GXS.Scene,
  Scene.VectorGeometry,
  GXS.Color,
  GXS.Material,
  Scene.Strings,
  GXS.VectorFileObjects,
  GXS.State,
  Scene.PersistentClasses,
  GXS.Coordinates,
  GXS.RenderContextInfo;

type
  TgxTextureSharingShader = class;

  TgxTextureSharingShaderMaterial = class(TInterfacedCollectionItem, IgxMaterialLibrarySupported)
  private
    FTextureMatrix: TMatrix;
    FNeedToUpdateTextureMatrix: Boolean;
    FTextureMatrixIsUnitary: Boolean;
    FLibMaterial: TgxLibMaterial;
    FTexOffset: TgxCoordinates2;
    FTexScale: TgxCoordinates2;
    FBlendingMode: TgxBlendingMode;
    FSpecular: TgxColor;
    FAmbient: TgxColor;
    FDiffuse: TgxColor;
    FEmission: TgxColor;
    FShininess: TgxShininess;
    FMaterialLibrary: TgxMaterialLibrary;
    FLibMaterialName: TgxLibMaterialName;
    procedure SetAmbient(const Value: TgxColor);
    procedure SetDiffuse(const Value: TgxColor);
    procedure SetEmission(const Value: TgxColor);
    procedure SetShininess(const Value: TgxShininess);
    procedure SetSpecular(const Value: TgxColor);
    procedure SetMaterialLibrary(const Value: TgxMaterialLibrary);
    procedure SetLibMaterialName(const Value: TgxLibMaterialName);
    procedure SetBlendingMode(const Value: TgxBlendingMode);
    procedure SetLibMaterial(const Value: TgxLibMaterial);
    procedure SetTexOffset(const Value: TgxCoordinates2);
    procedure SetTexScale(const Value: TgxCoordinates2);
    function GetTextureMatrix: TMatrix;
    function GetTextureMatrixIsUnitary: Boolean;
  protected
    procedure coordNotifychange(Sender: TObject);
    procedure OtherNotifychange(Sender: TObject);
    function GetDisplayName: string; override;
    function GetTextureSharingShader: TgxTextureSharingShader;
    // Implementing IVKMaterialLibrarySupported.
    function GetMaterialLibrary: TgxAbstractMaterialLibrary; virtual;
  public
    procedure Apply(var rci: TgxRenderContextInfo);
    procedure UnApply(var rci: TgxRenderContextInfo);
    constructor Create(Collection: TCollection); override;
    destructor Destroy; override;
    property LibMaterial: TgxLibMaterial read FLibMaterial write SetLibMaterial;
    property TextureMatrix: TMatrix read GetTextureMatrix;
    property TextureMatrixIsUnitary: Boolean read GetTextureMatrixIsUnitary;
  published
    property TexOffset: TgxCoordinates2 read FTexOffset write SetTexOffset;
    property TexScale: TgxCoordinates2 read FTexScale write SetTexScale;
    property BlendingMode: TgxBlendingMode read FBlendingMode write SetBlendingMode;
    property Emission: TgxColor read FEmission write SetEmission;
    property Ambient: TgxColor read FAmbient write SetAmbient;
    property Diffuse: TgxColor read FDiffuse write SetDiffuse;
    property Specular: TgxColor read FSpecular write SetSpecular;
    property Shininess: TgxShininess read FShininess write SetShininess;
    property MaterialLibrary: TgxMaterialLibrary read FMaterialLibrary write SetMaterialLibrary;
    property LibMaterialName: TgxLibMaterialName read FLibMaterialName write SetLibMaterialName;
  end;

  TgxTextureSharingShaderMaterials = class(TOwnedCollection)
  protected
    function GetItems(const AIndex: Integer): TgxTextureSharingShaderMaterial;
    procedure SetItems(const AIndex: Integer; const Value: TgxTextureSharingShaderMaterial);
    function GetParent: TgxTextureSharingShader;
  public
    function Add: TgxTextureSharingShaderMaterial;
    constructor Create(AOwner: TgxTextureSharingShader);
    property Items[const AIndex: Integer]: TgxTextureSharingShaderMaterial read GetItems write SetItems; default;
  end;

  TgxTextureSharingShader = class(TgxShader)
  private
    FMaterials: TgxTextureSharingShaderMaterials;
    FCurrentPass: Integer;
    procedure SetMaterials(const Value: TgxTextureSharingShaderMaterials);
  protected
    procedure DoApply(var rci: TgxRenderContextInfo; Sender: TObject); override;
    function DoUnApply(var rci: TgxRenderContextInfo): Boolean; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function AddLibMaterial(const ALibMaterial: TgxLibMaterial): TgxTextureSharingShaderMaterial;
    function FindLibMaterial(const ALibMaterial: TgxLibMaterial): TgxTextureSharingShaderMaterial;
  published
    property Materials: TgxTextureSharingShaderMaterials read FMaterials write SetMaterials;
  end;

//=======================================================================
implementation
//=======================================================================

//----------------------------------------------------------------------------
{ TgxTextureSharingShaderMaterial }
//----------------------------------------------------------------------------

procedure TgxTextureSharingShaderMaterial.Apply(var rci: TgxRenderContextInfo);
begin
  if not Assigned(FLibMaterial) then
    Exit;
  xglBeginUpdate;
  if Assigned(FLibMaterial.Shader) then
  begin
    case FLibMaterial.Shader.ShaderStyle of
      ssHighLevel: FLibMaterial.Shader.Apply(rci, FLibMaterial);
      ssReplace:
      begin
        FLibMaterial.Shader.Apply(rci, FLibMaterial);
        Exit;
      end;
    end;
  end;
  if not FLibMaterial.Material.Texture.Disabled then
  begin
    if not (GetTextureMatrixIsUnitary) then
    begin
      rci.gxStates.SetTextureMatrix(TextureMatrix);
    end;
  end;

  if moNoLighting in FLibMaterial.Material.MaterialOptions then
    rci.gxStates.Disable(stLighting);

  if stLighting in rci.gxStates.States then
  begin
    rci.gxStates.SetMaterialColors(cmFront,
      Emission.Color, Ambient.Color, Diffuse.Color, Specular.Color, Shininess);
    rci.gxStates.PolygonMode :=FLibMaterial.Material.PolygonMode;
  end
  else
    FLibMaterial.Material.FrontProperties.ApplyNoLighting(rci, cmFront);
  if (stCullFace in rci.gxStates.States) then
  begin
    case FLibMaterial.Material.FaceCulling of
      fcBufferDefault: if not rci.bufferFaceCull then
        begin
          rci.gxStates.Disable(stCullFace);
          FLibMaterial.Material.BackProperties.Apply(rci, cmBack);
        end;
      fcCull: ; // nothing to do
      fcNoCull:
      begin
        rci.gxStates.Disable(stCullFace);
        FLibMaterial.Material.BackProperties.Apply(rci, cmBack);
      end;
      else
        Assert(False);
    end;
  end
  else
  begin
    // currently NOT culling
    case FLibMaterial.Material.FaceCulling of
      fcBufferDefault:
      begin
        if rci.bufferFaceCull then
          rci.gxStates.Enable(stCullFace)
        else
          FLibMaterial.Material.BackProperties.Apply(rci, cmBack);
      end;
      fcCull: rci.gxStates.Enable(stCullFace);
      fcNoCull: FLibMaterial.Material.BackProperties.Apply(rci, cmBack);
      else
        Assert(False);
    end;
  end;

  // Apply Blending mode
  if not rci.ignoreBlendingRequests then
    case BlendingMode of
      bmOpaque:
      begin
        rci.gxStates.Disable(stBlend);
        rci.gxStates.Disable(stAlphaTest);
      end;
      bmTransparency:
      begin
        rci.gxStates.Enable(stBlend);
        rci.gxStates.Enable(stAlphaTest);
        rci.gxStates.SetBlendFunc(bfSrcAlpha, bfOneMinusSrcAlpha);
      end;
      bmAdditive:
      begin
        rci.gxStates.Enable(stBlend);
        rci.gxStates.Enable(stAlphaTest);
        rci.gxStates.SetBlendFunc(bfSrcAlpha, bfOne);
      end;
      bmAlphaTest50:
      begin
        rci.gxStates.Disable(stBlend);
        rci.gxStates.Enable(stAlphaTest);
        rci.gxStates.SetAlphaFunction(cfGEqual, 0.5);
      end;
      bmAlphaTest100:
      begin
        rci.gxStates.Disable(stBlend);
        rci.gxStates.Enable(stAlphaTest);
        rci.gxStates.SetAlphaFunction(cfGEqual, 1.0);
      end;
      bmModulate:
      begin
        rci.gxStates.Enable(stBlend);
        rci.gxStates.Enable(stAlphaTest);
        rci.gxStates.SetBlendFunc(bfDstColor, bfZero);
      end;
      else
        Assert(False);
    end;
  // Fog switch
  if moIgnoreFog in FLibMaterial.Material.MaterialOptions then
  begin
    if stFog in rci.gxStates.States then
    begin
      rci.gxStates.Disable(stFog);
      Inc(rci.fogDisabledCounter);
    end;
  end;

  if not Assigned(FLibMaterial.Material.TextureEx) then
  begin
    if Assigned(FLibMaterial.Material.Texture) then
      FLibMaterial.Material.Texture.Apply(rci);
  end
  else
  begin
    if Assigned(FLibMaterial.Material.Texture) and not FLibMaterial.Material.TextureEx.IsTextureEnabled(0) then
      FLibMaterial.Material.Texture.Apply(rci)
    else
    if FLibMaterial.Material.TextureEx.Count > 0 then
      FLibMaterial.Material.TextureEx.Apply(rci);
  end;

  if Assigned(FLibMaterial.Shader) then
  begin
    case FLibMaterial.Shader.ShaderStyle of
      ssLowLevel: FLibMaterial.Shader.Apply(rci, FLibMaterial);
    end;
  end;
  xglEndUpdate;
end;

procedure TgxTextureSharingShaderMaterial.coordNotifychange(Sender: TObject);
begin
  FNeedToUpdateTextureMatrix := True;
  GetTextureSharingShader.NotifyChange(Self);
end;

constructor TgxTextureSharingShaderMaterial.Create(Collection: TCollection);
begin
  inherited;
  FSpecular := TgxColor.Create(Self);
  FSpecular.OnNotifyChange := OtherNotifychange;
  FAmbient := TgxColor.Create(Self);
  FAmbient.OnNotifyChange := OtherNotifychange;
  FDiffuse := TgxColor.Create(Self);
  FDiffuse.OnNotifyChange := OtherNotifychange;
  FEmission := TgxColor.Create(Self);
  FEmission.OnNotifyChange := OtherNotifychange;

  FTexOffset := TgxCoordinates2.CreateInitialized(Self, NullHmgVector, csPoint2d);
  FTexOffset.OnNotifyChange := coordNotifychange;

  FTexScale := TgxCoordinates2.CreateInitialized(Self, XYZHmgVector, csPoint2d);
  FTexScale.OnNotifyChange := coordNotifychange;
  FNeedToUpdateTextureMatrix := True;
end;

destructor TgxTextureSharingShaderMaterial.Destroy;
begin
  FSpecular.Free;
  FAmbient.Free;
  FDiffuse.Free;
  FEmission.Free;
  FTexOffset.Free;
  FTexScale.Free;
  inherited;
end;


function TgxTextureSharingShaderMaterial.GetDisplayName: string;
var
  st: string;
begin
  if Assigned(MaterialLibrary) then
    st := MaterialLibrary.Name
  else
    st := '';
  Result := '[' + st + '.' + Self.LibMaterialName + ']';
end;

function TgxTextureSharingShaderMaterial.GetMaterialLibrary: TgxAbstractMaterialLibrary;
begin
  Result := FMaterialLibrary;
end;

function TgxTextureSharingShaderMaterial.GetTextureMatrix: TMatrix;
begin
  if FNeedToUpdateTextureMatrix then
  begin
    if not (TexOffset.Equals(NullHmgVector) and TexScale.Equals(XYZHmgVector)) then
    begin
      FTextureMatrixIsUnitary := False;
      FTextureMatrix := CreateScaleAndTranslationMatrix(TexScale.AsVector, TexOffset.AsVector)
    end
    else
      FTextureMatrixIsUnitary := True;
    FNeedToUpdateTextureMatrix := False;
  end;
  Result := FTextureMatrix;
end;

function TgxTextureSharingShaderMaterial.GetTextureMatrixIsUnitary: Boolean;
begin
  if FNeedToUpdateTextureMatrix then
    GetTextureMatrix;
  Result := FTextureMatrixIsUnitary;
end;

function TgxTextureSharingShaderMaterial.GetTextureSharingShader: TgxTextureSharingShader;
begin
  if Collection is TgxTextureSharingShaderMaterials then
    Result := TgxTextureSharingShaderMaterials(Collection).GetParent
  else
    Result := nil;
end;

procedure TgxTextureSharingShaderMaterial.OtherNotifychange(Sender: TObject);
begin
  GetTextureSharingShader.NotifyChange(Self);
end;

procedure TgxTextureSharingShaderMaterial.SetAmbient(const Value: TgxColor);
begin
  FAmbient.Assign(Value);
end;

procedure TgxTextureSharingShaderMaterial.SetBlendingMode(const Value: TgxBlendingMode);
begin
  FBlendingMode := Value;
end;

procedure TgxTextureSharingShaderMaterial.SetDiffuse(const Value: TgxColor);
begin
  FDiffuse.Assign(Value);
end;

procedure TgxTextureSharingShaderMaterial.SetEmission(const Value: TgxColor);
begin
  FEmission.Assign(Value);
end;

procedure TgxTextureSharingShaderMaterial.SetLibMaterialName(const Value: TgxLibMaterialName);
begin
  FLibMaterialName := Value;
  if (FLibMaterialName = '') or (FMaterialLibrary = nil) then
    FLibMaterial := nil
  else
    SetLibMaterial(FMaterialLibrary.LibMaterialByName(FLibMaterialName));
end;

procedure TgxTextureSharingShaderMaterial.SetLibMaterial(const Value: TgxLibMaterial);
begin
  FLibMaterial := Value;
  if FLibMaterial <> nil then
  begin
    FLibMaterialName := FLibMaterial.DisplayName;
    FMaterialLibrary := TgxMaterialLibrary(TgxLibMaterials(Value.Collection).Owner);
    if not (csloading in GetTextureSharingShader.ComponentState) then
    begin
      FTexOffset.Assign(FLibMaterial.TextureOffset);
      FTexScale.Assign(FLibMaterial.TextureScale);
      FBlendingMode := FLibMaterial.Material.BlendingMode;
      fEmission.Assign(FLibMaterial.Material.FrontProperties.Emission);
      fAmbient.Assign(FLibMaterial.Material.FrontProperties.Ambient);
      fDiffuse.Assign(FLibMaterial.Material.FrontProperties.Diffuse);
      fSpecular.Assign(FLibMaterial.Material.FrontProperties.Specular);
      fShininess := FLibMaterial.Material.FrontProperties.Shininess;
    end;
  end;
end;


procedure TgxTextureSharingShaderMaterial.SetMaterialLibrary(const Value: TgxMaterialLibrary);
begin
  FMaterialLibrary := Value;
  if (FLibMaterialName = '') or (FMaterialLibrary = nil) then
    FLibMaterial := nil
  else
    SetLibMaterial(FMaterialLibrary.LibMaterialByName(FLibMaterialName));
end;

procedure TgxTextureSharingShaderMaterial.SetShininess(const Value: TgxShininess);
begin
  FShininess := Value;
end;

procedure TgxTextureSharingShaderMaterial.SetSpecular(const Value: TgxColor);
begin
  FSpecular.Assign(Value);
end;

procedure TgxTextureSharingShaderMaterial.SetTexOffset(const Value: TgxCoordinates2);
begin
  FTexOffset.Assign(Value);
  FNeedToUpdateTextureMatrix := True;
end;

procedure TgxTextureSharingShaderMaterial.SetTexScale(const Value: TgxCoordinates2);
begin
  FTexScale.Assign(Value);
  FNeedToUpdateTextureMatrix := True;
end;

procedure TgxTextureSharingShaderMaterial.UnApply(var rci: TgxRenderContextInfo);
begin
  if not Assigned(FLibMaterial) then
    Exit;

  if Assigned(FLibMaterial.Shader) then
  begin
    case FLibMaterial.Shader.ShaderStyle of
      ssLowLevel: FLibMaterial.Shader.UnApply(rci);
      ssReplace:
      begin
        FLibMaterial.Shader.UnApply(rci);
        Exit;
      end;
    end;
  end;

  FLibMaterial.Material.UnApply(rci);

  if not FLibMaterial.Material.Texture.Disabled then
    if not (GetTextureMatrixIsUnitary) then
    begin
      rci.gxStates.ResetTextureMatrix;
    end;

  if Assigned(FLibMaterial.Shader) then
  begin
    case FLibMaterial.Shader.ShaderStyle of
      ssHighLevel: FLibMaterial.Shader.UnApply(rci);
    end;
  end;
end;

{ TgxTextureSharingShader }

function TgxTextureSharingShader.AddLibMaterial(const ALibMaterial: TgxLibMaterial): TgxTextureSharingShaderMaterial;
begin
  Result := FMaterials.Add;
  Result.SetLibMaterial(ALibMaterial);
end;

constructor TgxTextureSharingShader.Create(AOwner: TComponent);
begin
  inherited;
  FMaterials := TgxTextureSharingShaderMaterials.Create(Self);
  ShaderStyle := ssReplace;
end;

destructor TgxTextureSharingShader.Destroy;
begin
  FMaterials.Free;
  inherited;
end;

procedure TgxTextureSharingShader.DoApply(var rci: TgxRenderContextInfo; Sender: TObject);
begin
  if Materials.Count > 0 then
  begin
    rci.gxStates.Enable(stDepthTest);
    rci.gxStates.DepthFunc := cfLEqual;
    Materials[0].Apply(rci);
    FCurrentPass := 1;
  end;
end;

function TgxTextureSharingShader.DoUnApply(var rci: TgxRenderContextInfo): Boolean;
begin
  Result := False;
  if Materials.Count > 0 then
  begin
    Materials[FCurrentPass - 1].UnApply(rci);
    if FCurrentPass < Materials.Count then
    begin
      Materials[FCurrentPass].Apply(rci);
      Inc(FCurrentPass);
      Result := True;
    end
    else
    begin
      rci.gxStates.DepthFunc := cfLess;
      rci.gxStates.Disable(stBlend);
      rci.gxStates.Disable(stAlphaTest);
      FCurrentPass := 0;
    end;
  end;
end;

function TgxTextureSharingShader.FindLibMaterial(const ALibMaterial: TgxLibMaterial): TgxTextureSharingShaderMaterial;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FMaterials.Count - 1 do
    if FMaterials[I].FLibMaterial = ALibMaterial then
    begin
      Result := FMaterials[I];
      Break;
    end;
end;

procedure TgxTextureSharingShader.Notification(AComponent: TComponent; Operation: TOperation);
var
  I: Integer;
begin
  inherited;
  if Operation = opRemove then
  begin
    if AComponent is TgxMaterialLibrary then
    begin
      for I := 0 to Materials.Count - 1 do
      begin
        if Materials.Items[I].MaterialLibrary = AComponent then
          Materials.Items[I].MaterialLibrary := nil;
      end;
    end;
  end;
end;

procedure TgxTextureSharingShader.SetMaterials(const Value: TgxTextureSharingShaderMaterials);
begin
  FMaterials.Assign(Value);
end;

{ TgxTextureSharingShaderMaterials }

function TgxTextureSharingShaderMaterials.Add: TgxTextureSharingShaderMaterial;
begin
  Result := (inherited Add) as TgxTextureSharingShaderMaterial;
end;

constructor TgxTextureSharingShaderMaterials.Create(AOwner: TgxTextureSharingShader);
begin
  inherited Create(AOwner, TgxTextureSharingShaderMaterial);
end;

function TgxTextureSharingShaderMaterials.GetItems(const AIndex: Integer): TgxTextureSharingShaderMaterial;
begin
  Result := (inherited Items[AIndex]) as TgxTextureSharingShaderMaterial;
end;

function TgxTextureSharingShaderMaterials.GetParent: TgxTextureSharingShader;
begin
  Result := TgxTextureSharingShader(GetOwner);
end;

procedure TgxTextureSharingShaderMaterials.SetItems(const AIndex: Integer; const Value: TgxTextureSharingShaderMaterial);
begin
  inherited Items[AIndex] := Value;
end;

//----------------------------------------------------------------------------
initialization
//----------------------------------------------------------------------------

  RegisterClasses([TgxTextureSharingShader, TgxTextureSharingShaderMaterials,
                   TgxTextureSharingShaderMaterial]);

end.
