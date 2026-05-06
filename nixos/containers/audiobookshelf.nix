{serverName}: { inputs, outputs, config, pkgs, lib, secrets, ... }:
let
  hostname    = "audiobookshelf";
  servicePort = "13378";
  domain      = secrets.tailnet.domain;
in
{
  containers."${hostname}" = {
    autoStart = true;
    privateNetwork = true;
    hostBridge = "br0";

    bindMounts = {
      "/var/lib/${hostname}" = {
        hostPath   = "/home/container/${hostname}";
        isReadOnly = false;
      };
      "/home/books" = {
        hostPath = "/home/media/Books";
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

      services.audiobookshelf = {
        enable = true;
        host   = "0.0.0.0";
        port   = 13378;
        openFirewall = true;
      };

      # Audiobookshelf OIDC is configured through its web UI, not via Nix,
      # because the settings live in the database.  After deploying, go to:
      #   Settings → Authentication → OpenID Connect (OIDC)
      # and fill in:
      #   Issuer URL : https://kanidm.${domain}/oauth2/openid/audiobookshelf
      #   Client ID  : audiobookshelf
      #   Client Secret: <kanidm system oauth2 show-basic-secret audiobookshelf>
      #   Redirect URI: https://audiobookshelf.${domain}/auth/openid/callback
      #   Button text : Sign in with Kanidm   (or whatever you prefer)
      #
      # Tip: enable "Auto-launch" only after you have verified login works,
      # otherwise you can get locked out.
    };
  };
}
