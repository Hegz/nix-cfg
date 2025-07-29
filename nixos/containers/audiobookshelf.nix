{serverName}: { inputs, outputs, config, pkgs, lib, secrets, ... }:
let
  hostname = "audiobookshelf";
in
{
  containers."${hostname}" = {                                                                                              
    autoStart = true;                                      
	privateNetwork = true;
    hostBridge = "br0";

    # Filesystem mount points
    bindMounts = {                                         
      "/var/lib/${hostname}" = {                               
        hostPath = "/home/container/${hostname}";
        isReadOnly = false;                                
      };                                                   
      "/home/books" = {
        hostPath = "/home/media/Books";
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
        };                           
        # Use systemd-resolved inside the container 
        # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
        useHostResolvConf = lib.mkForce false;             
      };                                                   

      services.resolved.enable = true;

      # Add service definitions here.
     
      services.audiobookshelf = {
        enable = true;
        host = "0.0.0.0";
        openFirewall = true;
      };

      # Enable tailscale
      services.tailscale = {
        enable = true;
        interfaceName = "userspace-networking";
      };
    };                                                   
  };
}
