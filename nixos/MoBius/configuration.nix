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
  nixpkgs.config.permittedInsecurePackages = [
    # Broadcom STA driver is marked insecure on newer kernels; required for Wi-Fi
    "broadcom-sta-6.30.223.271-59-6.12.83"
  ];

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

    kernelModules = [
      "wl"              # Broadcom proprietary Wi-Fi driver
    ];

    extraModulePackages = [
      config.boot.kernelPackages.broadcom_sta
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

      # ---- NVMe ----
      # Prevent NVMe from entering ACPI power states that it can't wake from
      "nvme_core.default_ps_max_latency_us=0"
      "nvme.noacpi=1"

      # ---- Misc ----
      # Suppress noisy but harmless PCIe AER (Advanced Error Reporting) messages
      "pci=noaer"

      # ---- Hibernate resume ----
      # Points the kernel at the swapfile for resume-from-hibernate.
      # The offset was obtained via: sudo filefrag -v /var/lib/swapfile | awk 'NR==4{print $4}'
      "resume_offset=105242624"
    ];

    # Module parameters applied at load time
    extraModprobeConfig = ''
      # F1-F12 by default; hold Fn for media keys (fnmode=1 inverts this)
      options applespi fnmode=2

      # XHCI_RESET_ON_RESUME quirk — forces the xHCI controller to fully
      # reset on resume, which is required for keyboard/trackpad to come back
      options xhci_hcd quirks=0x80
    '';

    # Swapfile used for hibernate; must match swapDevices below
    resumeDevice = "/dev/disk/by-uuid/32b41089-cf45-43e2-8002-7b0bb757d897";
  };

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

	  # Charge thresholds — keep battery between 20-80% to reduce degradation
	  START_CHARGE_THRESH_BAT0 = 20;
	  STOP_CHARGE_THRESH_BAT0  = 80;
	};
  };

  # Suspend on lid close, then hibernate after 30 minutes of sleeping
  services.logind.settings.Login.HandleLidSwitch = "suspend-then-hibernate";
  systemd.sleep.extraConfig = ''
    HibernateDelaySec=30m
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
    cpu.intel.updateMicrocode = true;

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

  # xHCI (USB controller) rebind on resume — the keyboard and trackpad hang
  # off the xHCI controller and don't come back without a full rebind.
  # This sleep hook runs the rebind only on post-resume (not pre-suspend).
  environment.etc."systemd/system-sleep/xhci-rebind.sh" = {
    mode = "0755";
    text = ''
      #!/bin/bash
      if [ "$1" = "post" ]; then
        echo "xhci-rebind: rebinding xHCI controller after resume..."
        echo 0000:00:14.0 > /sys/bus/pci/drivers/xhci_hcd/unbind || true
        sleep 0.5
        echo 0000:00:14.0 > /sys/bus/pci/drivers/xhci_hcd/bind || true
      fi
    '';
  };

  # DNS fix on resume — systemd-resolved loses state after suspend.
  # Restarting it (and NM after a short delay) restores DNS reliably.
  environment.etc."systemd/system-sleep/dns-resume.sh" = {
    mode = "0755";
    text = ''
      #!/bin/bash
      if [ "$1" = "post" ]; then
        echo "dns-resume: restarting systemd-resolved and NetworkManager..."
        systemctl restart systemd-resolved
        sleep 1
        systemctl restart NetworkManager
      fi
    '';
  };

  # Bluetooth resume — the BT controller needs a service restart after wake
  environment.etc."systemd/system-sleep/bluetooth-resume.sh" = {
    mode = "0755";
    text = ''
      #!/bin/bash
      if [ "$1" = "post" ]; then
        systemctl restart bluetooth
      fi
    '';
  };

  # Ensure the system-sleep hook directory exists
  systemd.tmpfiles.rules = [
    "d /etc/systemd/system-sleep 0755 root root -"
  ];

  # ============================================================
  # Networking
  # ============================================================
  networking = {
    hostName        = hostName;
    enableB43Firmware = true;   # B43 firmware blob for Broadcom (fallback; wl is primary)
    networkmanager.dns = "systemd-resolved";
    firewall.enable = true;
  };

  # Use systemd-resolved for DNS; disable DNSSEC as consumer routers often
  # don't support it and it causes spurious resolution failures
  services.resolved = {
    enable  = true;
    dnssec  = "false";
  };

  # Reload the Broadcom wl module at boot if the wifi interface fails to appear.
  # The wl driver occasionally doesn't initialize correctly on first load.
  systemd.services.broadcom-wifi-fix = {
    description = "Reload Broadcom wl module if Wi-Fi interface is missing at boot";
    wantedBy    = [ "network.target" ];
    before      = [ "network.target" ];
    serviceConfig = {
      Type      = "oneshot";
      ExecStart = "${pkgs.writeShellScript "broadcom-wifi-fix" ''
        sleep 5
        if ! ${pkgs.iproute2}/bin/ip link show | grep -q "wlan\|wlp"; then
          echo "broadcom-wifi-fix: no Wi-Fi interface found, reloading wl..."
          ${pkgs.kmod}/bin/modprobe -r wl || true
          sleep 1
          ${pkgs.kmod}/bin/modprobe wl
          sleep 2
          systemctl restart NetworkManager
        fi
      ''}";
    };
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
