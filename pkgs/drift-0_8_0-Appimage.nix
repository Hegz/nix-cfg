{
  appimageTools,
  fetchurl,
  lib,
}: let
  pname = "drift";
  version = "0.8.0";
  desktop = "org.cutwire.Drift.desktop";
  icon = "org.cutwire.Drift.png";
  exec = "Exec=drift";
  src = fetchurl {
    url = "https://github.com/CutWire-Studios/Drift/releases/download/v0.8.0/Drift-0.8.0-x86_64.AppImage";
    hash = lib.fakeHash;
  };

  appimageContents = appimageTools.extract {
    inherit pname version src;
  };
in
  appimageTools.wrapType2 {
    inherit pname version src;

    # Install a desktop file and icon
    extraInstallCommands = ''
      install -m 444 -D ${appimageContents}/${desktop} $out/share/applications/${desktop}
      install -m 444 -D ${appimageContents}/${icon} $out/share/icons/hicolor/256x256/apps/${icon}
      substituteInPlace $out/share/applications/${desktop} \
      --replace-fail '${exec}' 'Exec=${pname}'
    '';
  }
