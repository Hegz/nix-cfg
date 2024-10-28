{ pkgs ? import <nixpkgs> {} }:

with pkgs;

appimageTools.wrapType2 { # or wrapType1
  name = "s3drive";
  src = fetchurl {
    url = "https://github.com/s3drive/appimage-app/releases/latest/download/S3Drive-x86_64.AppImage";
    hash = "";
  };
  extraPkgs = pkgs: with pkgs; [ ];
}
