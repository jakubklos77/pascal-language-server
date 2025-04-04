// Pascal Language Server
// Copyright 2020 Ryan Joseph

// This file is part of Pascal Language Server.

// Pascal Language Server is free software: you can redistribute it
// and/or modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation, either version 3 of
// the License, or (at your option) any later version.

// Pascal Language Server is distributed in the hope that it will be
// useful, but WITHOUT ANY WARRANTY; without even the implied warranty
// of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with Pascal Language Server.  If not, see
// <https://www.gnu.org/licenses/>.

unit hover;

{$mode objfpc}{$H+}

interface

uses
  Classes, URIParser, CodeToolManager, CodeCache, IdentCompletionTool, BasicCodeTools,
  lsp, basic,finddeclarationtool, helpers;

type
  
  { THoverResponse }

  THoverResponse = class(TPersistent)
  private
    fContents: TMarkupContent;
    fRange: TRange;
  published
    // The hover's content
    property contents: TMarkupContent read fContents write fContents;

    // An optional range is a range inside a text document
    // that is used to visualize a hover, e.g. by changing the background color.
    property range: TRange read fRange write fRange;
  end;


  TPascalHelpContextType = (
    pihcFilename,
    pihcSourceName,  // unit name, library name, ..
    pihcProperty,
    pihcProcedure,
    pihcParameterList,
    pihcVariable,
    pihcType,
    pihcConst
    );
  TPascalHelpContext = record
    Descriptor: TPascalHelpContextType;
    Context: string;
  end;
  TPascalHelpContextPtr = ^TPascalHelpContext;

  { THoverRequest }
  
  THoverRequest = class(specialize TLSPRequest<TTextDocumentPositionParams, THoverResponse>)
    function Process(var Params: TTextDocumentPositionParams): THoverResponse; override;
  end;

implementation
uses
  SysUtils, diagnostics,codetree,pascalparsertool,customcodetool,fileprocs;

{ THoverRequest }

function ReadFile(path: ansistring): ansistring;
var
  f: File;
  list: TStringList;
begin
  try
    list := TStringList.Create;
    list.LoadFromFile(path);
    result := list.Text;
  except
    on E:Exception do
      writeln(path+': ', E.Message);
  end;
  list.Free;
end;


function THoverRequest.Process(var Params: TTextDocumentPositionParams): THoverResponse;
var
  Code: TCodeBuffer;
  Cursor, Declaration: TCodeXYPosition;
  X, Y, i, CommentStart, TopLine: Integer;
  Hint, CommentText: String;
  Node:TCodeTreeNode;
  ListOfComments: TFPList;
  ExpressionType: TExpressionType;
  NewTool: TFindDeclarationTool;
  NewNode: TCodeTreeNode;
begin with Params do
  begin
    Code := CodeToolBoss.FindFile(UriToFilenameEx(textDocument.uri));
    X := position.character;
    Y := position.line;

    Cursor.Code := Code;
    Cursor.X := X + 1;
    Cursor.Y := Y + 1;

    CommentText := '';
    Result := nil;

    Declaration := Default(TCodeXYPosition);

    try
      DebugLn(code.Filename, ' ', code.Scanner.SourceName, ' ', code.Scanner.IsUnit.ToString(), ' ', IntToStr(Cursor.X), ' ', IntToStr(Cursor.Y));
      if not CodeToolBoss.InitCurCodeTool(Code) then begin
          Exit;
      end;

      // Hint := CodeToolBoss.CurCodeTool.FindSmartHint(Cursor, TFindSmart)

      if // not CodeToolBoss.CurCodeTool.FindDeclaration(Cursor, DefaultFindSmartHintFlags + [fsfSearchSourceName], NewTool, NewNode, Declaration, TopLine) or
         not CodeToolBoss.CurCodeTool.FindDeclaration(Cursor, DefaultFindSmartHintFlags + [fsfSearchSourceName], ExpressionType, Declaration, TopLine)
      then begin
          Exit;
      end;

      NewTool := ExpressionType.Context.Tool;
      NewNode := ExpressionType.Context.Node;

      Hint := NewTool.GetSmartHint(NewNode, Declaration, False);
      if Hint = '' then
        Exit(nil);

      if not ((ExpressionType.Desc = xtContext) and (ExpressionType.Context.Node = nil)) and
         Assigned(Declaration.Code) and
         CodeToolBoss.GetPasDocComments(Declaration.Code, Declaration.X, Declaration.Y, ListOfComments) and
         Assigned(ListOfComments)
      then
          try
            {PCodeXYPosition(ListOfComments[0])^.Code.LineColToPosition(PCodeXYPosition(ListOfComments[0])^.Y, PCodeXYPosition(ListOfComments[0])^.X, CommentStart);
            CommentText := ExtractCommentContent(
                PCodeXYPosition(ListOfComments[0])^.Code.Source,
                CommentStart,
                True,
                False,
                False,
                False
            );}
            CommentText := GatherComments(ListOfComments);
          finally
            FreeListOfPCodeXYPosition(ListOfComments);
            ListOfComments := nil;
          end;

      // Hint := CodeToolBoss.FindSmartHint(Code, X + 1, Y + 1);
      // empty hint string means nothing was found
      //if Hint = '' then
      //  exit(nil);
    except
      on E: Exception do
        begin
          //writeln(StdErr, 'Hover Error: ', E.ClassName, ' ', E.Message);
          //flush(StdErr);
          CommentText := E.Message;
//          exit(nil);
        end;
    end;
    // https://facelessuser.github.io/sublime-markdown-popups/

    // todo: doesn't support pascal syntax!
    // note: other user says it works for him, pascal syntax is in app bundle
    // import mdpopups;mdpopups.show_popup(view, '```pascal\nvar x = 1\n```')

    //Hint := ReadFile('/Users/ryanjoseph/Developer/Projects/FPC/pascal-language-server/README.md');
    //Hint:='```json'+#10+'"initializationOptions": [1,2,3]'+#10+'```';
    //Hint:='```pascal'+#10+'type TDebug = record'+#10+'```';

    Hint := ProcessSignature(Hint);
    Hint := '```pascal' + #10 + Hint + #10 + '```';

    if not (CommentText = '') then begin
        Hint := Hint + LineEnding;
        Hint := Hint + ProcessComment(CommentText);
    end;

    if Assigned(Declaration.Code) then begin
        Hint := Hint + LineEnding + LineEnding;
        Hint := Hint + '**Source**: ' + Declaration.Code.Filename;

        if Declaration.Y >= 1 then begin
            Hint := Hint + ':' + Declaration.Y.ToString;

            if Declaration.X >= 1 then
                Hint := Hint + ',' + Declaration.X.ToString;
        end;
    end;

    Result := THoverResponse.Create;
    Result.contents := TMarkupContent.Create(Hint, false);
    Result.range := TRange.Create(Y, X);
  end;
end;

initialization
  LSPHandlerManager.RegisterHandler('textDocument/hover', THoverRequest);
end.

