{ pkgs ? import <nixpkgs> {} }:

with pkgs;

appimageTools.wrapType2 { # or wrapType1
  name = "cura";
  src = fetchurl {
    url = "https://github.com/Ultimaker/Cura/releases/download/5.8.1/UltiMaker-Cura-5.8.1-linux-X64.AppImage";
    hash = "";
  };
  extraPkgs = pkgs: with pkgs; [ ];
}
