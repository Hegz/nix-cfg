# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, secrets, ... }:
let
  hostName    = "HePhaestus";
in
{
  imports =
    [ # Include the results of the hardware scan.
      (import "${sops-nix}/modules/sops")
      ./hardware-configuration.nix
      ../users/afairbrother.nix
      ../desktop.nix
      #../syncthing.nix
      ../../modules/suspend2Hibernate.nix
      #../dokuwiki.nix
    ];

  networking.hostName = "${hostName}"; # Define your hostname.

  boot.kernelPackages = pkgs.linuxPackages_zen; # Use the Zen kernel.

  hardware.bluetooth.enable = true;

  programs.kdeconnect.enable = true;

  services.lldpd.enable = true; # Enable LLDP to discover network devices.
  services.avahi.enable = true; # Enable avahi to discover mdns  devices.

  #services.printing = {
  #  enable = false; # Enable printing services.
  #  clientConf = ''
  #    ServerName 10.173.0.8
  #  '';
  #};
  networking.firewall = {
    enable = true; # Enable the firewall.
  };

  # Steam settings.
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = false; # Open ports in the firewall for Source Dedicated Server
  };
}

