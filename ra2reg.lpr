program EmperorReg;

{$mode objfpc}{$H+}

uses
  Classes,
  Registry,
  SysUtils,
  Windows,
  getopts;

const
  KEY_WOW64_64KEY = $0100;
  SM_CXSCREEN = 0; // width
  SM_CYSCREEN = 1; // height                  
  MB_OK = $00000000;
  MB_ICONINFORMATION = $00000040;
var
  optShowHelp: bool = False;
  optShowMsgBox: bool = True;
  optWriteWoldataKey: bool = True;
  optSetCompatibility: bool = True;
  optRegRa2: bool = True;
  optHighResSupport: bool = True;
  optHighGraphicSupport: bool = True;

  function GetSystemMetrics(nIndex: int32): int32; stdcall; external 'user32.dll';

  // Call randomize() before calling this method
  function GetRandomSerial: string;
  const
    RA2_SERIAL_SIZE = 22;
  var
    serial: string;
    i: int32;
  begin
    serial := default(string);
    setlength(serial, RA2_SERIAL_SIZE);
    for i := 1 to RA2_SERIAL_SIZE do
      serial[i] := char(random(10) + 48);
    exit(serial);
  end;

  // Call randomize() before calling this method
  procedure WriteWoldataKey(appPath: string);
  const
    KEY_FILENAME = 'Woldata.key';
    RA2_KEY_SIZE = 128;
  var
    textFile: Text;
    i: int32;
  begin
    AssignFile(textFile, appPath + '\' + KEY_FILENAME);
    rewrite(textFile);
    for i := 1 to RA2_KEY_SIZE do
      Write(textFile, random(10));
    Close(textFile);
  end;

  procedure WriteEmperorRegistry(appPath, serial: string);
  var
    regKey32: Tregistry;
  begin
    regKey32 := Tregistry.Create(KEY_ALL_ACCESS or KEY_WOW64_32KEY);
    regKey32.RootKey := HKEY_LOCAL_MACHINE;

    regKey32.OpenKey('SOFTWARE\Westwood\Emperor', True);
    regKey32.WriteString('Serial', serial);
    regKey32.WriteString('Name', 'Emperor');
    regKey32.WriteString('InstallPath', appPath + '\Emperor.EXE');
    regKey32.WriteInteger('SKU', 7936);
    regKey32.WriteInteger('Version', 65545);
    // note: Yuri's Revenge also has this key, thus it's probably only for Westwood Online which is obsolete now
    // regKey32.WriteString('HTMLPath', appPath + '\Data\HTML');
    regKey32.CloseKey;

    regKey32.Free;
  end;

  procedure SetEmperorCompatibility(appPath: string);
  var
    regKey64: Tregistry;
  begin
    regKey64 := Tregistry.Create(KEY_ALL_ACCESS or KEY_WOW64_64KEY);
    regKey64.RootKey := HKEY_LOCAL_MACHINE;
    regKey64.OpenKey(
      'SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers',
      True);
    regKey64.WriteString(AppPath + '\GAME.EXE', '~ RUNASADMIN HIGHDPIAWARE');
    regKey64.WriteString(AppPath + '\Emperor.EXE', '~ RUNASADMIN HIGHDPIAWARE');

    regKey64.Free;

  end;

  procedure Initialize();

  var
    opt: char;
  begin
    randomize();

    while True do
    begin
      opt := GetOpt('hfcbrsgw');
      case opt of
        'h': optShowHelp := True;
        'f': optWriteWoldataKey := False;
        'c': optSetCompatibility := False;
        'r': optRegRa2 := False;
        's': optHighResSupport := False;
        'g': optHighGraphicSupport := False;
        'w': optShowMsgBox := False;
        '?': optShowHelp := True;
        #0: Break;
        else
          Break;
      end;
    end;

    // post process
    if not optRegRa2 then
    begin
      if optHighResSupport then
      begin
        Writeln('Warning: high resolution support is disabled because of option -r.');
        optHighResSupport := False;
      end;
      if optHighGraphicSupport then
      begin
        Writeln('Warning: high graphics quality setting is disabled because of option -r.');
        optHighGraphicSupport := False;
      end;
    end;
  end;

  procedure ShowHelp();
  const
    helpText =
      'Usage:' + LineEnding + '-h: show this help.' + LineEnding +
      '-f: don''t write Woldata.key file' + LineEnding +
      '-c: don''t set compatibility for gaming executables' +
      LineEnding + '-r: don''t register the game in registry' +
      LineEnding +
      '-s: disable high resolution support and assume the screen is in SVGA (800x600) mode.'
      +
      LineEnding + '-g: disable high graphics quality setting.' +
      LineEnding + '-w: don''t show messages in Win32 MessageBox.' +
      LineEnding + LineEnding +
      'For regular installation, you don''t need to specify these options. Leave all options as default.';
  begin
    Writeln(helpText);

  end;

  procedure WriteEmperorResolution(screenWidth, screenHeight: int32);
  var
    regKey32: Tregistry;
  begin
    // note: the resolution must be 4:3
    // also, this method should be called after WriteEmperorRegistry()
    regKey32 := Tregistry.Create(KEY_ALL_ACCESS or KEY_WOW64_32KEY);
    regKey32.RootKey := HKEY_LOCAL_MACHINE;

    regKey32.OpenKey('SOFTWARE\Westwood\Emperor\Options\Graphics', True);
    regKey32.WriteString('ScreenWidth', IntToStr(screenWidth));
    regKey32.WriteString('ScreenHeight', IntToStr(screenHeight));
    regKey32.CloseKey;
  end;

  procedure WriteEmperorHighGraphicOptions();
  var
    regKey32: Tregistry;
  begin
    // note: this method should be called after WriteEmperorRegistry()
    regKey32 := Tregistry.Create(KEY_ALL_ACCESS or KEY_WOW64_32KEY);
    regKey32.RootKey := HKEY_LOCAL_MACHINE;

    regKey32.OpenKey('SOFTWARE\Westwood\Emperor\Options\Graphics', True);
    regKey32.WriteString('ColorDepth', '32');
    regKey32.WriteString('EffectLOD', '2');
    regKey32.WriteString('GraphicsLOD', '4');
    regKey32.WriteString('LimitFrameRate', '0');
    regKey32.WriteString('LimitTo16BitTex', '0');
    regKey32.WriteString('ModelLOD', '2');
    regKey32.WriteString('ShadowQuality', '2');
    regKey32.WriteString('Shadows', '1');
    regKey32.WriteString('TerrainLOD', '2');
    regKey32.WriteString('TextureLOD', '0');
    // note: HardwareTL and MultiTexture are hardware dependent
    regKey32.DeleteKey('HardwareTL');
    regKey32.DeleteKey('MultiTexture');
    // I don't know what "AltDevice" is. Presumably it's hardware dependent
    // In game's README.TXT file, it says: If you are running two video cards, the game may choose the video card you do not wish to use.  You can force it to use your alternate card by adding "-ALTVID" (without the quotes) to the Target line in the game's shortcut.
    regKey32.DeleteKey('AltDevice');
    regKey32.CloseKey;
  end;

var
  appPath: string;
  serial: string;
  screenWidth, screenHeight, currentScreenWidth, currentScreenHeight: int32;

{$R *.res}

begin
  Writeln('Register for Emperor: Battle for Dune');
  Writeln('Author: SadPencil');
  Writeln();
  appPath := ExtractFileDir(ParamStr(0));
  Initialize();
  if optShowHelp then
  begin
    ShowHelp();
    exit();
  end;

  if optRegRa2 then
  begin
    Writeln('Generating serial number...');
    serial := GetRandomSerial();

    Writeln('Writing registry...');
    WriteEmperorRegistry(appPath, serial);
  end;

  if optWriteWoldataKey then
  begin
    Writeln('Generating Woldata.key file...');
    WriteWoldataKey(appPath);
  end;

  if optSetCompatibility then
  begin
    Writeln('Setting application compatibility...');
    SetEmperorCompatibility(appPath);
  end;

  if optHighResSupport then
  begin
    Writeln('Enabling high resolution support...');

    currentScreenWidth := GetSystemMetrics(SM_CXSCREEN);
    currentScreenHeight := GetSystemMetrics(SM_CYSCREEN);

    // try these solutions: 1024x768, 800x600
    if (currentScreenWidth >= 1024) and (currentScreenHeight >= 768) then
    begin
      screenWidth := 1024;
      screenHeight := 768;
    end
    else
    begin
      screenWidth := 800;
      screenHeight := 600;
    end;
  end
  else
  begin
    screenWidth := 800;
    screenHeight := 600;
  end;

  if optRegRa2 then
  begin
    // note: optHighResSupport derives optRegRa2
    // no matter whether optHighResSupport is true or false, we should write the resolution
    Writeln('Resolution: ', screenWidth, 'x', screenHeight);
    WriteEmperorResolution(screenWidth, screenHeight);
  end;

  if optHighGraphicSupport then
  begin
    // note: optHighGraphicSupport derives optRegRa2
    Writeln('Setting high graphics quality...');
    WriteEmperorHighGraphicOptions();
  end;

  if optShowMsgBox then
    MessageBox(0, 'Setup complete.',
      'Register for Emperor: Battle for Dune (by: SadPencil)',
      MB_OK or MB_ICONINFORMATION);

end.
