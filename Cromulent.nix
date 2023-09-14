# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./common.nix
      ./suspend2Hibernate.nix
    ];

  networking.hostName = "Cromulent"; # Define your hostname.

  hardware.bluetooth.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.afairbrother = {
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "Adam Fairbrother";
    extraGroups = [ "networkmanager" "wheel" "distrobox" "docker"];
    packages = with pkgs; [
      firefox
      chromium
      teams
      tigervnc
      libsForQt5.bluedevil
      libsForQt5.kalk
      libsForQt5.yakuake
      libsForQt5.okular
      libsForQt5.ark
      libsForQt5.gwenview
      x2goclient
      logseq
      freecad
      libreoffice-fresh
      gimp-with-plugins
      inkscape-with-extensions
      tenacity
      playonlinux
      git
      kate
      xclip
    ];
  };
}

