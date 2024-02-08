{ pkgs ? import <nixpkgs> {} }:

with pkgs;

appimageTools.wrapType2 { # or wrapType1
  name = "cura";
  src = fetchurl {
    url = "https://github.com/Ultimaker/Cura/releases/download/5.6.0/UltiMaker-Cura-5.6.0-linux-X64.AppImage";
    hash = "sha256-EHiWoNpLKHPzv6rZrtNgEr7y//iVcRYeV/TaCn8QpEA=";
  };
  extraPkgs = pkgs: with pkgs; [ ];
}
