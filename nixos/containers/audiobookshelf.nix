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
        # Caddy proxies directly to Audiobookshelf — OIDC is handled natively
        # by Audiobookshelf itself, configured via the web UI.
        (import ../../modules/container-ssl.nix { port = servicePort; inherit secrets; })
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
        host   = "127.0.0.1";
        port   = 13378;
      };
    };
  };
}
