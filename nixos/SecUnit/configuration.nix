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
    ];

  # Enablment for google coral
  boot.extraModulePackages = with config.boot.kernelPackages; [
    gasket
  ];
  services.udev.packages = [ pkgs.unstable.libedgetpu ];
  users.groups.plugdev = {}; 

  hardware.cpu.intel.updateMicrocode = true;

  # Mount SSD to the ZM storage location
  fileSystems.${Storage} = { 
    device = "/dev/disk/by-uuid/${secrets.secunit.disk-uuid}";
  };

  # Grant extra access to frigate 
  systemd.services.frigate = {
	serviceConfig = {
		SupplementaryGroups = ["render" "video" "plugdev" ] ; # for access to dev/dri/*, and usb-edgetpu
	};
    environment.LD_LIBRARY_PATH = "${pkgs.unstable.libedgetpu}/lib";
  };
  
  services.frigate = {
    enable = true;
    hostname = "${hostName}";
    settings = {
      ffmpeg = {
        hwaccel_args = "preset-vaapi";		# For Intel video acceleration
        input_args = "preset-rtsp-udp";     # For UDP cameras
      };
      record = {
        enabled = true;
        retain = {
          days = 7;
          mode = "motion";
        };
        events = {
          retain = {
            default = 30;
            mode = "motion";
          };
        };
      }; 
      objects.track = [ "person" "bear" "cat" "dog" ];
      detectors.coral = {
        type = "edgetpu";                 # Google Coral TPU 
        device = "usb";
      };
      cameras = lib.listToAttrs (map
        (cam: lib.nameValuePair "${cam.name}" {
          ffmpeg.inputs = [ {
            path = "rtsp://127.0.0.1:8554/${cam.name}";
            input_args = "preset-rtsp-restream";
            roles = ["record"];
          } {
            path = "rtsp://${cam.rtsp-user}:${cam.rtsp-pass}@${cam.name}:554/ch1";
            roles = [ "detect" ];
          } ];
          motion.mask = if builtins.hasAttr "mask" cam then cam.mask else null;
        } )
        (builtins.filter (x: builtins.hasAttr "rtsp-user" x) secrets.secunit.hosts));
      go2rtc = {
        streams = lib.listToAttrs (map 
          (stream: lib.nameValuePair "${stream.name}" "rtsp://127.0.0.1:8554/${stream.name}")
          (builtins.filter (x: builtins.hasAttr "rtsp-user" x) secrets.secunit.hosts));
      };
    };
  };

  services.go2rtc = {
    enable = true;
    settings = {
      streams = lib.listToAttrs (map 
        (stream: lib.nameValuePair "${stream.name}" "rtsp://${stream.rtsp-user}:${stream.rtsp-pass}@${stream.name}:554/ch0")
        (builtins.filter (x: builtins.hasAttr "rtsp-user" x) secrets.secunit.hosts));
      rtsp.listen = ":8554";
      webrtc.listen = ":8555";
    };
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
  
  # Hostapd based Access point
  services.hostapd = {
    enable        = true;
    radios."${apInterface}" = {
      band        = "2g";
      channel     = 1;
      countryCode = "CA";
      #noScan      = true;
      networks."${apInterface}" = {
    	ssid          = "${secrets.secunit.wifi_name}";
        authentication = {
          mode        = "wpa2-sha1";
          wpaPassword = "${secrets.secunit.wifi_pass}";
        };
        macAcl = "allow";
        macAllow = builtins.map (x: "${x.mac}") (secrets.secunit.hosts);
      };
      wifi4 = {
        enable = true;
        capabilities = [
            "LDPC"
            "HT40+"
            "HT40-"
            "SHORT-GI-20"
            "SHORT-GI-40"
			"TX-STBC"
			"RX-STBC1"
			"DSSS_CCK-40"
          ];
      }; 
      wifi6 = {
        enable = true;
        operatingChannelWidth = "20or40";
        singleUserBeamformee = true;
      };
    }; 
  }; 

  # Enable TPM for better wifi performance?
  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;  # expose /run/current-system/sw/lib/libtpm2_pkcs11.so
    tctiEnvironment.enable = true;  # TPM2TOOLS_TCTI and TPM2_PKCS11_TCTI env variables
  };

  # Enable harware acceleration for video streams
  hardware.opengl = {
    enable = true;
    extraPackages = with pkgs; [
      #intel-media-sdk   # for older GPUs
      intel-vaapi-driver
    ];
  };
  hardware.intel-gpu-tools.enable = true;

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
      interface = "${apInterface}";
      no-hosts = true;

      listen-address ="${accessPointIP}";
      dhcp-option-force = [ 
        "option:router,${accessPointIP}"
        "option:dns-server,${accessPointIP}"
        "option:ntp-server,${accessPointIP}"
      ];
      dhcp-range = [ "192.168.10.50,192.168.10.54,24h" ];
      dhcp-host = builtins.map (x: "${x.mac},${x.name},${x.ip}" ) (
         secrets.secunit.hosts );
    };
  };
}
