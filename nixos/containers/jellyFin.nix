{serverName}: { inputs, outputs, config, pkgs, lib, secrets, ... }:
let
  hostname = "jellyfin";
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
      services.jellyfin = {                                                                                             
        enable = true;                                                                                                  
        port = 3000;                                                                                                    
        bind = "";
        extraConfig = ''
          Restart=always
          [Service]
          Restart=always
          RestartSec=5
        '';
      };

    };                                                   
  };
}
