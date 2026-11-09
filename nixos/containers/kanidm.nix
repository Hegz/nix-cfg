
{serverName}: {
  inputs,
  outputs,
  config,
  pkgs,
  lib,
  secrets,
  ...
}: let
  hostname = "kanidm";
  domain = secrets.tailnet.domain;
  kanidmPkg   = pkgs.kanidm_1_12;
in {
  containers."${hostname}" = {
    autoStart = true;
    privateNetwork = true;
    hostBridge = "br0";

    bindMounts = {
      "/var/lib/kanidm" = {
        hostPath = "/home/container/${hostname}";
        isReadOnly = false;
      };
      "/var/lib/caddy" = {
        hostPath = "/home/container/${hostname}/ssl";
        isReadOnly = false;
      };
    };

    config = {
      config,
      pkgs,
      lib,
      ...
    }: {
      system.stateVersion = "24.05";

      imports = [
        ../../modules/container-tailscale.nix
      ];
      
      environment.systemPackages = with pkgs; [
        kanidmPkg
      ];

      networking = {
        hostName = "${hostname}";
        networkmanager.enable = true;
        networkmanager.ethernet.macAddress = "${secrets.${serverName}.containers.${hostname}.mac}";
        firewall = {
          #allowedTCPPorts = [443 3636];
          allowedTCPPorts = [443];
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
        '';
      };
      
      # Allow caddy access to the tailscale group
      users.groups.tailscale = {};
      systemd.services.tailscaled.serviceConfig.Group = "tailscale";
      systemd.services.caddy.serviceConfig.SupplementaryGroups = [ "tailscale" ];

      services.kanidm = {
        server = {
          enable = true;
          settings = {
            bindaddress = "127.0.0.1:8443";
            #ldapbindaddress = "0.0.0.0:3636";
            origin = "https://${hostname}.${domain}";
            domain = "${hostname}.${domain}";
            tls_chain = "/var/lib/kanidm/kanidm.pem";
            tls_key = "/var/lib/kanidm/kanidm.key";
            log_level = "info";
          };
        };
        package = kanidmPkg;
      };

      # -----------------------------------------------------------------------
      # OAuth2 client registrations
      #
      # After first `nixos-rebuild switch`, run these once as the Kanidm admin:
      #
      #   kanidm login -D idm_admin -H https://kanidm.${domain}
      # 
      #   for each of the hosts, run the following
      #
      #   kanidm system oauth2 create $host "hostSys" https://kanidm.${domain}/oauth2/callback
      #   kanidm system oauth2 update-scope-map $host idm_all_accounts openid email profile
      #   kanidm system oauth2 show-basic-secret $host
      #
      #   Something whet wrong with authentication?
      #
      #   kanidm system oauth2 rotate-cryptographic-keys $host now -H https://kanidm.${domain}
      # -----------------------------------------------------------------------
    };
  };
}
