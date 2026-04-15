# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, outputs, lib, config, pkgs, secrets, ... }:

let
  hostName = "GeoGamer";
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../desktop.nix
      ../users/adam.nix
      ../users/gio.nix
    ];

  networking.hostName = "${hostName}"; # Define your hostname.

  # Extra Kernal Parameters
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "nvidia-drm.fbdev=1"
  ];
  
  services = {
    timekpr = {
      package = pkgs.unstable.timekpr;
      enable = true;
    };
    openssh = {
      enable = true;
    };
  };

  programs = { 
    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = false; # Open ports in the firewall for Source Dedicated Server
      gamescopeSession.enable = true;
    };
    kdeconnect = {
      enable = true;
    };
    gamescope = {
      enable = true;
    };
  };

  hardware.bluetooth.enable = true;


  # Nvidia graphics options below
  # ==============================

  # Enable OpenGL
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = ["nvidia"];

  # Enable game mode support
  programs.gamemode.enable = true;

   hardware.nvidia = {

    # Modesetting is needed most of the time
    modesetting.enable = true;

    # Enable power management (do not disable this unless you have a reason to).
    # Likely to cause problems on laptops and with screen tearing if disabled.
    powerManagement.enable = false;

    # Use the open source version of the kernel module ("nouveau")
    # Note that this offers much lower performance and does not
    # support all the latest Nvidia GPU features.
    # You most likely don't want this.
    # Only available on driver 515.43.04+
    open = false;

    # Enable the Nvidia settings menu,
    # accessible via `nvidia-settings`.
    nvidiaSettings = true;

    # Optionally, you may need to select the appropriate driver version for your specific GPU.
    package = config.boot.kernelPackages.nvidiaPackages.stable;  # stable runs latest version 545
    # package = config.boot.kernelPackages.nvidiaPackages.production;  # Production lags a bit 535
  };
}
