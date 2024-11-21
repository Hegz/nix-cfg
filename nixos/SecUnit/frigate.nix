# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{hostName, ... }: { inputs, outputs, lib, config, pkgs, secrets, ... }:
{
  # Enablment for google coral
  boot.extraModulePackages = with config.boot.kernelPackages; [
    gasket
  ];

  services.udev.packages = [ pkgs.unstable.libedgetpu ];
  users.groups.plugdev = {}; 

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
      detect = {
        height = 360;
        width = 640;
        fps = 5;
        annotation_offset = -1400;
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
}
