{ appimageTools, fetchurl }:

let
  pname = "cura";
  version = "5.8.1";
  src = fetchurl {
    url = "https://github.com/Ultimaker/Cura/releases/download/5.8.1/UltiMaker-Cura-5.8.1-linux-X64.AppImage";
    hash = "sha256-VLd+V00LhRZYplZbKkEp4DXsqAhA9WLQhF933QAZRX0=";
  };

  appimageContents = appimageTools.extract {
    inherit pname version src;
  };
in
  appimageTools.wrapType2 {
    inherit pname version src;

    # Install a desktop file and icon    
    extraInstallCommands = ''
      install -m 444 -D ${appimageContents}/com.ultimaker.cura.desktop $out/share/applications/com.ultimaker.cura.desktop
      install -m 444 -D ${appimageContents}/cura-icon.png $out/share/icons/hicolor/256x256/apps/cura-icon.png
      substituteInPlace $out/share/applications/com.ultimaker.cura.desktop \
            --replace-fail 'Exec=UltiMaker-Cura' 'Exec=${pname}'
    '';

}
