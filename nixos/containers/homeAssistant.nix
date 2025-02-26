{ inputs, outputs, config, pkgs, lib, secrets, ... }:
let
  hostname = "homeAssistant";
in
{
  containers."${hostname}" = {                                                                                              
    autoStart = true;                                      
	privateNetwork = true;
    hostBridge = "br0";

    # Filesystem mount points
    bindMounts = {                                         
      "/var/lib/private" = {                               
        hostPath = "/home/containers/${hostname}";
        isReadOnly = false;                                
      };                                                   
    };

    config = {config, pkgs, lib, ... }: {          
      system.stateVersion = "24.05";

      networking = {                                   
        hostName = "${hostname}";
        networkmanager.enable = true;
        networkmanager.ethernet.macAddress = "${secrets.containers.${hostname}.macAddress}";
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
      services.home-assistant = {                                                                                      
        enable = true;                                                                                                 
        config = {                                                                                                      
          homeAssistant = {                                                                                             
            externalUrl = "https://${hostname}.local";                                                                   
            internalUrl = "http://localhost:8123";                                                                       
            ssl = true;                                                                                                  
            certfile = "/var/lib/private/ssl/fullchain.pem";                                                             
            keyfile = "/var/lib/private/ssl/privkey.pem";                                                                
          };                                                                                                            
        };                                                                                                              
      };

    };                                                   
  };
}
