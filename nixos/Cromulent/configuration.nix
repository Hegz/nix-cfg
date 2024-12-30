# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, outputs, lib, config, pkgs, ... }:

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
      ../desktop.nix
      ../dokuwiki.nix
      ../users/afairbrother.nix
      #./suspend2Hibernate.nix
      #./unstable.nix
      #./unstable-keybase.nix
      #./dokuwiki.nix
    ];

  networking.hostName = "Cromulent"; # Define your hostname.

  hardware.bluetooth.enable = true;

  programs.kdeconnect.enable = true;

  services.opensnitch.enable = true;

  services.udev.extraRules = ''
    # Allow users in the plugdev group to access the USB devices
    #SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", MODE="0664", GROUP="plugdev"
    
    # Added to allow access to ATTiny85 USB devices
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="16d0", ATTRS{idProduct}=="0753", MODE:="0666"
    KERNEL=="ttyACM*", ATTRS{idVendor}=="16d0", ATTRS{idProduct}=="0753", MODE:="0666", ENV{ID_MM_DEVICE_IGNORE}="1"
  '';

  containers.adGuard = {
    autoStart = true;
    config = {config, pkgs, lib, ... }: {
      system.stateVersion = "24.05";
	  networking = {
        firewall = {
          enable = true;
          allowedTCPPorts = [ 80 ];
        };
		# Use systemd-resolved inside the container
      	# Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
      	useHostResolvConf = lib.mkForce false;
      };
	  services.resolved.enable = true;
    };
  };

  # Steam settings.
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = false; # Open ports in the firewall for Source Dedicated Server
  };
}

