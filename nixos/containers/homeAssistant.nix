{serverName}: { inputs, outputs, config, pkgs, lib, secrets, ... }:
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
      "/var/lib/hass" = {                               
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
          allowedTCPPorts = [ 8123 ];
        };                           
        # Use systemd-resolved inside the container 
        # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
        useHostResolvConf = lib.mkForce false;             
      };                                                   
      services.resolved.enable = true;

      # Add service definitions here.
      services.home-assistant = {                                                                                      
        enable = true;                                                                                                 
        configWritable = true;
        openFirewall = true;
        lovelaceConfigWritable = true;
        config = {
          lovelace.mode = "storage";
          http = {
            server_port = 8123;
            server_host = "0.0.0.0";
          };
          homeassistant = {
            unit_system = "metric";
            time_zone = "${secrets.${serverName}.containers.${hostname}.tz}";
            temperature_unit = "C";
            name = "Home";
            longitude = secrets.${serverName}.containers.${hostname}.lat;
            latitude = secrets.${serverName}.containers.${hostname}.long;
          };
        };
      };

    };                                                   
  };
}
