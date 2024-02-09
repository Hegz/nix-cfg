# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:
let
  # Sops secret management
  sops-nix = builtins.fetchTarball {
    url = "https://github.com/Mic92/sops-nix/archive/master.tar.gz";
    sha256 = "sha256:1fi778i85w9zhl3m6fr362dip2xmb1blywvilgh2yg6w71qrg2m5";
  }; 
in
{
  imports =
    [ # Include the results of the hardware scan.
      (import "${sops-nix}/modules/sops")
      ./hardware-configuration.nix
      ./common.nix
      #./suspend2Hibernate.nix
      ./unstable.nix
      #./unstable-keybase.nix
      ./dokuwiki.nix
    ];

  networking.hostName = "Cromulent"; # Define your hostname.

  hardware.bluetooth.enable = true;

  programs.kdeconnect.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.afairbrother = {
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "Adam Fairbrother";
    extraGroups = [ "networkmanager" "wheel" "distrobox" "docker"];
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

