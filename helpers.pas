unit helpers;

{$mode ObjFPC}{$H+}
{$Codepage utf8}

interface

uses
    SysUtils,
    Classes,
    CodeCache,
    stringhelper,
    BasicCodeTools;

function ProcessComment(AText: String): String;
function ProcessSignature(const AText: String): String;

function GatherComments(const AComments: TFPList): String;

implementation

function ProcessComment(AText: String): String;
var Parts: TStringArray;
    i, k, Beginning: Integer;
    S: String;
    WasAsterisk: Boolean;
begin
    AText := AText.Replace(#13#10, #10).Replace(#13, #10);

    Parts := AText.Split([ #10 ]);

    for i := 0 to Length(Parts) - 1 do begin
        S := Parts[i];
        S := S.Trim();

        if not S.IsEmpty and (S[1] = '*') and ((Length(S) < 2) or (S[2] = ' ') or (S[2] = '*')) then
            S := S.TrimLeft([ '*' ]).TrimLeft;

        if S.StartsWith('@param ') then begin
            S := Copy(S, 8).TrimLeft;

            k := 1;
            while (k <= S.Length) and (S[k] > ' ') do
                Inc(k);

            if k <= S.Length then begin
                S := string('* **Parameter** `') + Copy(S, 1, k - 1) + string('` — ') + Copy(S, k + 1).TrimLeft;
            end;
        end
        else if S.StartsWith('@return ') then begin
            S := Copy(S, 9).TrimLeft;

            S := '* **Returns**: ' + S;
        end;

        Parts[i] := S;
    end;

    Result := String('  ' + LineEnding).Join(Parts).Trim;
end;

function ProcessSignature(const AText: String): String;
{ Aux }
    function ReplaceRepeatedly(const AIn, AWhat, AWith: String): String;
    var Count: Integer;
    begin
        Result := AIn;

        repeat
            Result := SysUtils.StringReplace(Result, AWhat, AWith, [ rfReplaceAll ], Count);
        until Count = 0;
    end;
{ Main routine }
begin
    Result := ' ' + AText;

    Result := Result.Replace(' public ', ' public ', [ rfIgnoreCase ]);
    Result := Result.Replace(' protected ', ' protected ', [ rfIgnoreCase ]);
    Result := Result.Replace(' private ', ' private ', [ rfIgnoreCase ]);
    Result := Result.Replace(' class ', ' class ', [ rfIgnoreCase ]);
    Result := Result.Replace(' function ', ' function ', [ rfIgnoreCase ]);
    Result := Result.Replace(' procedure ', ' procedure ', [ rfIgnoreCase ]);
    Result := Result.Replace(' constructor ', ' constructor ', [ rfIgnoreCase ]);
    Result := Result.Replace(' destructor ', ' destructor ', [ rfIgnoreCase ]);
    Result := Result.Replace(' type ', ' type ', [ rfIgnoreCase ]);
    Result := Result.Replace(' helper ', ' helper ', [ rfIgnoreCase ]);

    Result := Result.TrimLeft;
    Result := Result.TrimRight([ ' ', '=', #9, #13, #10, '(', '[', ':' ]);

    Result := ReplaceRepeatedly(Result, '  ', ' ');
    Result := ReplaceRepeatedly(Result, ' (', '(');
    Result := ReplaceRepeatedly(Result, '( ', '(');
    Result := ReplaceRepeatedly(Result, ' )', ')');
    Result := ReplaceRepeatedly(Result, ') ', ')');
    Result := ReplaceRepeatedly(Result, ' ,', ',');
    Result := ReplaceRepeatedly(Result, ', ', ',');
    Result := ReplaceRepeatedly(Result, '= ', '=');
    Result := ReplaceRepeatedly(Result, ' =', '=');
    Result := ReplaceRepeatedly(Result, ': ', ':');
    Result := ReplaceRepeatedly(Result, ' :', ':');
    Result := ReplaceRepeatedly(Result, '; ', ';');
    Result := ReplaceRepeatedly(Result, ' ;', ';');
    Result := ReplaceRepeatedly(Result, '. ', '.');
    Result := ReplaceRepeatedly(Result, ' .', '.');

    Result := Result.Replace(':', ': ').Replace(';', '; ').Replace(',', ', ').Replace('=', ' = ');
end;

function GatherComments(const AComments: TFPList): String;
var i, CommentStart: Integer;
begin
    Result := '';

    if not Assigned(AComments) then
        Exit;

    for i := 0 to AComments.Count - 1 do begin
        PCodeXYPosition(AComments[i])^.Code.LineColToPosition(PCodeXYPosition(AComments[i])^.Y, PCodeXYPosition(AComments[i])^.X, CommentStart);
        Result := Result + ExtractCommentContent(
            PCodeXYPosition(AComments[i])^.Code.Source,
            CommentStart,
            True,
            False,
            False,
            False
        ) + LineEnding;
    end;

    Result := Result.TrimRight;
end;

end.

