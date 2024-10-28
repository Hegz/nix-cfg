# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
pkgs: {
  # example = pkgs.callPackage ./example { };
  cura = pkgs.callPackage ./cura5_4-Appimage.nix {};
  s3drive = pkgs.callPackage ./s3drive.nix {};
  freecad = pkgs.callPackage ./freecad1.0Rc2-Appimage.nix {};
}
