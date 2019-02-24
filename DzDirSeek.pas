{------------------------------------------------------------------------------
TDzDirSeek component
Developed by Rodrigo Depin� Dalpiaz (dig�o dalpiaz)
Non visual component to search files in directories

https://github.com/digao-dalpiaz/DzDirSeek

Please, read the documentation at GitHub link.
------------------------------------------------------------------------------}

unit DzDirSeek;

interface

uses System.Classes;

type
  TDSResultKind = (rkComplete, rkRelative, rkOnlyName);
  TDSMaskKind = (mkExceptions, mkInclusions);

  TDzDirSeek = class(TComponent)
  private
    FDir: String;
    FSubDir: Boolean;
    FSorted: Boolean;
    FResultKind: TDSResultKind;
    FMaskKind: TDSMaskKind;
    FUseMask: Boolean;
    FMasks: TStrings;

    FList: TStringList;

    BaseDir: String;
    procedure IntSeek(const RelativeDir: String);
    function CheckMask(const aFile: String; IsDir: Boolean): Boolean;
    function GetName(const RelativeDir, Nome: String): String;
    procedure DoSort;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Seek;

    property List: TStringList read FList;
  published
    property Dir: String read FDir write FDir;
    property SubDir: Boolean read FSubDir write FSubDir default True;
    property Sorted: Boolean read FSorted write FSorted default False;
    property ResultKind: TDSResultKind read FResultKind write FResultKind default rkComplete;
    property MaskKind: TDSMaskKind read FMaskKind write FMaskKind default mkExceptions;
    property UseMask: Boolean read FUseMask write FUseMask default True;
    property Masks: TStrings read FMasks write FMasks;
  end;

function BytesToMB(X: Int64): String;
function GetFileSize(const aFileName: String): Int64;

procedure Register;

implementation

uses System.SysUtils, System.Masks, System.StrUtils;

procedure Register;
begin
  RegisterComponents('Digao', [TDzDirSeek]);
end;

//

constructor TDzDirSeek.Create(AOwner: TComponent);
begin
  inherited;

  FSubDir := True;
  FResultKind := rkComplete;
  FMaskKind := mkExceptions;
  FUseMask := True;
  FMasks := TStringList.Create;
  FList := TStringList.Create;
end;

destructor TDzDirSeek.Destroy;
begin
  FMasks.Free;
  FList.Free;

  inherited;
end;

procedure TDzDirSeek.Seek;
begin
  if not DirectoryExists(FDir) then
    raise Exception.CreateFmt('Path "%s" not found', [FDir]);

  BaseDir := IncludeTrailingPathDelimiter(FDir);

  FList.Clear;
  IntSeek('');

  if FSorted then DoSort;
end;

procedure TDzDirSeek.IntSeek(const RelativeDir: String);
var Sr: TSearchRec;

  function IntCheckMask(IsDir: Boolean): Boolean;
  begin
    Result := CheckMask(RelativeDir + Sr.Name, IsDir);
  end;

begin
  if FindFirst(BaseDir + RelativeDir + '*', faAnyFile, Sr) = 0 then
  begin
    repeat
      if (Sr.Name = '.') or (Sr.Name = '..') then Continue;

      if (Sr.Attr and faDirectory) <> 0 then
      begin //directory
        if FSubDir then //include sub-directories
        begin
          if IntCheckMask(True{Dir}) then
            IntSeek(RelativeDir + Sr.Name + '\');
        end;
      end else
      begin //file
        if IntCheckMask(False) then
          FList.Add(GetName(RelativeDir, Sr.Name));
      end;

    until FindNext(Sr) <> 0;
    FindClose(Sr);
  end;
end;

function TDzDirSeek.CheckMask(const aFile: String; IsDir: Boolean): Boolean;

type
  TProps = (pOnlyFile);
  TPropsSet = set of TProps;

  function GetProps(var Mask: String): TPropsSet;
  var Props: TPropsSet;

    procedure CheckProp(const aProp: String; pProp: TProps);
    var aIntProp: String;
    begin
      aIntProp := '<'+aProp+'>';
    
      if Mask.Contains(aIntProp) then
      begin
        Include(Props, pProp);
        Mask := StringReplace(Mask, aIntProp, '', []); //you should type parameter just once!
      end;
    end;

  begin
    Props := [];

    CheckProp('F', pOnlyFile); //only file parameter
      
    Result := Props;
  end;

var
  aPreMask, aMask: String;
  P: TPropsSet;
  Normal: Boolean; //not OnlyFile
begin
  Result := False;
  if not FUseMask then Exit(True);
  if IsDir and (FMaskKind=mkInclusions) then Exit(True);

  for aPreMask in FMasks do
  begin
    aMask := aPreMask;
    P := GetProps(aMask);

    Normal := not (pOnlyFile in P); //not OnlyFile

    if ( Normal and MatchesMask(aFile, aMask) )
    or ( (Normal or not IsDir) and MatchesMask(ExtractFileName(aFile), aMask) ) then
    begin
      Result := True;
      Break;
    end;
  end;

  if FMaskKind = mkExceptions then Result := not Result;
end;

function TDzDirSeek.GetName(const RelativeDir, Nome: String): String;
begin
  case FResultKind of
    rkComplete: Result := BaseDir + RelativeDir + Nome;
    rkRelative: Result := RelativeDir + Nome;
    rkOnlyName: Result := Nome;
  end;
end;

// ============================================================================

function SortItem(List: TStringList; Index1, Index2: Integer): Integer;
var A1, A2: String;
    Dir1, Dir2: String;
    Name1, Name2: String;
begin
  A1 := List[Index1];
  A2 := List[Index2];

  Dir1 := ExtractFilePath(A1);
  Dir2 := ExtractFilePath(A2);

  Name1 := ExtractFileName(A1);
  Name2 := ExtractFileName(A2);

  if Dir1 = Dir2 then
    Result := AnsiCompareText(Name1, Name2)
  else
    Result := AnsiCompareText(Dir1, Dir2);
end;

procedure TDzDirSeek.DoSort;
begin
  FList.CustomSort(SortItem);
end;

// ============================================================================

function BytesToMB(X: Int64): String;
begin
  Result := FormatFloat('0.00 MB', X / 1024 / 1024);
end;

function GetFileSize(const aFileName: String): Int64;
var Sr: TSearchRec;
begin
  if FindFirst(aFileName, faAnyFile, Sr) = 0 then
  begin
    Result := Sr.Size;

    FindClose(Sr);
  end
    else raise Exception.CreateFmt('Could not get file size of "%s"', [aFileName]);
end;

end.
