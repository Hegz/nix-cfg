# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, outputs, lib, config, pkgs, secrets, ... }:

let
  ZMStorage = "/storage/tank"; 
  wifiInterface = "wlp2s0";
  accessPointIP = "192.168.10.1";
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../server.nix
      ../users/adam-blank.nix
    ];

  networking.hostName = "SecUnit"; # Define your hostname.

  # manually open required ports for AP
  networking.firewall.interfaces.ap0.allowedUDPPorts = [
      67  # Allow DHCP
      123 # Allow NTP
  ];

  # Mount SSD to the ZM storage location
  fileSystems.${ZMStorage} = { 
    device = "/dev/disk/by-uuid/${secrets.zoneminder.disk-uuid}";
  };

  # Enable the zoneminder service
  services.zoneminder = {
    enable = true;
    storageDir = "${ZMStorage}";
    cameras = 3;
    openFirewall = true;
    database = {
      createLocally = true;
      username = "zoneminder";
      #Manditory username for localdb
    };
  };

  # Create access point, local access only
  services.create_ap = {
	enable = true;
	settings = {
	  WIFI_IFACE = "${wifiInterface}";
      SHARE_METHOD="none";
	  SSID = "${secrets.zoneminder.wifi_name}";
	  PASSPHRASE = "${secrets.zoneminder.wifi_pass}";
      FREQ_BAND="2.4";
      NO_DNSMASQ=1;
      GATEWAY="${accessPointIP}";
      IEEE80211N=1;
      #ISOLATE_CLIENTS=1;
	};
  };

  #Provide NTP Services
  services.chrony = {
    enable = true;
    extraConfig = ''
      allow 192.168.10.0/24
    '';
  };

  #Provide DNS and DHCP
  services.dnsmasq = {
    enable = true;
    settings = {
      domain-needed = true;
      bogus-priv = true;
      no-resolv = true;
      cache-size = 1000;
      server = [ "1.1.1.1" "8.8.8.8" ];
      bind-dynamic = true;

      # DHCP Settings
      interface = "ap0";
      no-hosts = true;

      listen-address ="${accessPointIP}";
      dhcp-option-force = [ 
        "option:router,${accessPointIP}"
        "option:dns-server,${accessPointIP}"
        "option:ntp-server,${accessPointIP}"
      ];
      dhcp-range = [ "192.168.10.50,192.168.10.54,24h" ];
      dhcp-host = [
        "${secrets.zoneminder.host0.mac},${secrets.zoneminder.host0.name},192.168.10.50" 
        "${secrets.zoneminder.host1.mac},${secrets.zoneminder.host1.name},192.168.10.51" 
        "${secrets.zoneminder.host2.mac},${secrets.zoneminder.host2.name},192.168.10.52" 
        "${secrets.zoneminder.host3.mac},${secrets.zoneminder.host3.name},192.168.10.53" 
        "${secrets.zoneminder.host4.mac},${secrets.zoneminder.host4.name},192.168.10.54" 
      ];
    };
  };
}
