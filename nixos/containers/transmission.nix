{serverName}: { inputs, outputs, config, pkgs, lib, secrets, ... }:
let
  hostname = "transmission";
  mac = "${secrets.${serverName}.containers.${hostname}.mac}";
in
{
  containers."${hostname}" = {                                                                                              
    autoStart = true;                                      
	privateNetwork = true;
    hostBridge = "br0";
    specialArgs =  {secret = secrets; };

    # Filesystem mount points
    bindMounts = {                                         
      "/var/lib/transmission" = {                               
        hostPath = "/home/container/${hostname}";
        isReadOnly = false;                                
      };                                                   
      "/var/lib/transmission/Downloads" = {                               
        hostPath = "/home/media/Downloads";
        isReadOnly = false;                                
      };
      "/var/lib/transmission/.incomplete" = {                               
        hostPath = "/home/media/Downloads/.incomplete";
        isReadOnly = false;                                
      };

    };

    config = { config, pkgs, lib, ... }: {          
      system.stateVersion = "24.05";

      imports = [
         ../../modules/wireguard.nix
      ];

      networking = {                                   
        hostName = "${hostname}";
        networkmanager.enable = true;
        networkmanager.ethernet.macAddress = "${mac}";
        firewall = {                                                                                                  
          enable = true;                                   
        };                           
        # Use systemd-resolved inside the container 
        # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
        useHostResolvConf = lib.mkForce false;             
      };                                                   
      services.resolved.enable = true;

      # Fix for transmission failing to start 
      # https://github.com/NixOS/nixpkgs/issues/258793
	  systemd.services.transmission.serviceConfig = {
	    BindReadOnlyPaths = lib.mkForce [ builtins.storeDir "/etc" ];
        RootDirectoryStartOnly = lib.mkForce false;
        RootDirectory = lib.mkForce "";
      };

      # Add service definitions here.
      services.transmission = {                                                                                        
        enable = true;                                                                                                 
        openRPCPort = true;
        openPeerPorts = true;
        settings = { 
          rpc-host-whitelist = "${hostname}.fair";
          rpc-bind-address = "0.0.0.0";
          rpc-whitelist-enabled = false;
          download-dir = "/var/lib/transmission/Downloads";                                                                     
          incomplete-dir = "/var/lib/transmission/.incomplete"; 
          umask = 2;
        };          
      };
    };                                                   
  };
}
