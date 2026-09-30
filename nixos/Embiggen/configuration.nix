# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: let
  hostName = "Embiggen";
  unstableKernel = pkgs.unstable.linuxPackages_latest;
in {
  imports = [
    #inputs.linux-rocksmith.nixosModules.default
    ../../modules/nvidia-container-toolkit.nix
    #../../modules/llms.nix
    ../../modules/rocksmith-usb-xlr.nix
    ../desktop.nix
    #../dokuwiki.nix
    ../users/adam.nix
    ./hardware-configuration.nix
  ];

  nixpkgs.config = {
    permittedInsecurePackages = [
      "python3.12-ecdsa-0.19.1"
    ];
  };

  networking = {
    hostName = "${hostName}"; # Define your hostname.
    interfaces.enp25s0.wakeOnLan.enable = true;
    firewall.allowedUDPPorts = [9];
    firewall.allowedTCPPorts = [8012];
  };

  # Extra Kernal Parameters
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "nvidia-drm.fbdev=1"
  ];

  boot.initrd.kernelModules = ["nvidia" "nvidia_modeset" "nvidia_drm" "nvidia_uvm"];

  # Switch to zen kernel
  # boot.kernelPackages = pkgs.linuxPackages_zen;
  boot.kernelPackages = unstableKernel;

  # Enable CUPS to print documents.
  services.printing = {
    enable = true;
    #logLevel = "debug";
    #drivers = [pkgs.foomatic-db-ppds pkgs.foomatic-db pkgs.postscript-lexmark];
  };

  # Steam settings.
  programs.steam = {
    enable = true;
    protontricks.enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = false; # Open ports in the firewall for Source Dedicated Server
    gamescopeSession.enable = true;
    #rocksmithPatch = {
    #  enable = true;
    #  pipeasio = {
    #    inputDevice = "alsa_input.usb-C-Media_Electronics_Inc._USB_Audio_Device-00.mono-fallback";
    #    outputDevice = "alsa_output.pci-0000_28_00.3.analog-surround-41";
    #  };
    #};
    #config.apps."221680".env.WINEDLLPATH = lib.mkForce "${pkgs.pipeasio}/lib/wine";
  };

  #nixpkgs.config.allowUnfreePredicate = pkg:
  #  builtins.elem (lib.getName pkg) [
  #    "valheim-server"
  #    "steamworks-sdk-redist"
  #  ];
  # ...

  # Don't auto start valheim service
  #systemd.services.valheim.wantedBy = lib.mkForce [];
  #services.valheim = {
  #  enable = true;
  #  serverName = "Worldland";
  #  worldName = "Worldland";
  #  openFirewall = true;
  #  password = "12345";
  #  adminList = [ "76561197990259028" ];
  #  permittedList = [ "76561197990259028" "76561199314455669" "76561199221428738" ]; # Me, Mo, & G
  #};

  programs.kdeconnect.enable = true;

  # Don't change the state version.
  system.stateVersion = "23.05"; # Did you read the comment?

  hardware.bluetooth.enable = true;

  fileSystems."/home/steam" = {
    device = "/dev/disk/by-uuid/f7670fb0-3f16-4083-a527-82fa5e0b04c0";
    fsType = "ext4";
  };

  fileSystems."/home/important" = {
    device = "mcp.fair:/home/important";
    fsType = "nfs";
    options = ["x-systemd.automount" "noauto" "x-systemd.idle-timeout=600"];
  };

  # Nvidia graphics options below
  # ==============================

  programs.gamescope.enable = true;

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
    modesetting.enable = true;
    powerManagement.enable = false;
    open = true;
    nvidiaSettings = true;
    package = unstableKernel.nvidiaPackages.stable;
  };
}
