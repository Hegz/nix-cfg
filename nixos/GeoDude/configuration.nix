# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, outputs, lib, config, pkgs, secrets, ... }:

let
  hostName = "Geodude";
in
{
  imports =
    [ # Include the results of the hardware scan.
      (import "${sops-nix}/modules/sops")
      "${inputs.nixpkgs-unstable}/nixos/modules/services/security/timekpr.nix" # Timekpr from unstable channel
      ./hardware-configuration.nix
      ../desktop.nix
      ../users/adam.nix
      ../users/gio.nix
    ];

  networking = {
    hostName = "${hostName}";
  };

  services.timekpr = {
    package = pkgs.unstable.timekpr;
    enable = true;
  };

  hardware.bluetooth.enable = true;

  services.lldpd.enable = true;

  # Steam settings.
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = false; # Open ports in the firewall for Source Dedicated Server
  };
}

