{serverName}: { inputs, outputs, config, pkgs, lib, secrets, ... }:
let
  hostname = "transmission";
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
      "/var/lib/private/downloads" = {                               
        hostPath = "/home/media/";
        isReadOnly = false;                                
      };
      "/var/lib/private/incomplete" = {                               
        hostPath = "/home/media/.incomplete";
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
          allowedTCPPorts = [ 3000 ];
          allowedUDPPorts = [ 53 ];
        };                           
        # Use systemd-resolved inside the container 
        # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
        useHostResolvConf = lib.mkForce false;             
      };                                                   
      services.resolved.enable = true;

      # Add service definitions here.
      services.transmission = {                                                                                        
        enable = true;                                                                                                 
        openRPCPort = true;
        openPeerPorts = true;
        settings = { 
          download-dir = "/var/lib/private/downloads";                                                                     
          incomplete-dir = "/var/lib/private/incomplete"; 
        };          
      };

    };                                                   
  };
}
