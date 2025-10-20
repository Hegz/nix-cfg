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
      ../users/otto.nix
      ../virt/virt.nix
      #../docker/dawarich.nix
      (import ../containers/adGuard.nix {serverName = "${hostName}";})
      (import ../containers/jellyFin.nix {serverName = "${hostName}";})
      (import ../containers/transmission.nix {serverName = "${hostName}";})
      #(import ../containers/smokeping.nix {serverName = "${hostName}";})
      (import ../containers/tt-rss.nix {serverName = "${hostName}";})
      (import ../containers/minecraft.nix {serverName = "${hostName}";})
      (import ../containers/budget.nix {serverName = "${hostName}";})
      (import ../containers/audiobookshelf.nix {serverName = "${hostName}";})
      (import ../containers/mealie.nix {serverName = "${hostName}";})
    ];

  environment.systemPackages = with pkgs; [
    git-crypt
    keybase
    nmap
    vim 
    virt-manager
    zfs
    compose2nix
    wiimms-iso-tools 
    unrar
  ];

  hardware.cpu.intel.updateMicrocode = true;

  boot.supportedFilesystems = [ "zfs" "nfs" ];
  networking.hostId = "${secrets.${hostName}.hostId}";
  boot.zfs.extraPools = [ "zpool" ];

  boot.kernel.sysctl = { 
    "net.core.rmem_max" = 4194304;
    "net.core.wmem_max" = 1048576;
  };
 
  services.nfs.server.enable = true;

  services.zfs = {
    autoScrub.enable = true;
    autoSnapshot = {
      enable = true;
      flags = "-k -p --utc";
    };
    autoReplication = {
      enable = true;
      host = "BackuPi";
      username = "otto";
      identityFilePath = "/home/otto/.ssh/BackuPi";
      localFilesystem = "zpool/ds1/important";
      remoteFilesystem = "backup1";
    };
  };

  # Make our backup server known
  programs.ssh.knownHosts.BackuPi = {
    extraHostNames = [ "backupi.taild7a71.ts.net" ];
    publicKey = "${secrets.BackuPi.publicKey}";
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
       allowedTCPPorts = [ 
         2049  # nfs v4 
       ];
    };
  };
}
