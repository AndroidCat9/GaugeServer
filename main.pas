unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  IdHTTPServer, IdCustomHTTPServer, IdContext;

const
  ServerSoft : string = 'GaugeServer';
  SAMPLERATE          = 60000; // milliseconds or 60 seconds

  // Remember to adjust these for port used and network path
{$IFDEF LINUX}
  TEMPPath  = '/sys/devices/platform/dht11@10/iio:device0/in_temp_input';
  HUMIDPath = '/sys/devices/platform/dht11@10/iio:device0/in_humidityrelative_input';
{$ELSE IF WINDOWS}
  TEMPPath  = '\\BETABANG\root\sys\devices\platform\dht11@10\INLYCU~I\in_temp_input';
  HUMIDPath = '\\BETABANG\root\sys\devices\platform\dht11@10\INLYCU~I\in_humidityrelative_input';
{$IFEND}

type

  { TGaugeForm }

  TGaugeForm = class(TForm)
    DataServer: TIdHTTPServer;
    TempLabel: TLabel;
    HumidLabel: TLabel;
    UpdateTimer: TTimer;
    procedure DataServerCommandGet(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Init;
    procedure UpdateTimerTimer(Sender: TObject);
  private
    temp      : integer;
    humidity  : integer;
    sRootPath : string;
    sHostName : string;
    slEnviron : TStringList;

    procedure DoReadingUpdate;
    procedure ReadValues;

  public

  end;

var
  GaugeForm: TGaugeForm;

implementation

uses
  {$IFDEF UNIX}
  BaseUnix,
  {$ENDIF}
  IdSocketHandle;

{$R *.lfm}

//=============================================================================
// Signal handler
//-----------------------------------------------------------------------------
{$IFDEF UNIX}    // Need to trap this for Linux and probably MacOS.

// Trap SIGPIPE
procedure Handle_Linux_Signal(sig: LongInt); cdecl;
begin
  case sig of
     SIGPIPE: //Ignore or handle any way you want.
  end;
end;
{$ENDIF}

//=============================================================================
// Toolbox functions
//-----------------------------------------------------------------------------

function ProcessTemplate(slTemplate, slEnviron : TStringList) : string;
var
  n      : integer;
  sMacro : string;
begin
  // Simple variable replacement.
  // Not a Jinja2 clone, but every macro processor tends to grow into
  // into a complete language, so we'll see.

  sMacro := slTemplate.Text;
  for n := 0 to slEnviron.Count-1 do
  begin
      sMacro := StringReplace(sMacro, '{{ '+slEnviron.Names[n]+' }}', slEnviron.ValueFromIndex[n], [rfReplaceAll]);  // Replacce all instances
      sMacro := StringReplace(sMacro, '{{'+slEnviron.Names[n]+'}}', slEnviron.ValueFromIndex[n], [rfReplaceAll]);  // Replacce all instances
  end;
  result := sMacro;
end;

{$IFDEF UNIX}
function GetHostName : string;
var
  fHostName : TextFile;
  s         : string;
begin
  // I thought that there was a system call to return this, but couldn't find
  // it, so I'll do it direct.
  try
    AssignFile(fHostName, '/etc/hostname');
    Reset(fHostName);
    ReadLn(fHostName, s);
    CloseFile(fHostName);
    result := uppercase(s);  // LCARS is a shouty UX
  except
    on E: EInOutError do
      result := '*ERR*';
  end;
end;
{$ENDIF}

//=============================================================================
// TGaugeForm obect code
//-----------------------------------------------------------------------------

procedure TGaugeForm.Init;
begin
  slEnviron := TStringList.Create;

  DoReadingUpdate; // Do an inital read

  {$IFDEF UNIX}    // Need to trap this for Linux and probably MacOS.

  // Trap SIGPIPE
  // Todo: Update depreciated fpSignal
  fpSignal(SIGPIPE, SignalHandler(@Handle_Linux_Signal));

  {$ENDIF}

  // Set up the web server
  sRootPath := ExtractFilePath(Application.ExeName);
  {$IFDEF UNIX}
  // ID for the web page and json data
  sHostName := GetHostName;
  {$ELSE IF}
  // Might as well assign it rather than using the hostname of the Windows box.
  sHostName := 'Betabang';
  {$ENDIF}
  slEnviron.Values['hostname'] := sHostName;

  UpdateTimer.Interval := SAMPLERATE;
  UpdateTimer.Enabled  := true;

end;

procedure TGaugeForm.FormCreate(Sender: TObject);
var
  Binding : TIdSocketHandle;
begin
  // Under Linux, the HTTPServer can't be started until the thread handler has
  // been initialized, or RunError(232) will happen. FormCreate seems to be the
  // safest place for that.

  // Someday add another binding for IPv6.

  DataServer.Bindings.Clear;
  Binding       := DataServer.Bindings.Add;
  Binding.Port  := 8885;
  // Binding.IP    := '127.0.0.1';    // This machine only.
  // Binding.IP    := '192.168.1.9';  // LAN access only.
  Binding.IP    := '0.0.0.0';         // Open all the addresses!

  DataServer.Active    := true;
end;

procedure TGaugeForm.FormDestroy(Sender: TObject);
begin
  // Shutdown HTTP server
  try
    DataServer.Active := false;
  finally
  end;

  // Shutdown any other threads

  // Free memory

end;

procedure TGaugeForm.DoReadingUpdate;
begin
  ReadValues;
  TempLabel.Caption  := inttostr(temp)+'c';
  HumidLabel.Caption := inttostr(humidity)+'%';
end;

procedure TGaugeForm.UpdateTimerTimer(Sender: TObject);
begin
  DoReadingUpdate;
end;

procedure TGaugeForm.ReadValues;
var
  fDeviceTree : TextFile;
  s           : string;

begin
  // Read the DHT11 temp and humidity as dev tree text files.
  // Since the DHT11 only returns integer values, the extra percision can be
  // disgarded. The DHT22 or other sensors might require changes.

  // The DHT11 values are in Celcius. I don't know if that's locale dependant.

  try
    AssignFile(fDeviceTree, TEMPpath);
    Reset(fDeviceTree);
    ReadLn(fDeviceTree, s);
    CloseFile(fDeviceTree);
  except
    on E: EInOutError do
      s := '-1000';
  end;
  temp := strtoint(s) div 1000;

  try
    AssignFile(fDeviceTree, HUMIDPath);
    Reset(fDeviceTree);
    ReadLn(fDeviceTree, s);
    CloseFile(fDeviceTree);
  except
    on E: EInOutError do
      s := '-1000';
  end;
  humidity := strtoint(s) div 1000;

  slEnviron.Values['temp'] := inttostr(temp);
  slEnviron.Values['hum']  := inttostr(humidity);
  slEnviron.Values['time'] := DateTimeToStr(now);

end;

//=============================================================================
// Caution - Threaded code
//
// Don't directly access UI or other non-threadsafe data without
// TCriticalSection locks or other protection.
//-----------------------------------------------------------------------------

procedure TGaugeForm.DataServerCommandGet(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
  s          : string;
  sLocalDoc  : string;
  sJSON      : string;
  ByteSent   : Cardinal;
  bTemplate  : boolean;
  slTemplate : TStringList;

  procedure AuthFailed;
  begin
    AResponseInfo.ContentText := '<!doctype html><html><head><title>Error</title></head><body><h1>Authentication failed</h1></body></html>';
    AResponseInfo.AuthRealm := ServerSoft;
  end;

  procedure AccessDenied;
  begin
    AResponseInfo.ContentText := '<!doctype html><html><head><title>Error</title></head><body><h1>Access denied</h1>'#13 +
      'You do not have sufficient priviligies to access this document.</body></html>';
    AResponseInfo.ResponseNo := 403;
  end;

  procedure NotFound;
  begin
    AResponseInfo.ContentText := '<!doctype html><html><head><title>Error</title></head><body><h1>Not found</h1>'#13 +
      'The requested resource could not be found.</body></html>';
    AResponseInfo.ResponseNo := 404;
  end;

begin
  // This could be tidier with page handler registration like Flask.

  // Setup
  AResponseInfo.Server := ServerSoft;
  AResponseInfo.CustomHeaders.AddValue('X-Clacks-Overhead', 'GNU Terry Pratchett');

  // Default index.html?
  if (ARequestInfo.Document = '/') or (ARequestInfo.Document = '') then
    sLocalDoc := '/templates/index.html'
  else
    sLocalDoc := ARequestInfo.Document;

  // Virtual pages

  if (pos('/json/', sLocalDoc) = 1) then
  begin
    // Request for data in json format
    if (pos('/json/environment', sLocalDoc) = 1) then
    begin
      // Build the JSON by hand.
      sJSON  := Format('{"hostname":"%s","temp":"%s","hum":"%s","time":"%s"}',
        [slEnviron.Values['hostname'],
        slEnviron.Values['temp'],
        slEnviron.Values['hum'],
        slEnviron.Values['time']]);
      AResponseInfo.ContentText := sJSON;
      AResponseInfo.ContentType := 'application/json';
      AResponseInfo.ResponseNo  := 200;
    end
    else
      NotFound;  // 404
  end
  else begin
    // Which requests are templates and which are static?
    bTemplate := (pos('/templates', sLocalDoc) = 1);

    if FileExists(sRootPath + sLocalDoc) then // File exists
    begin
      if bTemplate then
      begin
        // Template processing

        slTemplate := TStringList.Create;
        slTemplate.LoadFromFile(sRootPath + sLocalDoc); // Test with non-western languages?

        // Reading slEnviron from threaded code *should* be okay.
        s := ProcessTemplate(slTemplate, slEnviron);

        AResponseInfo.ResponseNo  := 200;
        AResponseInfo.ContentText := s;
      end
      else begin
        // Normal document request

        AResponseInfo.ResponseNo         := 200;
        AResponseInfo.ContentDisposition := ' '; // kludge to prevent it being tagged as an attachment and autosaved.

        ///// Boomcode in Linux
        try
          ByteSent := AResponseInfo.SmartServeFile(AContext, ARequestInfo, sRootPath + sLocalDoc);
        finally
        end;
      end;
    end
    else
      NotFound;  // 404
  end;
end;


end.

