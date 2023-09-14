{ config, pkgs, ... }:
let
  unstable = import
    (builtins.fetchTarball https://github.com/nixos/nixpkgs/tarball/3807ab24077dd827482cc76c2a0d598e12578119)
    # 3807ab24077dd827482cc76c2a0d598e12578119 -- September 13, 2023. 
    # reuse the current configuration
    { config = config.nixpkgs.config; };
in
{
  environment.systemPackages = with pkgs; [
    unstable.distrobox
  ];
}
