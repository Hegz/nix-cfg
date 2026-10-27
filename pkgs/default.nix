# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
pkgs: {
  # example = pkgs.callPackage ./example { };
  cura = pkgs.callPackage ./cura5_8-Appimage.nix {};
  drift = pkgs.callPacakage ./drift-0_8_0-Appimage.nix {};
  # freecad = pkgs.callPackage ./freecad1.0Rc2-Appimage.nix {};
}
