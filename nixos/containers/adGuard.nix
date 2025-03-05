{serverName}: { inputs, outputs, config, pkgs, lib, secrets, ... }:
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
        hostPath = "/home/container/${hostname}";
        isReadOnly = false;                                
      };                                                   
    };

    config = {config, pkgs, lib, ... }: {          
      system.stateVersion = "24.05";

      networking = {                                   
        hostName = "${hostname}";
        networkmanager.enable = true;
        #networkmanager.ethernet.macAddress = "${secrets.${config.networking.hostName}.containers.${hostname}.mac}";
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

      services.adguardhome = { 
        enable = true;
        allowDHCP = false;
        # port = 80;           
        # host = "0.0.0.0"; 
        # openFirewall = true;
        mutableSettings = true;
        # settings = {};
      };
    };                                                   
  };
}
