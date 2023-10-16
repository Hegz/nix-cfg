# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:
let
  dokuwiki-plugin-edittable = pkgs.stdenv.mkDerivation {
    name = "edittable";
    src = pkgs.fetchzip {
      url = "https://github.com/cosmocode/edittable/archive/refs/tags/2023-01-14.zip";
      sha256 = "sha256-Mns8zgucpJrg1xdEopAhd4q1KH7j83Mz3wxuu4Thgsg=";
    };
    sourceRoot = ".";
    installPhase = "mkdir -p $out; cp -r * $out/";
  };

  dokuwiki-plugin-dw2pdf = pkgs.stdenv.mkDerivation {
    name = "dw2pdf";
    src = pkgs.fetchzip {
      url = "https://github.com/splitbrain/dokuwiki-plugin-dw2pdf/archive/refs/tags/2023-09-15.zip";
      sha256 = "sha256-vRX0YuDr2eHjz6+HpFylEaOGee2a/zfenCj/48enyH0=";
    };
    sourceRoot = ".";
    installPhase = "mkdir -p $out; cp -r * $out/";
  };

  dokuwiki-plugin-drawio = pkgs.stdenv.mkDerivation {
    name = "draw.io";
    src = pkgs.fetchzip {
      url = "https://github.com/lejmr/dokuwiki-plugin-drawio/archive/refs/tags/0.2.10.zip";
      sha256 = "sha256-hiAvV5ySZcnPNcWPofq7CFXDR51zA6vEeTuIfi++S8M=";
    };
    sourceRoot = ".";
    installPhase = "mkdir -p $out; cp -r * $out/";
  };



in {
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./common.nix
      #./suspend2Hibernate.nix
      ./unstable-distrobox.nix
    ];

  services.dokuwiki.sites."localhost" = {
    enable = true;
    settings = {
      title = "My Wiki";
      useacl = true;
      superuser = "@admin";
      allowdebug = true;
      dontlog = "";
    };
    plugins = [ dokuwiki-plugin-drawio dokuwiki-plugin-dw2pdf dokuwiki-plugin-edittable ];
    acl = [
      {
        page = "start";
        actor = "@external";
        level = "read";
      }
      {
        page = "*";
        actor = "@user";
        level = "upload";
      }
	];

  };

  networking.hostName = "Cromulent"; # Define your hostname.

  hardware.bluetooth.enable = true;

  nixpkgs.config.permittedInsecurePackages = [
    "teams-1.5.00.23861"
  ];

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
      libreoffice-fresh
      libsForQt5.ark
      libsForQt5.bluedevil
      libsForQt5.gwenview
      libsForQt5.kalk
      libsForQt5.okular
      libsForQt5.yakuake
      logseq
      playonlinux
      quickemu
      teams
      tenacity
      tigervnc
      x2goclient
      xclip
      usbimager
    ];
  };
}

