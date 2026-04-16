# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, outputs, lib, config, pkgs, secrets, ... }:

with pkgs; let
  hostName = "GeoGames";
  patchDesktop = pkg: appName: from: to: lib.hiPrio (
    pkgs.runCommand "$patched-desktop-entry-for-${appName}" {} ''
      ${coreutils}/bin/mkdir -p $out/share/applications
      ${gnused}/bin/sed 's#${from}#${to}#g' < ${pkg}/share/applications/${appName}.desktop > $out/share/applications/${appName}.desktop
      '');
    GPUOffloadApp = pkg: desktopName: patchDesktop pkg desktopName "^Exec=" "Exec=nvidia-offload ";
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

  environment.systemPackages = with pkgs; [
    (GPUOffloadApp steam "steam")
    (GPUOffloadApp heroic "com.heroicgameslauncher.hgl")
  ];

  # Extra Kernal Parameters
  boot.kernelParams = [
    "nvidia-drm.moeset=1"
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
    tlp = {
      enable = false;
      settings =  {
        CPU_SCALING_GOVENOR_ON_AC = "performance";
        CPU_SCALING_GOVENOR_ON_BAT = "powersave";
        ENERGY_PERF_POLICY_ON_AC = "performance";
        ENERGY_PERF_POLICY_ON_BAT = "power";
        CPU_BOOST_ON_AC = 1;
        CPU_BOOST_ON_BAT = 0;
        PCIE_ASPM_ON_AC = "off";
        PCIE_ASPM_ON_BAT = "on";
        WIFI_PWR_ON_AC = "off";
        WIFI_PWR_ON_BAT = "on";
        NVIDIA_DRM_MODE_ON_AC = 1;
        NVIDIA_DRM_MODE_ON_BAT = 0;
      };
    };

  };

  powerManagement = {
    enable = true;
    powertop.enable = true;
  };

  programs = { 
    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = false; # Open ports in the firewall for Source Dedicated Server
      gamescopeSession.enable = true;
      package = pkgs.steam.override {
        extraEnv = { 
          __NV_PRIME_RENDER_OFFLOAD = "1";
          __NV_PRIME_RENDER_OFFLOAD_PROVIDER = "NVIDIA-G0";
          __GLX_VENDOR_LIBRARY_NAME = "nvidia";
          __VK_LAYER_NV_optimus = "NVIDIA_only";
        };
      };
    };
    kdeconnect = {
      enable = true;
    };
    gamescope = {
      enable = true;
    };
  };

  hardware.bluetooth.enable = true;

  hardware.cpu.intel.updateMicrocode = true;

  # Nvidia graphics options below
  # ==============================

  # Enable OpenGL
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "modesetting" "nvidia" ];

  # Enable game mode support
  programs.gamemode.enable = true;


   hardware.nvidia = {

    prime = {
      offload = { 
        enable = true;
        enableOffloadCmd = true;
      };
      nvidiaBusId = "PCI:1@0:0:0";
      intelBusId = "PCI:0@0:2:0";
    };


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
