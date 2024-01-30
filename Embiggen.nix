# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./common.nix
      #./unstable.nix
      ./dokuwiki.nix
      #./unstable-services.nix
    ];

  networking.hostName = "Embiggen"; # Define your hostname.

  # Enable CUPS to print documents.
  services.printing.drivers = [ pkgs.foomatic-filters pkgs.foomatic-db-nonfree pkgs.foomatic-db-ppds-withNonfreeDb ];

  #services.esphome = {
  #  #enable the ESPhome service
  #  enable = true;
  #  openFirewall = true;
  #  # enableUnixSocket = true;
  #};

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.adam = {
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "Adam Fairbrother";
    extraGroups = [ "networkmanager" "wheel" "video" "docker" ];
    packages = with pkgs; [
      firefox
      chromium
      libsForQt5.bluedevil
      libsForQt5.kalk
      libsForQt5.yakuake
      libsForQt5.okular
      libsForQt5.ark
      libsForQt5.gwenview
      x2goclient
      steam
      freecad
      libreoffice-fresh
      gimp-with-plugins
      inkscape-with-extensions
      tenacity
      playonlinux
      openscad
      git
      transmission-qt
      (pkgs.callPackage ./cura5_4-Appimage.nix {} )
      kate
      xclip
      wine
      esphome
      distrobox
    ];
  };

  # Steam settings.
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = false; # Open ports in the firewall for Source Dedicated Server
  };
  programs.kdeconnect.enable = true;

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

  fileSystems."/home/steam" =
  { device = "/dev/disk/by-uuid/70ea5c33-d6ec-4003-846a-fe5f9708b41c";
  };
  
  fileSystems."/home/Important" = {
    device = "freenas.fair:/mnt/S1/Important";
    fsType = "nfs";
    options = [ "x-systemd.automount" "noauto" "x-systemd.idle-timeout=600" ];
  };
  
  fileSystems."/home/Torrents" = {
    device = "freenas.fair:/mnt/S1/Torrents";
    fsType = "nfs";
    options = [ "x-systemd.automount" "noauto" "x-systemd.idle-timeout=600" ];
  };

  fileSystems."/home/esphome" = {
    device = "//freenas.fair/esphome";
    fsType = "cifs";
    options = let
      # this line prevents hanging on network split
    automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
      in ["${automount_opts},credentials=/etc/nixos/smb-secrets,uid=1000,gid=100"];
  };

  # Nvidia graphics options below
  # ==============================

  # Enable OpenGL
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = ["nvidia"];

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
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

}
