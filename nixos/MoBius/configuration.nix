# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, secrets, ... }:
let
  hostName    = "MoBius";
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../users/afairbrother.nix
      ../desktop.nix
      #../syncthing.nix
      ../../modules/suspend2Hibernate.nix
      #../dokuwiki.nix
    ];

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    "broadcom-sta-6.30.223.271-59-6.12.83"
  ];

  boot = {
    initrd.kernelModules = [
      "applespi"
      "spi_pxa2xx_platform"
      "intel_lpss_pci"
      "applesmc"
    ];
    # Suspend fixes
	kernelParams = [
	  "button.lid_init_state=open"
	  "acpi_osi=Linux"
	  "acpi_backlight=video"
	  "i915.enable_guc=2"
	  "i915.enable_fbc=1"
	  "i915.enable_psr=2"
          "intel_iommu=on" 
	];

    kernelModules = [ "wl" ];
    extraModulePackages = [ config.boot.kernelPackages.broadcom_sta ];
  };


  # Touchpad quirks to make "disable-while-typing" actually work
  services.libinput.enable = true;
  environment.etc."libinput/local-overrides.quirks".text = ''
    [MacBook(Pro) SPI Touchpads]
    MatchName=*Apple SPI Touchpad*
    ModelAppleTouchpad=1
    AttrTouchSizeRange=200:150
    AttrPalmSizeThreshold=1100

    [MacBook(Pro) SPI Keyboards]
    MatchName=*Apple SPI Keyboard*
    AttrKeyboardIntegration=internal
  '';

  # Wifi, CPU Microcode FW updates
  networking.enableB43Firmware = true;
  hardware = {
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = true;
  };

  services.fstrim.enable = true;

  networking.hostName = "${hostName}"; # Define your hostname.

  hardware.enableAllFirmware = true;
  hardware.bluetooth.enable = true;

  # FaceTime webcam
  hardware.facetimehd.enable = true;

  # Fan control
  services.mbpfan = {
    enable = true;
    settings.general = {
      low_temp = 50;
      high_temp = 55;
      max_temp = 65;
    };
  };

  # NVMe suspend fix
  systemd.services.disable-nvme-d3cold = {
    enable = true;
    description = "Disable d3cold for NVMe to fix suspend";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.coreutils}/bin/sh -c 'echo 0 > /sys/bus/pci/devices/0000:01:00.0/d3cold_allowed'";
    };
  };


  programs.kdeconnect.enable = true;

  services.lldpd.enable = true; # Enable LLDP to discover network devices.
  services.avahi.enable = true; # Enable avahi to discover mdns  devices.

  #services.printing = {
  #  enable = false; # Enable printing services.
  #  clientConf = ''
  #    ServerName 10.173.0.8
  #  '';
  #};
  networking.firewall = {
    enable = true; # Enable the firewall.
  };
}

