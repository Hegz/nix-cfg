{serverName}: { inputs, outputs, config, pkgs, lib, secrets, ... }:
let
  hostname = "mealie";
  private = "/var/lib/private/${hostname}";
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
      "/var/lib/caddy" = {
        hostPath = "/home/container/${hostname}/ssl";
        isReadOnly = false;
      };      
    };

    config = {config, pkgs, lib, ... }: {          
      system.stateVersion = "24.05";
		
      # Enable access for actual to bind to port 80
      boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 0;

      imports = [
        ../../modules/container-ssl.nix
      ];

      networking = {                                   
        hostName = "${hostname}";
        networkmanager.enable = true;
        networkmanager.ethernet.macAddress = "${secrets.${serverName}.containers.${hostname}.mac}";
        firewall = {                                                                                                  
          allowedTCPPorts = [ 80 443 ];
          enable = true;                                   
        };                           
        # Use systemd-resolved inside the container 
        # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
        useHostResolvConf = lib.mkForce false;             
      };                                                   
      services.resolved.enable = true;

      services.mealie = {
        enable = true;
        port = 9000;
      };

      # Enable tailscale
      services.tailscale = {
        enable = true;
        interfaceName = "userspace-networking";
      };
    };                                                   
  };
}
