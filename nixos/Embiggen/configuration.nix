# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, outputs, lib, config, pkgs, ... }:
let 

  hostName      = "Embiggen";

  # Define the llama-cpp package once, reused across all model commands
  llama-cpp = pkgs.unstable.llama-cpp.override { cudaSupport = true; };
  llama-server = "${llama-cpp}/bin/llama-server";

  # Fetch models into the Nix store at build time
  models = {
    qwen35-uncensored = pkgs.fetchurl {
      url = "https://huggingface.co/HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive/resolve/main/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive-Q6_K.gguf";
      hash = "sha256-wLp762j9P+R4kb1UlIbTjc9i0AgXKW6jFK03AX9aSYY="; # replace with real hash
    };
    gemma4 = pkgs.fetchurl {
      url = "https://huggingface.co/unsloth/gemma-4-E4B-it-GGUF/resolve/main/gemma-4-E4B-it-Q6_K.gguf";
      hash = "sha256-A75pV0BO8kTB++PQggMGOwjXWf7htYMSm0XgtOMau/k=";
    };
    qwen3-8b = pkgs.fetchurl {
      url = "https://huggingface.co/Qwen/Qwen3-8B-GGUF/resolve/main/Qwen3-8B-Q4_K_M.gguf";
      hash = "sha256-2YzcvQPhfOR2gUNbUVDjTBQX9QtcABndVg5IgsV0V4U="; # replace with real hash
    };
  };


in
{
  imports = [
    ../../modules/nvidia-container-toolkit.nix
    ../../modules/llms.nix
    ../desktop.nix
    ../dokuwiki.nix
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
    firewall.allowedUDPPorts = [ 9 ];
  };

  # Extra Kernal Parameters
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "nvidia-drm.fbdev=1"
  ];
  
  # Switch to zen kernel 
  # boot.kernelPackages = pkgs.linuxPackages_zen;

  # Enable CUPS to print documents.
  services.printing.drivers = [ pkgs.foomatic-filters pkgs.foomatic-db-nonfree pkgs.foomatic-db-ppds-withNonfreeDb ];

  # Steam settings.
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = false; # Open ports in the firewall for Source Dedicated Server
    gamescopeSession.enable = true;
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

  fileSystems."/home/steam" =
  { device = "/dev/disk/by-uuid/70ea5c33-d6ec-4003-846a-fe5f9708b41c";
  };
  
  fileSystems."/home/important" = {
    device = "mcp:/home/important";
    fsType = "nfs";
    options = [ "x-systemd.automount" "noauto" "x-systemd.idle-timeout=600" ];
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

    # Modesetting is needed most of the time
    modesetting.enable = true;

    # Enable power management (do not disable this unless you have a reason to).
    # Likely to cause problems on laptops and with screen tearing if disabled.
    powerManagement.enable = false;

    # Use the open source version of the kernel module ("nouveau")
    open = false;

    # Enable the Nvidia settings menu,
    # accessible via `nvidia-settings`.
    nvidiaSettings = true;

    package = config.boot.kernelPackages.nvidiaPackages.stable;  
  };
}
