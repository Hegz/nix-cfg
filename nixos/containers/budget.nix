{serverName}: { inputs, outputs, config, pkgs, lib, secrets, ... }:
let
  hostname = "budget";
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

      imports =
        [ # Importing Actual budget server from unstable
        <nixos-unstable/nixos/modules/services/web-apps/actual.nix>
        ];

      networking = {                                   
        hostName = "${hostname}";
        networkmanager.enable = true;
        # networkmanager.ethernet.macAddress = "${secrets.${serverName}.containers.${hostname}.mac}";
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
      services.actual = {
        enable = true;
        openFirewall = true;
        settings.port = 80;
      };

    };                                                   
  };
}
