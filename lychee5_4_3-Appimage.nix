{ pkgs ? import <nixpkgs> {} }:

with pkgs;

appimageTools.wrapType2 { # or wrapType1
  name = "lychee";
  src = fetchurl {
    url = "https://mango-lychee.nyc3.cdn.digitaloceanspaces.com/LycheeSlicer-5.4.3.AppImage";
    hash = "sha256-qi5YXWYIZf3Nf6zXEudzhgWdhchQfD66yAEb5P5WXEQ=";
  };
  extraPkgs = pkgs: with pkgs; [ ];
}
