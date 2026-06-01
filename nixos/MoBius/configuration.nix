{ config, pkgs, secrets, ... }:
let
  hostName = "MoBius";
in
{
  # ============================================================
  # Imports
  # ============================================================
  imports = [
    ./hardware-configuration.nix
    ../users/afairbrother.nix
    ../desktop.nix
     ../../modules/apple-audio.nix   # Cirrus Logic / CS8409 audio driver for MBP 14,1
    #../syncthing.nix
    #../../modules/suspend2Hibernate.nix
    #../dokuwiki.nix
  ];

  # ============================================================
  # Nixpkgs
  # ============================================================
  nixpkgs.config.allowUnfree = true;

  i18n.defaultLocale = "en_CA.UTF-8";
  i18n.extraLocaleSettings = {
    LC_TIME = "en_CA.UTF-8";
    LC_MEASUREMENT = "en_CA.UTF-8";
  };
  # ============================================================
  # Boot
  # ============================================================
  boot = {
    # Pin to 6.12 LTS to avoid regressions in the working suspend/audio/wifi setup
    kernelPackages = pkgs.linuxPackages_6_12;

    # Load Apple SPI keyboard/trackpad and SMC drivers early so input
    # is available at the initrd stage (e.g. during LUKS unlock)
    initrd.kernelModules = [
      "applespi"
      "spi_pxa2xx_platform"
      "intel_lpss_pci"
      "applesmc"
      "facetimehd"      # FaceTime webcam — load early for faster availability
    ];

    # Modules that cause problems on this hardware
    blacklistedKernelModules = [
      "thunderbolt"     # Causes ACPI errors on RP05; not needed
    ];

    kernelParams = [
      # ---- Input / ACPI ----
      # Treat lid as open on boot to avoid missed open events
      "button.lid_init_state=open"
      # Use ACPI video driver for backlight (required on this MBP)
      "acpi_backlight=video"
      # Suppress EC wakeup events that can prevent or confuse suspend
      "acpi.ec_no_wakeup=1"

      # ---- Intel GPU (i915) ----
      # Enable GuC firmware for better GPU power management
      "i915.enable_guc=2"
      # Disable framebuffer compression — can cause display glitches on Kaby Lake
      "i915.enable_fbc=0"
      # Disable Panel Self Refresh — PSR causes display hangs on resume on this GPU
      "i915.enable_psr=0"
      # Disable display power-saving C-states — another source of resume hangs
      "i915.enable_dc=0"

      # ---- IOMMU ----
      # Disable IOMMU for the iGPU only; full intel_iommu=on causes ACPI resume hangs
      # on this hardware due to malformed Apple DMAR tables
      "intel_iommu=igfx_off"

      # ---- Suspend / Resume ----
      # Force S3 (deep) sleep instead of s2idle; s2idle does not resume on this hardware
      "mem_sleep_default=deep"
      # Disable USB autosuspend — prevents xHCI from power-gating and failing to resume
      "usbcore.autosuspend=-1"
      # Limit CPU C-states to C3; deeper states cause non-resuming hangs on Apple ACPI
      "processor.max_cstate=3"
      "intel_idle.max_cstate=3"

      # ---- Misc ----
      # Suppress noisy but harmless PCIe AER (Advanced Error Reporting) messages
      "pci=noaer"

      # ---- Hibernate resume ----
      # Points the kernel at the swapfile for resume-from-hibernate.
      # The offset was obtained via: sudo filefrag -v /var/lib/swapfile | awk 'NR==4{print $4}'
      "resume_offset=105242624"
      "resume=/dev/disk/by-uuid/32b41089-cf45-43e2-8002-7b0bb757d897"
    ];

    # Module parameters applied at load time
    extraModprobeConfig = ''
    # F1-F12 by default; hold Fn for media keys (fnmode=1 inverts this)
    options applespi fnmode=2
    
    # XHCI_RESET_ON_RESUME quirk — forces the xHCI controller to fully
    # reset on resume, which is required for keyboard/trackpad to come back
    options xhci_hcd quirks=0x80
    
    #Fix for broadcom network addapter resume failures
    options brcmfmac feature_disable=0x82000
    options brcmfmac country_code=CA
    
    #Possible fix  audio resume issues
    options applespi fnmode=2
    options xhci_hcd quirks=0x80
    options snd_hda_intel power_save=0
    options snd_hda_intel power_save_controller=N
    '';

    # Swapfile used for hibernate; must match swapDevices below
    resumeDevice = "/dev/disk/by-uuid/32b41089-cf45-43e2-8002-7b0bb757d897";
  };

  fileSystems."/boot".options = [ "umask=0077" ];

  # ============================================================
  # Swap (used for suspend-then-hibernate)
  # ============================================================
  swapDevices = [{
    device = "/var/lib/swapfile";
    size = 16 * 1024;   # 16 GB — should be >= RAM for reliable hibernate
  }];

  # ============================================================
  # Power Management
  # ============================================================
  powerManagement.enable = true;

  # KDE pulls in power-profiles-daemon by default; disable it so TLP can manage power
  services.power-profiles-daemon.enable = false;

  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC  = "performance";
	  CPU_SCALING_GOVERNOR_ON_BAT = "schedutil";
	  CPU_ENERGY_PERF_POLICY_ON_AC  = "performance";
	  CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";

	  # Allow CPU to boost on battery when needed, just not sustained
	  CPU_BOOST_ON_AC  = 1;
	  CPU_BOOST_ON_BAT = 1;
	};
  };

  # Suspend on lid close, then hibernate after 30 minutes of sleeping
  services.logind.settings.Login = { 
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend-then-hibernate";
    #LidSwitchIgnoreInhibited = "yes";
  };

  systemd.sleep.extraConfig = ''
    HibernateDelaySec=2m
    SuspendState=mem
  '';

  # ============================================================
  # Fan Control
  # ============================================================
  services.mbpfan = {
    enable = true;
    settings.general = {
      low_temp  = 55;   # °C — fan stays off below this
      high_temp = 65;   # °C — fan ramps up above this
      max_temp  = 85;   # °C — fan at maximum above this
    };
  };

  # ============================================================
  # Hardware
  # ============================================================
  hardware = {
    enableRedistributableFirmware = true;   # Includes Broadcom BT firmware
    enableAllFirmware = true;               # Catches anything redistributable misses
    firmware = [ 
      pkgs.linux-firmware 
    ];
    cpu.intel.updateMicrocode = true;
    wirelessRegulatoryDatabase = true;

    bluetooth = {
      enable       = true;
      powerOnBoot  = true;
      settings.General = {
        Experimental    = true;
        FastConnectable = true;
      };
      settings.Policy = {
        AutoEnable      = true;
      };
    };

    facetimehd.enable = true;   # FaceTime HD webcam (Broadcom BCM2763)
  };

  # ============================================================
  # Suspend / Resume Fixes
  # ============================================================

  # Disable NVMe d3cold power state — the Apple NVMe controller cannot
  # wake from d3cold, causing a hard hang on resume
  systemd.services.disable-nvme-d3cold = {
    description = "Disable d3cold for Apple NVMe to prevent suspend hang";
    wantedBy    = [ "multi-user.target" ];
    serviceConfig = {
      Type      = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo 0 > /sys/bus/pci/devices/0000:01:00.0/d3cold_allowed'";
    };
  };

  systemd.services."${hostName}-pre-sleep" = {
	description = "Pre-Sleep Actions (${hostName})";
	wantedBy = [ "sleep.target" ];
	before = [ "sleep.target" ];
	serviceConfig = {
	  Type = "oneshot";
	  ExecStart = "${pkgs.writeShellScript "${hostName}-pre-sleep" ''
		if ${pkgs.kmod}/bin/lsmod | grep -q "^brcmfmac"; then
		  echo "pre-sleep: brcmfmac loaded, unloading..."
		  ${pkgs.kmod}/bin/modprobe --remove-dependencies brcmfmac || true
		else
		  echo "pre-sleep: brcmfmac not loaded, nothing to do"
		fi
	  ''}";
	};
  };

  systemd.services."${hostName}-post-resume" = {
	description = "Post-Resume Actions (${hostName})";
	wantedBy = [ "hibernate.target" "suspend.target" "hybrid-sleep.target" "suspend-then-hibernate.target" ];
	after = [ "hibernate.target" "suspend.target" "hybrid-sleep.target" "suspend-then-hibernate.target" ];
	serviceConfig = {
	  Type = "oneshot";
	  ExecStart = "${pkgs.writeShellScript "${hostName}-post-resume" ''
		echo "${hostName}-post-resume: reloading brcmfmac..."
		${pkgs.kmod}/bin/modprobe brcmutil
		${pkgs.kmod}/bin/modprobe brcmfmac
		sleep 3
		systemctl restart NetworkManager
		sleep 1
		systemctl restart systemd-resolved

		echo "${hostName}-post-resume: rebinding xHCI..."
		echo 0000:00:14.0 > /sys/bus/pci/drivers/xhci_hcd/unbind || true
		sleep 0.5
		echo 0000:00:14.0 > /sys/bus/pci/drivers/xhci_hcd/bind || true

		echo "${hostName}-post-resume: restarting audio..."
		AUDIO_USER=$(${pkgs.systemd}/bin/loginctl list-sessions --no-legend \
		| ${pkgs.gawk}/bin/awk '{print $3}' \
		| ${pkgs.coreutils}/bin/head -1)
		AUDIO_UID=$(${pkgs.coreutils}/bin/id -u "$AUDIO_USER")
		export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$AUDIO_UID/bus"
		export XDG_RUNTIME_DIR="/run/user/$AUDIO_UID"
		# Give pipewire a moment after the HDA reinit
		sleep 2
		${pkgs.shadow.su}/bin/su -c "systemctl --user restart wireplumber" "$AUDIO_USER"
		sleep 1
		${pkgs.shadow.su}/bin/su -c "systemctl --user restart pipewire pipewire-pulse" "$AUDIO_USER"

		echo "${hostName}-post-resume: restarting bluetooth..."
        systemctl restart bluetooth
        sleep 1
        ${pkgs.bluez}/bin/bluetoothctl power off || true
		sleep 0.5
		${pkgs.bluez}/bin/bluetoothctl power on || true

  	  ''}";
	};
  };

  # ============================================================
  # Networking
  # ============================================================
  networking = {
    hostName        = hostName;
    enableB43Firmware = true;   # B43 firmware blob for Broadcom 
    networkmanager.dns = "systemd-resolved";
    firewall.enable = true;
  };

  # Use systemd-resolved for DNS; disable DNSSEC as consumer routers often
  # don't support it and it causes spurious resolution failures
  services.resolved = {
    enable  = true;
    dnssec  = "false";
  };

  # ============================================================
  # Audio
  # ============================================================
  services.pipewire = {
    enable      = true;
    alsa.enable = true;
    pulse.enable = true;
    # jack.enable = true;
  };

  # ============================================================
  # Input
  # ============================================================
  services.libinput.enable = true;

  # Quirks for the Apple SPI touchpad and keyboard
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

  # ============================================================
  # Services
  # ============================================================
  services.fstrim.enable  = true;   # Weekly SSD TRIM
  services.lldpd.enable   = true;   # LLDP neighbour discovery
  services.avahi.enable   = true;   # mDNS / DNS-SD

  programs.kdeconnect.enable = true;   # Phone/desktop integration
}
