{ pkgs ? import <nixpkgs> {} }:

with pkgs;

appimageTools.wrapType2 { # or wrapType1
  name = "cura";
  src = fetchurl {
    url = "https://github.com/Ultimaker/Cura/releases/download/5.4.0/UltiMaker-Cura-5.4.0-linux-modern.AppImage";
    hash = "sha256-QVv7Wkfo082PH6n6rpsB79st2xK2+Np9ivBg/PYZd74=";
  };
  extraPkgs = pkgs: with pkgs; [ ];
}
