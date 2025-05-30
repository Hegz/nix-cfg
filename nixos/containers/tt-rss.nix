{serverName}: { inputs, outputs, config, pkgs, lib, secrets, ... }:
let
  hostname = "tt-rss";
in
{
  containers."${hostname}" = {                                                                                              
    autoStart = true;                                      
	privateNetwork = true;
    hostBridge = "br0";

    # Filesystem mount points
    bindMounts = {                                         
      "/var/lib/tt-rss" = {                               
        hostPath = "/home/container/${hostname}";
        isReadOnly = false;                                
      };                                                   
    };

    config = {config, pkgs, lib, ... }: {          
      system.stateVersion = "24.05";

      networking = {                                   
        hostName = "${hostname}";
        networkmanager.enable = true;
        networkmanager.ethernet.macAddress = "${secrets.${serverName}.containers.${hostname}.mac}";
        firewall = {                                                                                                  
          enable = true;                                   
          allowedTCPPorts = [ 80 ];
          # allowedUDPPorts = [ 53 ];
        };                           
        # Use systemd-resolved inside the container 
        # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
        useHostResolvConf = lib.mkForce false;             
      };                                                   
      services.resolved.enable = true;

      # Add service definitions here.

      services.tt-rss = {
        enable = true;
        selfUrlPath = "http://${hostname}.fair";
      };

      services.nginx.virtualHosts."${config.services.tt-rss.virtualHost}" = {
        forceSSL = true;
        sslCertificate = "/var/lib/tt-rss/ssl/tt-rss.taild7a71.ts.net.crt";
        sslCertificateKey = "/var/lib/tt-rss/ssl/tt-rss.taild7a71.ts.net.key";
      };
      
      # Enable tailscale
      services.tailscale = {
        enable = true;
        interfaceName = "userspace-networking";
      };

    };                                                   
  };
}
