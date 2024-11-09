{ pkgs ? import <nixpkgs> {} }:

with pkgs;

appimageTools.wrapType2 { # or wrapType1
  name = "freecad";
  src = fetchurl {
    url = "https://github.com/FreeCAD/FreeCAD/releases/download/1.0rc2/FreeCAD_1.0.0RC2-conda-Linux-x86_64-py311.AppImage";
    hash = "sha256-NHS35APqz8VtpmkKcM9Q2hgg2HHGcfQLx0gR5t7vtUs=";
  };
  extraPkgs = pkgs: with pkgs; [ ];
}
