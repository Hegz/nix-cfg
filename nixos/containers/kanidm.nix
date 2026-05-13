{serverName}: { inputs, outputs, config, pkgs, lib, secrets, ... }:
let
  hostname    = "kanidm";
  domain      = secrets.tailnet.domain;
in
{
  containers."${hostname}" = {
    autoStart = true;
    privateNetwork = true;
    hostBridge = "br0";

    bindMounts = {
      "/var/lib/kanidm" = {
        hostPath   = "/home/container/${hostname}";
        isReadOnly = false;
      };
      "/var/lib/caddy" = {
        hostPath   = "/home/container/${hostname}/ssl";
        isReadOnly = false;
      };
    };

    config = {config, pkgs, lib, ... }: {
      system.stateVersion = "24.05";

      imports = [
        ../../modules/container-tailscale.nix
      ];

      networking = {
        hostName = "${hostname}";
        networkmanager.enable = true;
        networkmanager.ethernet.macAddress = "${secrets.${serverName}.containers.${hostname}.mac}";
        firewall = {
          allowedTCPPorts = [ 443 3636 ];
          enable = true;
        };
        useHostResolvConf = lib.mkForce false;
      };
      services.resolved.enable = true;

      # Caddy reverse-proxies 443 → Kanidm on 8443.
      # We use transport http { tls_insecure_skip_verify } because Kanidm's
      # cert is self-signed internally; Caddy terminates the public TLS using
      # the Tailscale cert and re-encrypts to Kanidm's backend.
      services.caddy = {
        enable = true;
        virtualHosts."${hostname}.${domain}".extraConfig = ''
          reverse_proxy https://localhost:8443 {
            transport http {
              tls_insecure_skip_verify
            }
          }
          tls /var/lib/caddy/${hostname}.${domain}.crt /var/lib/caddy/${hostname}.${domain}.key {
            protocols tls1.3
          }
        '';
      };

      systemd.timers."ssl-refresh" = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "quarterly";
          Persistent  = true;
          Unit        = "ssl-refresh.service";
        };
      };

      systemd.services."ssl-refresh" = {
        script = ''
          set -eu
          cd /var/lib/caddy
          ${pkgs.tailscale}/bin/tailscale cert ${hostname}.${domain}
          ${pkgs.coreutils}/bin/chown caddy ${hostname}.${domain}.*
          ${pkgs.systemd}/bin/systemctl restart caddy.service
        '';
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
      };

      services.kanidm = {
        enableServer = true;
        package = pkgs.kanidm_1_8;
        serverSettings = {
          bindaddress     = "127.0.0.1:8443";
          ldapbindaddress = "0.0.0.0:3636";
          origin          = "https://${hostname}.${domain}";
          domain          = "${hostname}.${domain}";
          tls_chain       = "/var/lib/kanidm/kanidm.pem";
          tls_key         = "/var/lib/kanidm/kanidm.key";
          log_level       = "info";
        };
      };

      # -----------------------------------------------------------------------
      # OAuth2 client registrations
      #
      # After first `nixos-rebuild switch`, run these once as the Kanidm admin:
      #
      #   kanidm login -D idm_admin -H https://kanidm.${domain}
      #
      #   # Mealie
      #   kanidm system oauth2 create mealie "Mealie" https://mealie.${domain}/oauth2/callback
      #   kanidm system oauth2 update-scope-map mealie idm_all_accounts openid email profile
      #   kanidm system oauth2 show-basic-secret mealie
      #
      #   # Audiobookshelf
      #   kanidm system oauth2 create audiobookshelf "Audiobookshelf" https://audiobookshelf.${domain}/oauth2/callback
      #   kanidm system oauth2 update-scope-map audiobookshelf idm_all_accounts openid email profile
      #   kanidm system oauth2 show-basic-secret audiobookshelf
      #
      #   # FreshRSS
      #   kanidm system oauth2 create freshrss "FreshRSS" https://freshrss.${domain}/oauth2/callback
      #   kanidm system oauth2 update-scope-map freshrss idm_all_accounts openid email profile
      #   kanidm system oauth2 show-basic-secret freshrss
      #
      #   # Frigate
      #   kanidm system oauth2 create frigate "Frigate NVR" https://secunit.${domain}/oauth2/callback
      #   kanidm system oauth2 update-scope-map frigate idm_all_accounts openid email profile
      #   kanidm system oauth2 show-basic-secret frigate
      # -----------------------------------------------------------------------
    };
  };
}
