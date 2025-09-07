{serverName}: { inputs, outputs, config, pkgs, lib, secrets, ... }:
let
  hostname = "mealie";
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

      # Enable unstable packages
      # nixpkgs.overlays = [
      #   outputs.overlays.unstable-packages
      # ];

      networking = {                                   
        hostName = "${hostname}";
        networkmanager.enable = true;
        networkmanager.ethernet.macAddress = "${secrets.${serverName}.containers.${hostname}.mac}";
        firewall = {                                                                                                  
          allowedTCPPorts = [ 80 ];
          enable = true;                                   
        };                           
        # Use systemd-resolved inside the container 
        # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
        useHostResolvConf = lib.mkForce false;             
      };                                                   
      services.resolved.enable = true;

      #systemd.timers."ssl-refresh" = {
      #  wantedBy = ["timers.target"];
      #  timerConfig = {
      #    OnCalendar = "quarterly";
      #    Persistent = true;
      #    Unit = "ssl-refresh.service";
      #  };
      #};

      #systemd.services."ssl-refresh" = {
      #  script = ''
      #    set -eu
      #    cd /var/lib/private/actual/
      #    ${pkgs.tailscale}/bin/tailscale cert budget.taild7a71.ts.net
      #    ${pkgs.coreutils}/bin/chown -R actual /var/lib/private/actual/budget.taild7a71.ts.net.*
      #    ${pkgs.systemd}/bin/systemctl restart actual.service
      #  '';
      #  serviceConfig = {
      #    Type = "oneshot";
      #    User = "root";
      #  };
      #};

      # Add service definitions here.
      services.mealie = {
        enable = true;
        port = 80;
        #database.createLocally = true;
        #openFirewall = true;
        
      };

      # Enable tailscale
      # services.tailscale = {
      #  enable = true;
      #  interfaceName = "userspace-networking";
      # };

    };                                                   
  };
}
