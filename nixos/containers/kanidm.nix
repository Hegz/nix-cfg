{serverName}: { inputs, outputs, config, pkgs, lib, secrets, ... }:
let
  hostname    = "kanidm";
  servicePort = "8443";
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
          allowedTCPPorts = [ 443 ];
          enable = true;
        };
        useHostResolvConf = lib.mkForce false;
      };
      services.resolved.enable = true;

      # Kanidm uses its own TLS — point it at Tailscale certs obtained by the
      # ssl-refresh timer (same pattern as container-ssl.nix).
      systemd.timers."ssl-refresh" = {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = "quarterly";
          Persistent  = true;
          Unit        = "ssl-refresh.service";
        };
      };

      systemd.services."ssl-refresh" = {
        script = ''
          set -eu
          mkdir -p /var/lib/kanidm
          ${pkgs.tailscale}/bin/tailscale cert ${lib.toLower hostname}.${domain}
          cp ${lib.toLower hostname}.${domain}.crt /var/lib/kanidm/kanidm.pem
          cp ${lib.toLower hostname}.${domain}.key /var/lib/kanidm/kanidm.key
          ${pkgs.coreutils}/bin/chown kanidm:kanidm /var/lib/kanidm/kanidm.pem /var/lib/kanidm/kanidm.key
          ${pkgs.systemd}/bin/systemctl restart kanidm.service
        '';
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
      };

      services.kanidm = {
        enableServer = true;
        serverSettings = {
          # Kanidm listens on HTTPS directly — no Caddy reverse-proxy needed.
          bindaddress  = "0.0.0.0:8443";
          ldapbindaddress = "0.0.0.0:3636";   # optional: LDAP for other services
          origin       = "https://${hostname}.${domain}";
          domain       = "${hostname}.${domain}";
          tls_chain    = "/var/lib/kanidm/kanidm.pem";
          tls_key      = "/var/lib/kanidm/kanidm.key";
          db_path      = "/var/lib/kanidm/kanidm.db";
          log_level    = "info";
        };
      };

      # -----------------------------------------------------------------------
      # OAuth2 client registrations
      #
      # After first `nixos-rebuild switch`, run these once as the Kanidm admin:
      #
      #   kanidm login -D idm_admin
      #
      #   # Mealie
      #   kanidm system oauth2 create mealie "Mealie" https://mealie.${domain}/auth/oauth2
      #   kanidm system oauth2 update-scope-map mealie idm_all_accounts openid email profile
      #   kanidm system oauth2 show-basic-secret mealie   # → paste into secrets
      #
      #   # Audiobookshelf
      #   kanidm system oauth2 create audiobookshelf "Audiobookshelf" https://audiobookshelf.${domain}/auth/openid/callback
      #   kanidm system oauth2 update-scope-map audiobookshelf idm_all_accounts openid email profile
      #   kanidm system oauth2 show-basic-secret audiobookshelf
      #
      #   # FreshRSS
      #   kanidm system oauth2 create freshrss "FreshRSS" https://freshrss.${domain}/i/oidc/
      #   kanidm system oauth2 update-scope-map freshrss idm_all_accounts openid email profile
      #   kanidm system oauth2 show-basic-secret freshrss
      # -----------------------------------------------------------------------
    };
  };
}
