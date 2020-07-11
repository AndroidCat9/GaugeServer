program GaugeServer;

{$mode objfpc}{$H+}

uses
  // If UNIX-ish, always use cthreads.
  {$IFDEF LINUX}(*{$IFDEF UseCThreads}*)
  cthreads,
  (*{$ENDIF}*){$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, main, indylaz
  { you can add units after this };

{$R *.res}

begin
  Application.Title:='GaugeServer';
  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  Application.Initialize;
  Application.CreateForm(TGaugeForm, GaugeForm);
  GaugeForm.Init;
  Application.Run;
end.

