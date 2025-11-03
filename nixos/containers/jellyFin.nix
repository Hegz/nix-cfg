{serverName}: { inputs, outputs, config, pkgs, lib, secrets, ... }:
let
  hostname = "jellyFin";
  servicePort = "8096";
in
{
  containers."${hostname}" = {                                                                                              
    autoStart = true;                                      
	privateNetwork = true;
    hostBridge = "br0";

    # Filesystem mount points
    bindMounts = {                                         
      "/var/lib/jellyfin" = {                               
        hostPath = "/home/container/${hostname}";
        isReadOnly = false;                                
      };                                                   
    };

    bindMounts = {                                         
      "/media" = {                               
        hostPath = "/home/media";
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

      # Add service definitions here.
      services.jellyfin = {                                                                                             
        enable = true;                                                                                                  
        openFirewall = true;
      };
        environment.systemPackages = [
          pkgs.jellyfin
          pkgs.jellyfin-web
          pkgs.jellyfin-ffmpeg
        ];

    };                                                   
  };
}
