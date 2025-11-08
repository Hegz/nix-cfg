# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, outputs, lib, config, pkgs, ... }:

let
  hostName = "cromulent";
  # Sops secret management
  sops-nix = builtins.fetchTarball {
    # url = "https://github.com/Mic92/sops-nix/archive/master.tar.gz";
    # Pinned to 22-02-2024
    url = "https://github.com/Mic92/sops-nix/archive/f6b80ab6cd25e57f297fe466ad689d8a77057c11.tar.gz";
    sha256 = "sha256:158n4gwrjpxkgjivmmnlzsy81sxlirmfxgdxhyck5d1pqrwliwls";
  }; 
in
{
  imports =
    [ # Include the results of the hardware scan.
      (import "${sops-nix}/modules/sops")
      ./hardware-configuration.nix
      ../desktop.nix
      ../dokuwiki.nix
      ../users/afairbrother.nix
      #../containers/adGuard.nix
      #./suspend2Hibernate.nix
      #./unstable.nix
      #./unstable-keybase.nix
      #./dokuwiki.nix
    ];

  networking = {
    hostName = "${hostName}";
  };

  users.mutableUsers = false;

  fileSystems."/home/Important" = {
    device = "mcp:/home/important";
    fsType = "nfs";
    options = [ "x-systemd.automount" "noauto" "x-systemd.idle-timeout=600" ];
  };

  # enable the zen kernel
  boot.kernelPackages = pkgs.linuxPackages_zen;
 
  boot.initrd.kernelModules = [ "amdgpu" ];
  hardware.graphics.enable32Bit = true; # For 32 bit applications

  hardware.graphics.extraPackages = with pkgs; [
      amdvlk
    ];
    # For 32 bit applications 
  hardware.graphics.extraPackages32 = with pkgs; [
      driversi686Linux.amdvlk
    ];

  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "amdgpu" ];  

  hardware.bluetooth.enable = true;

  programs.kdeconnect.enable = true;

  services.opensnitch.enable = true;

  services.lldpd.enable = true;

  services.udev.extraRules = ''
    # Allow users in the plugdev group to access the USB devices
    #SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", MODE="0664", GROUP="plugdev"
    
    # Added to allow access to ATTiny85 USB devices
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="16d0", ATTRS{idProduct}=="0753", MODE:="0666"
    KERNEL=="ttyACM*", ATTRS{idVendor}=="16d0", ATTRS{idProduct}=="0753", MODE:="0666", ENV{ID_MM_DEVICE_IGNORE}="1"
  '';

  # Steam settings.
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = false; # Open ports in the firewall for Source Dedicated Server
  };
}

