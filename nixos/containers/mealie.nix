{serverName}: { inputs, outputs, config, pkgs, lib, secrets, ... }:
let
  hostname = "mealie";
  servicePort = "9000";
in
{
  containers."${hostname}" = {                                                                                              
    autoStart = true;                                      
	privateNetwork = true;
    hostBridge = "br0";

    # Filesystem mount points
    bindMounts = {                                         
      "/var/lib/private" = {                               
        hostPath = "/home/container/${hostname}";
        isReadOnly = false;                                
      };
      "/var/lib/caddy" = {
        hostPath = "/home/container/${hostname}/ssl";
        isReadOnly = false;
      };      
    };

    config = {config, pkgs, lib, ... }: {          
      system.stateVersion = "24.05";
		
      imports = [
        ../../modules/container-tailscale.nix
        (import ../../modules/container-ssl.nix {port = "${servicePort}";})
      ];

      networking = {                                   
        hostName = "${hostname}";
        networkmanager.enable = true;
        networkmanager.ethernet.macAddress = "${secrets.${serverName}.containers.${hostname}.mac}";
        firewall = {                                                                                                  
          allowedTCPPorts = [ 80 443 ];
          enable = true;                                   
        };                           
        # Use systemd-resolved inside the container 
        # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
        useHostResolvConf = lib.mkForce false;             
      };                                                   
      services.resolved.enable = true;

      services.mealie = {
        enable = true;
        port = 9000;
      };

    };                                                   
  };
}
