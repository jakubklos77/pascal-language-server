// Pascal Language Server
// Copyright 2020 Arjan Adriaanse

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

program pasls;

{$mode objfpc}{$H+}

uses
  { RTL }
  SysUtils, fpjson, jsonparser, jsonscanner, classes,

  { LSP }
  lsp, general, 

  { Protocols }
  basic, synchronization, completion, gotoDeclaration, gotoDefinition, 
  gotoImplementation, hover, signatureHelp, references, codeAction, rename,
  documentHighlight, documentSymbol, workspace, window, diagnostics, settings,

  {Other}
   LazLoggerBase;

const
  ContentType = 'application/vscode-jsonrpc; charset=utf-8';

type
  TTestNotification = class(specialize TLSPNotification<TShowMessageParams>)
    procedure Process(var Params : TShowMessageParams); override;
  end;

  { TMyLogger }

  TMyLogger=class(TLazLogger)
    procedure DoDebugLn(s: string; AGroup: PLazLoggerLogGroup = nil); override;
  end;

{ TMyLogger }

procedure TMyLogger.DoDebugLn(s: string; AGroup: PLazLoggerLogGroup);
begin
  WriteLn(StdErr,s);
  Flush(StdErr);
end;

procedure TTestNotification.Process(var Params : TShowMessageParams);
begin
  writeln('got params: ', Params.ClassName)
end;


procedure TestNotifications;
var
  params: TShowMessageParams;
  //notification: TTestNotification;
  data: TJSONData;
  Dispatcher: TLSPDispatcher;
begin
  params := TShowMessageParams.Create;
  params.&type := TMessageType.Error;
  params.message := 'Some Error Message';

  Dispatcher := TLSPDispatcher.Create(nil);

  //notification := TTestNotification.Create(nil);
  //function TLSPDispatcher.ExecuteMethod(const AClassName, AMethodName: TJSONStringType;
  //  Params, ID: TJSONData; AContext: TJSONRPCCallContext): TJSONData;

  data := specialize TLSPStreaming<TShowMessageParams>.ToJSON(params);
  writeln(data.AsJSON);
  data := Dispatcher.Execute(data);
  if data <> nil then
    writeln(data.AsJSON);
end;

function GetFileRequest(AName: string): TJSONData;
var
  stream: TFileStream;
  str: ansistring;
begin
  stream := TFileStream.Create(ExtractFilePath(ParamStr(0)) + '../../data/' + AName, fmOpenRead);
  try
    SetLength(str, stream.size);
    stream.Read(str[1], stream.size);
    Result := TJSONParser.Create(str, DefaultOptions).Parse;
  finally
    stream.Free;
  end;
end;

procedure RunFileRequest(Dispatcher: TLSPDispatcher; AName: ansistring);
var
  Request: TJSONData;
  Response: TJSONData;
begin
  Request := GetFileRequest(AName);
  writeln(Request.AsJSON);
  Response := Dispatcher.Execute(Request);
  if Response <> nil then
    writeln(Response.AsJSON);

  Request.Free;
  Response.Free;
end;

procedure PerformTestRun;
var
  Dispatcher: TLSPDispatcher;
begin
  Dispatcher := TLSPDispatcher.Create(nil);

  RunFileRequest(Dispatcher, 'init.json');
  RunFileRequest(Dispatcher, 'rename.json');

  Halt(0);
end;

procedure RunConsole;
var
  Dispatcher: TLSPDispatcher;
  Header, Name, Value, Content: string;
  I, Length: Integer;
  Request, Response: TJSONData;
  VerboseDebugging: boolean = true;
begin
  //TestNotifications;
  //halt;
  Length:=0;
  Dispatcher := TLSPDispatcher.Create(nil);
  TJSONData.CompressedJSON := True;
  SetTextLineEnding(Input, #13#10);
  SetTextLineEnding(Output, #13#10);
  SetTextCodePage(Input,CP_UTF8);
  SetTextCodePage(Output,CP_UTF8);

  if FindCmdLineSwitch('-test-run') then
    PerformTestRun;
  
  while not EOF do
  begin
    ReadLn(Header);
    while Header <> '' do
    begin
      I := Pos(':', Header);
      Name := Copy(Header, 1, I - 1);
      Delete(Header, 1, i);
      Value := Trim(Header);
      if Name = 'Content-Length' then Length := StrToInt(Value);
      ReadLn(Header);
    end;

    Content := '';
    SetLength(Content, Length);
    I := 1;
    while I <= Length do
    begin
      Read(Content[I]);
      Inc(I);
    end;
    
    Request := TJSONParser.Create(Content, DefaultOptions).Parse;

    if TJSONObject(request).Find('params')=nil then
    begin
        TJSONObject(request).Add('params',TJSONObject.Create);
    end;

    // log request payload
    if VerboseDebugging then
      begin
        writeln(StdErr, Request.FormatJSON);
        Flush(StdErr);
      end;
      
    Response := Dispatcher.Execute(Request);
    if Assigned(Response) then
    begin
      if not IsResponseValid(Response) then
        begin
          Writeln(StdErr, 'invalid response -> ', response.AsJSON);
          Flush(StdErr);
          continue;
        end;
      Content := Response.AsJSON;
      WriteLn('Content-Type: ', ContentType);
      WriteLn('Content-Length: ', Content.Length);
      WriteLn;
      Write(Content);
      Flush(Output);
      
      // log response payload
      if VerboseDebugging then
        begin
          writeln(StdErr, Content);
          Flush(StdErr);
        end;

      Response.Free;
    end;

    Request.Free;
  end;
end;
var log:TMyLogger;
begin
  log:=TMyLogger.Create;
  SetDebugLogger(log);
  
  RunConsole;
  log.Free;
end.
