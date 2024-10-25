# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
pkgs: {
  # example = pkgs.callPackage ./example { };
  cura = pkgs.callPackage ./cura5_4-Appimage.nix {};
  lychee = pkgs.callPackage ./lychee5_4_3-Appimage.nix {}; 
  freecad = pkgs.callPackage ./freecad1.0Rc2-Appimage.nix {};
}
