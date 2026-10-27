{
  appimageTools,
  fetchurl,
  lib,
}: let
  pname = "drift";
  version = "0.8.0";
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
      install -m 444 -D ${appimageContents}/org.cutwire.Drift.desktop $out/share/applications/org.cutwire.Drift.desktop
      install -m 444 -D ${appimageContents}/org.cutwire.Drift.png $out/share/icons/hicolor/256x256/apps/org.cutwire.Drift.png
    '';
  }
