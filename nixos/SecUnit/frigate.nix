# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{hostName, ... }: { inputs, outputs, lib, config, pkgs, secrets, ... }:
let
  domain      = secrets.tailnet.domain;
  frigatePort = 5000;
  oauth2Port  = 4180;
  frigateHost = lib.toLower hostName;
in
{
  # Enable google coral
  boot.extraModulePackages = with config.boot.kernelPackages; [
    gasket
  ];

  services.udev.packages = [ pkgs.unstable.libedgetpu ];
  users.groups.plugdev = {};

  # Enable frigate+
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
      auth.enabled = false;  # oauth2-proxy handles auth via nginx

      # Proxy auth config — Frigate trusts x-forwarded-user from nginx.
      # default_role is viewer so unauthenticated fallback isn't admin.
      proxy = {
        header_map.user = "x-forwarded-user";
        default_role    = "viewer";
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
  # oauth2-proxy in auth_request mode.
  #
  # Create /etc/oauth2-proxy/env on SecUnit (mode 0400):
  #   OAUTH2_PROXY_CLIENT_SECRET=<kanidm system oauth2 show-basic-secret frigate>
  #   OAUTH2_PROXY_COOKIE_SECRET=<openssl rand -base64 24 | tr -d '=+/' | head -c 32>
  #
  # Register in Kanidm:
  #   kanidm system oauth2 create frigate "Frigate NVR" \
  #     https://secunit.${domain} \
  #     -D idm_admin -H https://kanidm.${domain}
  #   kanidm system oauth2 add-redirect-url frigate \
  #     https://secunit.${domain}/oauth2/callback \
  #     -D idm_admin -H https://kanidm.${domain}
  #   kanidm system oauth2 update-scope-map frigate idm_all_accounts \
  #     openid email profile \
  #     -D idm_admin -H https://kanidm.${domain}
  #   kanidm system oauth2 warning-insecure-client-disable-pkce frigate \
  #     -D idm_admin -H https://kanidm.${domain}
  # ---------------------------------------------------------------------------
  services.oauth2-proxy = {
    enable   = true;
    provider = "oidc";

    clientID      = "frigate";
    keyFile       = "/etc/oauth2-proxy/env";
    cookie.secure = true;
    cookie.domain = "${frigateHost}.${domain}";
    httpAddress   = "127.0.0.1:${toString oauth2Port}";

    oidcIssuerUrl = "https://kanidm.${domain}/oauth2/openid/frigate";
    redirectURL   = "https://${frigateHost}.${domain}/oauth2/callback";

    setXauthrequest = true;
    email.domains   = [ "*" ];

    extraConfig = {
      upstream             = "static://202";
      reverse-proxy        = true;
      silence-ping-logging = true;
      oidc-email-claim     = "preferred_username";
      client-secret-file   = "/run/oauth2-proxy-secrets-frigate/client-secret";
      cookie-secret-file   = "/run/oauth2-proxy-secrets-frigate/cookie-secret";
    };
  };

  systemd.services.oauth2-proxy = {
    serviceConfig.ExecStartPre = [
      ("+" + toString (pkgs.writeShellScript "oauth2-proxy-secrets-frigate" ''
        set -eu
        dir=/run/oauth2-proxy-secrets-frigate
        mkdir -p "$dir"
        chmod 700 "$dir"
        grep '^OAUTH2_PROXY_CLIENT_SECRET=' /etc/oauth2-proxy/env | head -1 | cut -d= -f2- \
          > "$dir/client-secret"
        grep '^OAUTH2_PROXY_COOKIE_SECRET=' /etc/oauth2-proxy/env | head -1 | cut -d= -f2- \
          > "$dir/cookie-secret"
        chmod 400 "$dir/client-secret" "$dir/cookie-secret"
        chown oauth2-proxy "$dir/client-secret" "$dir/cookie-secret"
      ''))
    ];
  };

  # ---------------------------------------------------------------------------
  # nginx — TLS termination + auth_request gate.
  # The Frigate NixOS module already creates a vhost on port 80.
  # We add a vhost on 443 using the auth_request pattern.
  # ---------------------------------------------------------------------------
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings   = true;

    # Strip @domain suffix from preferred_username for display
    appendHttpConfig = ''
      map $auth_request_user $auth_user_stripped {
        "~^(?P<user>[^@]+)@.*$" $user;
        default                 $auth_request_user;
      }
    '';

    virtualHosts."${frigateHost}.${domain}" = {
      forceSSL          = true;
      sslCertificate    = "/var/lib/caddy/${frigateHost}.${domain}.crt";
      sslCertificateKey = "/var/lib/caddy/${frigateHost}.${domain}.key";

      extraConfig = ''
        auth_request /oauth2/auth;
        error_page 401 = /oauth2/start;
        auth_request_set $auth_request_user $upstream_http_x_auth_request_preferred_username;
      '';

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString frigatePort}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header X-Real-IP         $remote_addr;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-User  $auth_user_stripped;
        '';
      };

      # WebRTC and API paths bypass auth so camera apps keep working
      locations."^~ /live/webrtc" = {
        proxyPass = "http://127.0.0.1:${toString frigatePort}";
        proxyWebsockets = true;
        extraConfig = ''
          auth_request off;
        '';
      };

      locations."^~ /api/ws" = {
        proxyPass = "http://127.0.0.1:${toString frigatePort}";
        proxyWebsockets = true;
        extraConfig = ''
          auth_request off;
        '';
      };

      locations."/oauth2/" = {
        proxyPass = "http://127.0.0.1:${toString oauth2Port}";
        extraConfig = ''
          auth_request off;
          proxy_set_header X-Auth-Request-Redirect $request_uri;
        '';
      };

      locations."/oauth2/auth" = {
        proxyPass = "http://127.0.0.1:${toString oauth2Port}";
        extraConfig = ''
          auth_request off;
          proxy_pass_request_body off;
          proxy_set_header Content-Length "";
          proxy_set_header X-Original-URI $request_uri;
        '';
      };
    };
  };

  # Tailscale cert refresh
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
      cd /var/lib/caddy
      ${pkgs.tailscale}/bin/tailscale cert ${frigateHost}.${domain}
      ${pkgs.coreutils}/bin/chown nginx:nginx \
        ${frigateHost}.${domain}.crt \
        ${frigateHost}.${domain}.key
      ${pkgs.systemd}/bin/systemctl restart nginx.service
    '';
    serviceConfig = {
      Type            = "oneshot";
      User            = "root";
      WorkingDirectory = "/var/lib/caddy";
    };
  };

  services.tailscale = {
    enable        = true;
    permitCertUid = "nginx";
  };
}
