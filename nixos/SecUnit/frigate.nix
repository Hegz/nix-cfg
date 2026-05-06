# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').\n

{hostName, ... }: { inputs, outputs, lib, config, pkgs, secrets, ... }:
let
  domain        = secrets.tailnet.domain;
  frigatePort   = 5000;   # frigate's internal HTTP port (NixOS module default)
  oauth2Port    = 4180;   # oauth2-proxy listener
  frigateHost   = lib.toLower hostName;
in
{
  # Enablment for google coral
  boot.extraModulePackages = with config.boot.kernelPackages; [
    gasket
  ];

  services.udev.packages = [ pkgs.unstable.libedgetpu ];
  users.groups.plugdev = {};

  #Enable frigate+
  environment.variables = { PLUS_API_KEY = "${secrets.secunit.frigate}"; };

  # Grant extra access to frigate
  systemd.services.frigate = {
    serviceConfig = {
      SupplementaryGroups = ["render" "video" "plugdev"];
    };
  };

  services.frigate = {
    enable   = true;
    hostname = "${hostName}";
    settings = {
      tls.enabled = false;

      # Tell Frigate to trust the Remote-User header forwarded by oauth2-proxy
      # so that the logged-in username shows up in the UI.
      auth = {
        enabled    = false;   # disable Frigate's own auth — nginx+oauth2-proxy handles it
      };

      mqtt = {
        enabled  = true;
        user     = "${secrets.secunit.mqtt.user}";
        password = "${secrets.secunit.mqtt.password}";
        host     = "${secrets.secunit.mqtt.host}";
      };
      snapshots.enabled = true;
      ffmpeg = {
        hwaccel_args = "preset-vaapi";
        input_args   = "preset-rtsp-udp";
      };
      record = {
        enabled = true;
        retain = {
          days = 7;
          mode = "motion";
        };
        events.retain = {
          default = 30;
          mode    = "motion";
        };
      };
      objects.track = [ "person" "bird" "bear" "cat" "dog" ];
      detectors.coral = {
        type   = "edgetpu";
        device = "usb";
      };
      detect = {
        height            = 360;
        width             = 640;
        fps               = 5;
        annotation_offset = -1400;
      };
      cameras = lib.listToAttrs (map
        (cam: lib.nameValuePair "${cam.name}" {
          ffmpeg.inputs = [ {
            path       = "rtsp://0.0.0.0:8554/${cam.name}";
            input_args = "preset-rtsp-restream";
            roles      = ["record"];
          } {
            path  = "rtsp://${cam.rtsp-user}:${cam.rtsp-pass}@${cam.name}:554/ch1";
            roles = ["detect"];
          } ];
          objects.filters.person.mask = if builtins.hasAttr "person" cam then cam.person else null;
          motion.mask                 = if builtins.hasAttr "motion" cam then cam.motion else null;
        })
        (builtins.filter (x: builtins.hasAttr "rtsp-user" x) secrets.secunit.hosts));
      go2rtc.streams = lib.listToAttrs (map
        (stream: lib.nameValuePair "${stream.name}" "rtsp://0.0.0.0:8554/${stream.name}")
        (builtins.filter (x: builtins.hasAttr "rtsp-user" x) secrets.secunit.hosts));
    };
  };

  services.go2rtc = {
    enable   = true;
    settings = {
      streams = lib.listToAttrs (map
        (stream: lib.nameValuePair "${stream.name}" "rtsp://${stream.rtsp-user}:${stream.rtsp-pass}@${stream.name}:554/ch0")
        (builtins.filter (x: builtins.hasAttr "rtsp-user" x) secrets.secunit.hosts));
      rtsp.listen   = ":8554";
      webrtc.listen = ":8555";
    };
  };

  # ---------------------------------------------------------------------------
  # oauth2-proxy — OIDC sidecar that nginx delegates auth to.
  #
  # Secrets needed in /etc/oauth2-proxy/env (mode 0400, owner root):
  #   OAUTH2_PROXY_CLIENT_SECRET=<kanidm system oauth2 show-basic-secret frigate>
  #   OAUTH2_PROXY_COOKIE_SECRET=<openssl rand -base64 32>
  #
  # Register the client in Kanidm once after deploying:
  #   kanidm system oauth2 create frigate "Frigate NVR" \
  #     https://${frigateHost}.${domain}/oauth2/callback
  #   kanidm system oauth2 update-scope-map frigate idm_all_accounts openid email profile
  #   kanidm system oauth2 show-basic-secret frigate
  # ---------------------------------------------------------------------------
  services.oauth2-proxy = {
    enable   = true;
    provider = "oidc";

    clientID     = "frigate";
    # clientSecret and cookieSecret are injected from the environment file below
    # so they never touch the Nix store.

    oidcIssuerUrl     = "https://kanidm.${domain}/oauth2/openid/frigate";
    redirectURL       = "https://${frigateHost}.${domain}/oauth2/callback";
    cookie.secure     = true;
    cookie.domain     = "${frigateHost}.${domain}";
    httpAddress       = "127.0.0.1:${toString oauth2Port}";

    # Pass the authenticated user's email to Frigate as a header.
    setXauthrequest = true;

    # Only allow users that exist in Kanidm (email domain is a soft guard;
    # Kanidm itself is the authoritative gate).
    email.domains = ["*"];

    extraConfig = {
      # Skip auth for the go2rtc WebRTC path so camera apps still work.
      skip-auth-route        = ["^/live/webrtc" "^/api/ws"];
      upstream               = "http://127.0.0.1:${toString frigatePort}";
      silence-ping-logging   = true;
      # Forward the authenticated user header to Frigate
      pass-user-headers      = true;
    };
  };

  # Inject secrets from a file that is NOT in the Nix store.
  systemd.services.oauth2-proxy.serviceConfig.EnvironmentFile =
    "/etc/oauth2-proxy/env";

  # ---------------------------------------------------------------------------
  # nginx — TLS termination + auth_request gate in front of Frigate.
  #
  # The Frigate NixOS module already configures an nginx vhost on port 80 for
  # `${hostName}`.  We add a second vhost on 443 for the Tailscale FQDN that
  # proxies through oauth2-proxy.
  # ---------------------------------------------------------------------------
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings   = true;

    virtualHosts."${frigateHost}.${domain}" = {
      forceSSL   = true;
      sslCertificate    = "/var/lib/caddy/${frigateHost}.${domain}.crt";
      sslCertificateKey = "/var/lib/caddy/${frigateHost}.${domain}.key";

      locations = {
        # Hand everything through oauth2-proxy, which itself proxies to Frigate.
        "/" = {
          proxyPass = "http://127.0.0.1:${toString oauth2Port}";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header X-Real-IP         $remote_addr;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };

        # oauth2-proxy's own callback and static paths must be reached directly.
        "/oauth2/" = {
          proxyPass = "http://127.0.0.1:${toString oauth2Port}";
          extraConfig = ''
            proxy_set_header X-Auth-Request-Redirect $request_uri;
          '';
        };
      };
    };
  };

  # Tailscale cert refresh for SecUnit (same pattern as container-ssl.nix).
  systemd.timers."ssl-refresh-secunit" = {
    wantedBy  = ["timers.target"];
    timerConfig = {
      OnCalendar = "quarterly";
      Persistent  = true;
      Unit        = "ssl-refresh-secunit.service";
    };
  };

  systemd.services."ssl-refresh-secunit" = {
    script = ''
      set -eu
      mkdir -p /var/lib/caddy
      ${pkgs.tailscale}/bin/tailscale cert ${frigateHost}.${domain}
      mv ${frigateHost}.${domain}.crt /var/lib/caddy/
      mv ${frigateHost}.${domain}.key /var/lib/caddy/
      ${pkgs.coreutils}/bin/chown nginx:nginx \
        /var/lib/caddy/${frigateHost}.${domain}.crt \
        /var/lib/caddy/${frigateHost}.${domain}.key
      ${pkgs.systemd}/bin/systemctl restart nginx.service
    '';
    serviceConfig = {
      Type            = "oneshot";
      User            = "root";
      WorkingDirectory = "/var/lib/caddy";
    };
  };

  # Allow tailscale to issue certs (nginx needs permitCertUid).
  services.tailscale = {
    enable         = true;
    permitCertUid  = "nginx";
  };
}
