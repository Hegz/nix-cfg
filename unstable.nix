{ config, pkgs, ... }:
let
  unstable = import
  (builtins.fetchTarball {
      url = "https://github.com/NixOS/nixpkgs/tarball/fb684d889d1b6e5a7bc0613b322c36acfdb7dd25";
      # Updated pin to 6-02-24
      sha256 = "sha256:04ap3vs89hl0czfa322kick5hjppg0qrjhsmj6vl0q3l3ra5pddq";
    })
    { config = config.nixpkgs.config; };
in
{
  environment.systemPackages = with pkgs; [
    unstable.distrobox
  ];
}
