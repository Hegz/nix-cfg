{serverName}: { inputs, outputs, config, pkgs, lib, secrets, ... }:
let
  hostname = "minecraft";
in
{
  containers."${hostname}" = {                                                                                              
    autoStart = true;                                      
	privateNetwork = true;
    hostBridge = "br0";

    # Filesystem mount points
    bindMounts = {                                         
      "/var/lib/minecraft" = {                               
        hostPath = "/home/container/${hostname}";
        isReadOnly = false;                                
      };                                                   
    };

    config = {config, pkgs, lib, ... }: {          
      system.stateVersion = "24.05";

      # allow unfree minecraft
      nixpkgs.config.allowUnfree = true;

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
      services.minecraft-server = {
        enable = true;
        eula = true;
        openFirewall = true;
      };
    };                                                   
  };
}
