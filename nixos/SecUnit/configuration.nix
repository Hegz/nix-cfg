# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, outputs, lib, config, pkgs, secrets, ... }:

let
  # Sops secret management
  sops-nix = builtins.fetchTarball {
    # url = "https://github.com/Mic92/sops-nix/archive/master.tar.gz";
    # Pinned to 22-02-2024
    url = "https://github.com/Mic92/sops-nix/archive/f6b80ab6cd25e57f297fe466ad689d8a77057c11.tar.gz";
    sha256 = "sha256:158n4gwrjpxkgjivmmnlzsy81sxlirmfxgdxhyck5d1pqrwliwls";
  }; 

  ZMStorage = "/storage/tank"; 
  wifiInterface = "wlp2s0";
in
{
  imports =
    [ # Include the results of the hardware scan.
      (import "${sops-nix}/modules/sops")
      ./hardware-configuration.nix
      ../server.nix
      #../dokuwiki.nix
      ../users/adam-blank.nix
      #./suspend2Hibernate.nix
      #./unstable.nix
      #./unstable-keybase.nix
      #./dokuwiki.nix
    ];

  networking.hostName = "SecUnit"; # Define your hostname.

  fileSystems.${ZMStorage} = { 
    device = "/dev/disk/by-uuid/5cc187b4-b98c-450c-b28f-c8e58bce7da5";
  };

  services.zoneminder = {
    enable = true;
    storageDir = "${ZMStorage}";
#    port = 80;
    cameras = 3;
    openFirewall = true;
  };

  services.create_ap = {
	enable = true;
	settings = {
	  WIFI_IFACE = "${wifiInterface}";
      SHARE_METHOD="none";
	  SSID = "${secrets.zoneminder.wifi_name}";
	  PASSPHRASE = "${secrets.zoneminder.wifi_pass}";
      FREQ_BAND="2.4";
	};
  };

  services.dnsmasq = {
    enable = true;
    settings = {
      domain-needed = true;
      bogus-priv = true;
      no-resolv = true;
      cache-size = 1000;
      dhcp-range = [ "${wifiInterface},192.168.10.50,192.168.10.254,24h" ];
      interface = "${wifiInterface}";
      dhcp-host = "192.168.10.1";
      local = "/cam/";
      domain = "cam";
      expand-hosts = true;

      no-hosts = true;
      address = "/zm.cam/192.168.10.1"; 
    };
  };


}
