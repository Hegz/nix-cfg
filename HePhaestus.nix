# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:
let
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
      ./common.nix
      ./suspend2Hibernate.nix
      ./unstable.nix
      #./unstable-keybase.nix
      ./dokuwiki.nix
    ];

  networking.hostName = "HePhaestus"; # Define your hostname.

  hardware.bluetooth.enable = true;

  programs.kdeconnect.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.afairbrother = {
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "Adam Fairbrother";
    extraGroups = [ "networkmanager" "wheel" "distrobox" "docker" ];
    packages = with pkgs; [
      chromium
      firefox
      freecad
      gimp-with-plugins
      git
      google-chrome
      inkscape-with-extensions
      kate
      libsForQt5.kdeconnect-kde
      libreoffice-fresh
      libsForQt5.ark
      libsForQt5.bluedevil
      libsForQt5.gwenview
      libsForQt5.kalk
      libsForQt5.okular
      libsForQt5.yakuake
      libsForQt5.plasma-browser-integration
      playonlinux
      quickemu
      tenacity
      tigervnc
      x2goclient
      xclip
      usbimager
    ];
  };
}

