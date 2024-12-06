# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, outputs, lib, config, pkgs, secrets, ... }:

let
  hostName      = "SecUnit";
  Storage       = "/storage/tank"; 
  wifiInterface = "wlp2s0";
  ethInterface  = "eno1";
  apInterface   = "wlan-ap0";
  accessPointIP = "192.168.10.1";
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../server.nix
      ../users/adam-blank.nix
      ( import ./dnsmasq.nix { ip = accessPointIP; interface = apInterface; })
      ( import ./wifi.nix {interface = apInterface; })
      ( import ./frigate.nix {hostName = hostName; })

    ];

  # Netdata for Debug
  services.netdata.enable = true;

  hardware.cpu.intel.updateMicrocode = true;

  # Enable harware acceleration for video streams
  hardware.opengl = {
    enable = true;
    extraPackages = with pkgs; [
      intel-vaapi-driver
    ];
  };
  hardware.intel-gpu-tools.enable = true;

  # Mount SSD to the ZM storage location
  fileSystems.${Storage} = { 
    device = "/dev/disk/by-uuid/${secrets.secunit.disk-uuid}";
  };

  networking = { 
    hostName = "${hostName}";
    firewall = {
      interfaces = {
        "${apInterface}".allowedUDPPorts = [
          67     # DHCP
          123    # NTP
        ];
        "${ethInterface}".allowedTCPPorts = [
          80     # Web interface
          5000   # API for homeassistant
          8554   # RTSP
          8555   # WebRTC
          19999  # Netdata
        ];
      };
    };
    wlanInterfaces = {
      "${apInterface}" = { device = "${wifiInterface}"; };
    };
    interfaces."${apInterface}".ipv4.addresses = [ {
        address = "${accessPointIP}";
        prefixLength = 24;
      } ];
  };

  #Provide NTP Services
  services.chrony = {
    enable = true;
    extraConfig = ''
      allow 192.168.10.0/24
    '';
  };

}
