# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, outputs, lib, config, pkgs, secrets, ... }:

with pkgs; let
  hostName = "GeoGames";
  patchDesktop = pkg: appName: from: to: lib.hiPrio (
    pkgs.runCommand "patched-desktop-entry-for-${appName}" {} ''
      ${coreutils}/bin/mkdir -p $out/share/applications
      ${gnused}/bin/sed 's#${from}#${to}#g' < ${pkg}/share/applications/${appName}.desktop > $out/share/applications/${appName}.desktop
      '');
    GPUOffloadApp = pkg: desktopName: patchDesktop pkg desktopName "^Exec=" "Exec=nvidia-offload ";
in
{
  nixpkgs.overlays = [
 	  (self: super: {
 		  isw = super.callPackage ./isw.nix { };
          msi-perkeyrgb = super.callPackage ./msi-perkeyrgb.nix {
            inherit (super) hidapi;  # passes the C library 
          };
 	  })
   ];

  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../desktop.nix
      ../users/adam.nix
      ../users/gio.nix
      ./isw-module.nix
    ];

  networking.hostName = "${hostName}"; # Define your hostname.

  environment.systemPackages = with pkgs; [
    (GPUOffloadApp steam "steam")
    heroic
    (GPUOffloadApp heroic "com.heroicgameslauncher.hgl")
    prismlauncher
    (GPUOffloadApp prismlauncher "org.prismlauncher.PrismLauncher")
    playonlinux
    (GPUOffloadApp playonlinux "playonlinux")
    freecad
    (GPUOffloadApp freecad "org.freecad.FreeCAD")

    mcontrolcenter
    actkbd
    msi-perkeyrgb
	(pkgs.writeShellScriptBin "msi-rgb-cycle" ''
      export PATH="${pkgs.usbutils}/bin:${pkgs.coreutils}/bin:$PATH"
	  PRESETS=("aqua" "chakra" "default" "disco" "drain" "freeway" "plain" "rainbow-split" "roulette")
	  STATE_FILE="/var/lib/actkbd/msi-rgb-preset"
	  mkdir -p "$(dirname "$STATE_FILE")"
	  CURRENT=0
	  if [[ -f "$STATE_FILE" ]]; then
		CURRENT=$(cat "$STATE_FILE")
	  fi
	  NEXT=$(( (CURRENT + 1) % ''${#PRESETS[@]} ))
	  echo "$NEXT" > "$STATE_FILE"
	  exec ${pkgs.msi-perkeyrgb}/bin/msi-perkeyrgb --model GS65 -p "''${PRESETS[$NEXT]}"
	'')
  ];

  boot.extraModprobeConfig = ''
	options atkbd set2keycodes=1
  '';

  # Increase vm.max_map_count - required for some games (esp. Star Citizen, etc.)
  boot.kernel.sysctl = {
	"vm.max_map_count" = 2147483642;
	"vm.swappiness" = 10;  # reduce swap usage during gaming
  };

  systemd.services.fn-f7-keymap = {
	description = "Map Fn+F7 scancode to keycode";
	wantedBy = [ "multi-user.target" ];
	after = [ "systemd-udev-settle.service" ];
	serviceConfig = {
	  Type = "oneshot";
	  RemainAfterExit = true;
	  ExecStart = "${pkgs.kbd}/bin/setkeycodes e00a 184";
	};
  };

  # Create a config file
  environment.etc."actkbd.conf".text = ''
	184::exec:/run/current-system/sw/bin/msi-rgb-cycle
  '';

  users.users.actkbd = {
	isSystemUser = true;
	group = "actkbd";
	extraGroups = [ "input" ];  # read /dev/input/*
    home = "/var/lib/actkbd";
	description = "actkbd keyboard daemon user";
  };

  users.groups.actkbd = {};

  systemd.services.actkbd = {
	description = "actkbd keyboard shortcut daemon";
	wantedBy = [ "multi-user.target" ];
	after = [ "systemd-udev-settle.service" ];
	serviceConfig = {
	  Type = "forking";
	  User = "actkbd";
      StateDirectory = "actkbd";      # creates /var/lib/actkbd owned by actkbd user
      StateDirectoryMode = "0755";
	  ExecStart = "${pkgs.actkbd}/bin/actkbd -c /etc/actkbd.conf -d /dev/input/by-path/platform-i8042-serio-0-event-kbd";
	  Restart = "on-failure";
	};
  };

  # udev rule for HID access without root
  services.udev.extraRules = ''
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1038", ATTRS{idProduct}=="1122", MODE="0666"
	ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="auto"
    '';

  # Extra Kernal Parameters
  boot = {
    kernelParams = [
      "nvidia-drm.moeset=1"
      "nvidia-drm.fbdev=1"
	  "transparent_hugepage=madvise"
    ];
    extraModulePackages = [ 
      config.boot.kernelPackages.msi-ec 
    ];
    kernelModules = [
      "msi-ec"
    ];
    plymouth = {
      enable = true;
      theme = "bgrt";
    };
	kernelPackages = pkgs.linuxPackages_zen;
  };


  systemd.services."AirplaneKey" = {
    description = "ISW airplane key enable service";
    wantedBy = [ "multi-user.target" "sleep.target" ];
    after = [ "multi-user.target" "sleep.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.isw}/bin/isw -s 0x34 48";
    };
  };
  
  services = {
    logind.settings.Login = {
      HandleSuspendKey = "hibernate";
      HandleLidSwitch = "hibernate";
    };
    undervolt = {
      enable = true;
      analogioOffset = -100; 
      coreOffset = -100;
      gpuOffset = -50;
      uncoreOffset = -100;
    };
    timekpr = {
      package = pkgs.unstable.timekpr;
      enable = true;
    };
    isw = {
      enable = true;
      section = "16Q2EMS1";
    };
    openssh = {
      enable = true;
    };
	thermald = { 
      enable = true;
	};
	libinput = {
	  enable = true;
	  touchpad = {
		tapping = true;
		naturalScrolling = true;
		disableWhileTyping = true;
	  };
	};
	earlyoom = {
	  enable = true;
	  freeMemThreshold = 5;
	  freeSwapThreshold = 10;
	};
	fstrim = {
	  enable = true;
	  interval = "weekly";
	};
  };

  zramSwap = {
	enable = true;
	algorithm = "zstd";
	memoryPercent = 25;
  };


  location.provider = "geoclue2";

  # Font rendering improvements
  fonts.fontconfig = {
	enable = true;
	antialias = true;
	hinting.enable = true;
	hinting.style = "slight";
	subpixel.rgba = "rgb";  # for typical LCD panels
  };


  powerManagement.powertop.enable = true;

  programs = { 
    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = false; # Open ports in the firewall for Source Dedicated Server
      gamescopeSession.enable = true;
	  extraCompatPackages = with pkgs; [
		proton-ge-bin  # community Proton with extra patches
	  ];
    };
    kdeconnect = {
      enable = true;
    };
    gamescope = {
      enable = true;
    };
  };

  hardware.bluetooth.enable = true;

  hardware.cpu.intel.updateMicrocode = true;

  # Nvidia graphics options below
  # ==============================

  # Enable OpenGL
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "modesetting" "nvidia" ];

  # Enable game mode support
  programs.gamemode.enable = true;


   hardware.nvidia = {

    prime = {
      offload = { 
        enable = true;
        enableOffloadCmd = true;
      };
      nvidiaBusId = "PCI:1@0:0:0";
      intelBusId = "PCI:0@0:2:0";
    };


    # Modesetting is needed most of the time
    modesetting.enable = true;

    # Enable power management (do not disable this unless you have a reason to).
    # Likely to cause problems on laptops and with screen tearing if disabled.
    powerManagement.enable = true;
    powerManagement.finegrained = true;

    # Use the open source version of the kernel module ("nouveau")
    # Note that this offers much lower performance and does not
    # support all the latest Nvidia GPU features.
    # You most likely don't want this.
    # Only available on driver 515.43.04+
    open = false;

    # Enable the Nvidia settings menu,
    # accessible via `nvidia-settings`.
    nvidiaSettings = true;

    # Optionally, you may need to select the appropriate driver version for your specific GPU.
    package = config.boot.kernelPackages.nvidiaPackages.stable;  # stable runs latest version 545
    # package = config.boot.kernelPackages.nvidiaPackages.production;  # Production lags a bit 535
  };
}
