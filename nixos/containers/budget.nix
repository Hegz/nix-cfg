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
		
      # Enable access for actual to bind to port 80
      boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 0;

	  # Bring actual in from unstable
      #imports =
      #  [ # Importing Actual budget server from unstable
      #  "${inputs.nixpkgs-unstable}/nixos/modules/services/web-apps/actual.nix"
      #  ];

      #nixpkgs.overlays = [
      #  outputs.overlays.unstable-packages
      #  (new: prev: { mtr-exporter = pkgs.unstable.pkgs.actual; })
      #];

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

      # Add service definitions here.
      services.actual = {
        enable = true;
        openFirewall = true;
        settings = {
          port = 443;
          https = {
            key = "/var/lib/private/actual/budget.taild7a71.ts.net.key";
            cert = "/var/lib/private/actual/budget.taild7a71.ts.net.crt";
          };
        };

      };

      # Enable tailscale
      services.tailscale = {
        enable = true;
        interfaceName = "userspace-networking";
      };

    };                                                   
  };
}
