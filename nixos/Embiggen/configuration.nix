# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, outputs, lib, config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../desktop.nix
      ../dokuwiki.nix
      #../syncthing.nix
      ../users/adam.nix
      ../../modules/nvidia-container-toolkit.nix
    ];

  networking.hostName = "Embiggen"; # Define your hostname.

  # Extra Kernal Parameters
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "nvidia-drm.fbdev=1"
  ];
  
  # Switch to zen kernel 
  # boot.kernelPackages = pkgs.linuxPackages_zen;

  # Enable CUPS to print documents.
  services.printing.drivers = [ pkgs.foomatic-filters pkgs.foomatic-db-nonfree pkgs.foomatic-db-ppds-withNonfreeDb ];

  #services.esphome = {
  #  #enable the ESPhome service
  #  enable = true;
  #  openFirewall = true;
  #  # enableUnixSocket = true;
  #};

  # Define a user account. Don't forget to set a password with ‘passwd’.

  # Steam settings.
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = false; # Open ports in the firewall for Source Dedicated Server
    gamescopeSession.enable = true;
  };

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
  #    "valheim-server"
      "steamworks-sdk-redist"
    ];
  # ...

  # Don't auto start valheim service
  systemd.services.valheim.wantedBy = lib.mkForce [];
  services.valheim = {
    enable = true;
    serverName = "Worldland";
    worldName = "Worldland";
    openFirewall = true;
    password = "12345";
    adminList = [ "76561197990259028" ];
    permittedList = [ "76561197990259028" "76561199314455669" "76561199221428738" ]; # Me, Mo, & G
  };

  programs.kdeconnect.enable = true;


  # Enable wake on lan
  networking.interfaces.enp25s0.wakeOnLan.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  #  networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?

  #home-manager.users.afairbrother = { pkgs, ... }: {
    
  #};

  hardware.bluetooth.enable = true;


  fileSystems."/home/steam" =
  { device = "/dev/disk/by-uuid/70ea5c33-d6ec-4003-846a-fe5f9708b41c";
  };
  
  fileSystems."/home/important" = {
    device = "mcp:/home/important";
    fsType = "nfs";
    options = [ "x-systemd.automount" "noauto" "x-systemd.idle-timeout=600" ];
  };
  #
  #fileSystems."/home/Torrents" = {
  #  device = "freenas.fair:/mnt/S1/Torrents";
  #  fsType = "nfs";
  #  options = [ "x-systemd.automount" "noauto" "x-systemd.idle-timeout=600" ];
  #};

 # fileSystems."/home/esphome" = {
 #   device = "//freenas.fair/esphome";
 #   fsType = "cifs";
 #   options = let
 #     # this line prevents hanging on network split
 #   automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
 #     in ["${automount_opts},credentials=/etc/nixos/smb-secrets,uid=1000,gid=100"];
 # };


 # Potentially causing instability?
 # services.sunshine = {
 #   enable = true;
 #   autoStart = true;
 #   capSysAdmin = true; # only needed for Wayland -- omit this when using with Xorg
 #   openFirewall = true;
 # }; 

  # Fixes issue regarding "Failed to gain CAP_SYS_ADMIN"
  #security.wrappers.sunshine = {
  #  owner = "root";
  #	group = "root";
  #	capabilities = "cap_sys_admin+p";
  #	source = "${pkgs.sunshine}/bin/sunshine";
  #};

  # Fixes "avahi::entry_group_new() failed" permission
  # services.avahi.publish.enable = true;
  # services.avahi.publish.userServices = true;



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

  #programs.gamemode.settings = {
  #  general = {
  #  	renice = 10;
  #	};

  #	# Warning: GPU optimisations have the potential to damage hardware
  #	gpu = {
  #  	apply_gpu_optimisations = "accept-responsibility";
  #  	gpu_device = 0;
  #  	amd_performance_level = "high";
  #	};

  #	custom = {
  #  	start = "${pkgs.libnotify}/bin/notify-send 'GameMode started'";
  #  	end = "${pkgs.libnotify}/bin/notify-send 'GameMode ended'";
  #	};
  #}

  hardware.nvidia = {

    # Modesetting is needed most of the time
    modesetting.enable = true;

    # Enable power management (do not disable this unless you have a reason to).
    # Likely to cause problems on laptops and with screen tearing if disabled.
    powerManagement.enable = true;

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
