unit stringhelper;
 
{$mode objfpc}{$H+}
{$modeswitch typehelpers}

interface
 
uses
  SysUtils;
 
type
 
  TStringArray = array of String;

  { TStringHelper }

  TStringHelper = type helper for String
    public
      function length : integer; overload;
      function substring(index : Integer): String; overload;
      function substring(index : Integer; len : Integer): String; overload;
      function charAt(index : integer) : Char;
      function split(const Separators: array of Char): TStringArray; overload;

      function Trim: String;
      function Replace(Awhat: String; Awith: String; Flags: TReplaceFlags = [rfReplaceAll]): String;
      function StartsWith(Awhat: String): boolean;
      function TrimLeft(const CSet:TSysCharSet): String; overload;
      function TrimLeft: String; overload;
      function TrimRight(const CSet:TSysCharSet): String; overload;
      function TrimRight: String; overload;
      function Join(list: TStringArray): String;
      function IsEmpty: boolean;
  end;
 
 
implementation

uses
  StrUtils;

{ TStringHelper }
 
function TStringHelper.length : integer; inline;
begin
  result := system.length(self);
end;
 
function TStringHelper.substring(index : Integer): String;
var
  strlen, len : integer;
begin
  strlen := self.length;
  if (index < 0) or (index >= strlen) then
    result := ''
  else
  begin
    len := strlen - index;
    setlength(result, len);
    move(self[1 + index], result[1], len * sizeof(Char));
  end;
end;
 
function TStringHelper.substring(index : Integer; len : Integer): String;
var
  strlen : integer;
begin
  strlen := self.length;
  if (index < 0) or (index >= strlen) or (len <= 0) then
    result := ''
  else
  begin
    if index + len > strlen then
      len := strlen - index;
    setlength(result, len);
    move(self[1 + index], result[1], len * sizeof(Char));
  end;
end;

function TStringHelper.charAt(index: integer): Char;
begin
  if (index < 0) or (index >= self.length) then
    result := Char(0)
  else
    result := self[index + 1];
end;

function TStringHelper.split(const Separators: array of Char): TStringArray;
var
  i, j, lastpos : integer;
  ch : char;
 
  x : String;
begin
  x := self;
  result := nil;
  lastpos := 0;
  for i := 0 to self.length - 1 do
  begin
    ch := self.charAt(i);
    for j := 0 to system.length(Separators) - 1 do
    begin
      if ch = Separators[j] then
      begin
        setlength(result, system.length(result) + 1);
        result[system.length(result) - 1] := self.substring(lastpos, i - lastpos);
        lastpos := i + 1;
        break;
      end;
    end;
  end;
  setlength(result, system.length(result) + 1);
  result[system.length(result) - 1] := self.substring(lastpos);
end;

function TStringHelper.Trim: String;
begin
  result := SysUtils.trim(self);
end;

function TStringHelper.Replace(Awhat: String; Awith: String; Flags: TReplaceFlags): String;
begin
  Result := SysUtils.StringReplace(self, Awhat, Awith, Flags);
end;

function TStringHelper.StartsWith(Awhat: String): boolean;
begin
  Result := Pos(awhat, self) = 1;
end;

function TStringHelper.TrimLeft(const CSet: TSysCharSet): String;
begin
  Result := StrUtils.TrimLeftSet(self, CSet);
end;

function TStringHelper.TrimLeft: String;
begin
  Result := SysUtils.TrimLeft(self);
end;

function TStringHelper.TrimRight(const CSet: TSysCharSet): String;
begin
  Result := StrUtils.TrimRightSet(self, CSet);
end;

function TStringHelper.TrimRight: String;
begin
  Result := SysUtils.TrimRight(self);
end;

function TStringHelper.Join(list: TStringArray): String;
var
  i: longint;
  top: longint;
begin
  Result := '';
  for i := 0 to high(list) do
    Result := Result + list[i] + self;
end;

function TStringHelper.IsEmpty: boolean;
begin
  Result := self = '';
end;


end.
 
