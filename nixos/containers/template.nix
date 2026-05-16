{serverName}: { inputs, outputs, config, pkgs, lib, secrets, ... }:
let
  hostname    = "servicename";   # ← change this
  servicePort = "8080";          # ← change this
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
      # Uncomment for TLS via Caddy:
      # "/var/lib/caddy" = {
      #   hostPath   = "/home/container/${hostname}/ssl";
      #   isReadOnly = false;
      # };
    };

    config = {config, pkgs, lib, ... }: {          
      system.stateVersion = "24.05";

      imports = [
        ../../modules/container-tailscale.nix
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

      # Add service definitions here.

    };
  };
}
