# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, outputs, lib, config, pkgs, secrets, ... }:

let
  hostName      = "MCP";
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../server.nix
      ../users/adam-blank.nix
      ../virt/virt.nix
      (import ../containers/adGuard.nix {serverName = "${hostName}";})
      (import ../containers/jellyFin.nix {serverName = "${hostName}";})
      (import ../containers/transmission.nix {serverName = "${hostName}";})
    ];

  hardware.cpu.intel.updateMicrocode = true;

  boot.supportedFilesystems = [ "zfs" "nfs" ];
  networking.hostId = "${secrets.${hostName}.hostId}";
  boot.zfs.extraPools = [ "zpool" ];
 
  services.nfs.server.enable = true;

  fileSystems."/home/haos/Backup" = {
    device = "zpool/ds1/haos/Backup";
    fsType = "zfs";
    options = [ "zfsutil" ];
  };

  fileSystems."/home/media" = {
    device = "zpool/ds1/media";
    fsType = "zfs";
    options = [ "zfsutil" ];
  };

  fileSystems."/home/container" = {
    device = "zpool/ds1/container";
    fsType = "zfs";
    options = [ "zfsutil" ];
  };

  fileSystems."/home/important" = {
    device = "zpool/ds1/important";
    fsType = "zfs";
    options = [ "zfsutil" ];
  };

  # Enable harware acceleration for video streams
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-vaapi-driver
    ];
  };
  hardware.intel-gpu-tools.enable = true;

  # Enable bridge mode networking for containers.
  networking = {
     hostName = "${hostName}";
     bridges.br0.interfaces = [ "enp1s0" ];

     useDHCP = false;
     interfaces."br0".useDHCP = true;
     firewall = {
       enable = true;
    };
  };

}
