# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, outputs, lib, config, pkgs, ... }:

let
  hostName = "Lenny";
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
      ../users/afairbrother.nix
      ../suspend2Hibernate.nix
    ];

  networking = {
    hostName = "${hostName}";
  };

  # Bootloader.
  #boot.loader = lib.mkForce { 
  #  grub = {
  #    enable = true;
  #    device = "/dev/sda";
  #    useOSProber = true;
  #  };
  #};

  users.mutableUsers = false;

  # enable the zen kernel
  boot.kernelPackages = pkgs.linuxPackages_zen;

  zramSwap =  {
    enable = true;
    algorithm = "zstd";
  };

  hardware.bluetooth.enable = true;


  programs.kdeconnect.enable = true;

  services.lldpd.enable = true;

  services.udev.extraRules = ''
    # Allow users in the plugdev group to access the USB devices
    #SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", MODE="0664", GROUP="plugdev"
    
    # Added to allow access to ATTiny85 USB devices
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="16d0", ATTRS{idProduct}=="0753", MODE:="0666"
    KERNEL=="ttyACM*", ATTRS{idVendor}=="16d0", ATTRS{idProduct}=="0753", MODE:="0666", ENV{ID_MM_DEVICE_IGNORE}="1"
  '';

}

