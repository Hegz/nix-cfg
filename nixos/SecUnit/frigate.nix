# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').
{hostName, ...}: {
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  secrets,
  ...
}: let
  domain = secrets.tailnet.domain;
  frigateHost = lib.toLower hostName;
in {
  # Enable google coral
  boot.extraModulePackages = with config.boot.kernelPackages; [
    gasket
  ];

  services.udev.packages = [pkgs.unstable.libedgetpu];
  users.groups.plugdev = {};

  # Enable frigate+
  environment.variables = {PLUS_API_KEY = "${secrets.secunit.frigate}";};

  # Grant extra access to frigate
  systemd.services.frigate = {
    serviceConfig = {
      SupplementaryGroups = ["render" "video" "plugdev"];
    };
  };

  services.frigate = {
    enable = true;
    hostname = "${hostName}";
    settings = {
      tls.enabled = true;
      auth.enabled = true;

      mqtt = {
        enabled = true;
        user = "${secrets.secunit.mqtt.user}";
        password = "${secrets.secunit.mqtt.password}";
        host = "${secrets.secunit.mqtt.host}";
      };
      snapshots.enabled = true;
      ffmpeg = {
        hwaccel_args = "preset-vaapi";
      };
      record = {
        enabled = true;
        alerts = {
          retain = {
            days = 7;
            mode = "motion";
          };
        };
        detections = {
          retain = {
            days = 30;
            mode = "motion";
          };
        };
      };
      objects.track = ["person" "bird" "bear" "cat" "dog"];
      detectors.coral = {
        enabled = "true";
        type = "edgetpu";
        device = "usb";
      };
      detect = {
        height = 360;
        width = 640;
        fps = 5;
        annotation_offset = -1400;
      };
      cameras = lib.listToAttrs (map
        (cam:
          lib.nameValuePair "${cam.name}" {
            ffmpeg.inputs = [
              {
                path = "rtsp://0.0.0.0:8554/${cam.name}";
                input_args = "preset-rtsp-restream";
                roles = ["record"];
              }
              {
                path = "rtsp://${cam.rtsp-user}:${cam.rtsp-pass}@${cam.name}:554/ch1";
                input_args = "-rtsp_transport tcp -timeout 15000000";
                roles = ["detect"];
              }
            ];
            objects.filters.person.mask =
              if builtins.hasAttr "person" cam
              then cam.person
              else null;
            motion.mask =
              if builtins.hasAttr "motion" cam
              then cam.motion
              else null;
          })
        (builtins.filter (x: builtins.hasAttr "rtsp-user" x) secrets.secunit.hosts));
      go2rtc.streams = lib.listToAttrs (map
        (stream: lib.nameValuePair "${stream.name}" "rtsp://0.0.0.0:8554/${stream.name}")
        (builtins.filter (x: builtins.hasAttr "rtsp-user" x) secrets.secunit.hosts));
    };
  };

  services.go2rtc = {
    enable = true;
    settings = {
      streams = lib.listToAttrs (map
        (stream: lib.nameValuePair "${stream.name}" "rtsp://${stream.rtsp-user}:${stream.rtsp-pass}@${stream.name}:554/ch0#transport=tcp")
        (builtins.filter (x: builtins.hasAttr "rtsp-user" x) secrets.secunit.hosts));
      rtsp.listen = ":8554";
      webrtc.listen = ":8555";
    };
  };

  # nginx — TLS termination only, proxying to Frigate's port 5000.
  # Access is restricted to Tailscale network via firewall.
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts."${frigateHost}.${domain}" = {
      forceSSL = true;
      sslCertificate = "/var/lib/caddy/${frigateHost}.${domain}.crt";
      sslCertificateKey = "/var/lib/caddy/${frigateHost}.${domain}.key";

      locations."/" = {
        proxyPass = "http://127.0.0.1:5000";
        proxyWebsockets = true;
      };
    };
  };

  # Tailscale cert refresh
  systemd.timers."ssl-refresh-secunit" = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "quarterly";
      Persistent = true;
      Unit = "ssl-refresh-secunit.service";
    };
  };

  systemd.services."ssl-refresh-secunit" = {
    script = ''
      set -eu
      mkdir -p /var/lib/caddy
      cd /var/lib/caddy
      ${pkgs.tailscale}/bin/tailscale cert ${frigateHost}.${domain}
      ${pkgs.coreutils}/bin/chown nginx:nginx \
        ${frigateHost}.${domain}.crt \
        ${frigateHost}.${domain}.key
      ${pkgs.systemd}/bin/systemctl restart nginx.service
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      WorkingDirectory = "/var/lib/caddy";
    };
  };

  services.tailscale = {
    enable = true;
    permitCertUid = "nginx";
  };
}
