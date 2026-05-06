{serverName}: { inputs, outputs, config, pkgs, lib, secrets, ... }:
let
  hostname    = "mealie";
  servicePort = "9000";
  domain      = secrets.tailnet.domain;
in
{
  containers."${hostname}" = {
    autoStart = true;
    privateNetwork = true;
    hostBridge = "br0";

    bindMounts = {
      "/var/lib/private" = {
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
        (import ../../modules/container-ssl.nix {port = "${servicePort}"; inherit secrets;})
      ];

      networking = {
        hostName = "${hostname}";
        networkmanager.enable = true;
        networkmanager.ethernet.macAddress = "${secrets.${serverName}.containers.${hostname}.mac}";
        firewall = {
          allowedTCPPorts = [ 80 443 ];
          enable = true;
        };
        useHostResolvConf = lib.mkForce false;
      };
      services.resolved.enable = true;

      services.mealie = {
        enable = true;
        port   = 9000;

        # OIDC / SSO via Kanidm.
        # Add to /home/container/mealie/oidc.env on the host:
        #   OIDC_CLIENT_SECRET=<output of: kanidm system oauth2 show-basic-secret mealie>
        credentialsFile = "/var/lib/private/mealie/oidc.env";

        settings = {
          ALLOW_SIGNUP            = "false";

          OIDC_AUTH_ENABLED       = "true";
          OIDC_SIGNUP_ENABLED     = "true";
          OIDC_CONFIGURATION_URL  = "https://kanidm.${domain}/oauth2/openid/mealie/.well-known/openid-configuration";
          OIDC_CLIENT_ID          = "mealie";
          # OIDC_CLIENT_SECRET is injected from credentialsFile
          OIDC_AUTO_REDIRECT      = "false";
          OIDC_REMEMBER_ME        = "true";
          OIDC_USER_CLAIM         = "email";
          OIDC_GROUPS_CLAIM       = "groups";
          OIDC_ADMIN_GROUP        = "idm_admins";
        };
      };
    };
  };
}
