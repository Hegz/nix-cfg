{ inputs, outputs, config, pkgs, lib, ... }:
let
  hostname = "adGuard";
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
        # networkmanager.ethernet.macAddress = "00:11:22:33:44:55";
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

      services.adguardhome = { 
        enable = true;
        allowDHCP = false;
        # port = 3000;           
        # host = "0.0.0.0"; 
        # openFirewall = true;
        mutableSettings = true;
        #settings = {};
      };
    };                                                   
  };
}
