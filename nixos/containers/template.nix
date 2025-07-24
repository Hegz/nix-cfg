{serverName}: { inputs, outputs, config, pkgs, lib, secrets, ... }:
let
  hostname = "template";
  sslPath = "/var/lib/${hostname}/ssl/";
  tailName = "taild7a71.ts.net";
  
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
        # networkmanager.ethernet.macAddress = "${secrets.${serverName}.containers.${hostname}.mac}";
        firewall = {                                                                                                  
          enable = true;                                   
          #allowedTCPPorts = [ 3000 ];
          #allowedUDPPorts = [ 53 ];
        };                           
        # Use systemd-resolved inside the container 
        # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
        useHostResolvConf = lib.mkForce false;             
      };                                                   
      services.resolved.enable = true;

      ## Enable tailscale
      #services.tailscale = {
      #  enable = true;
      #  interfaceName = "userspace-networking";
      #};
      
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
      #    cd ${sslPath}
      #    ${pkgs.tailscale}/bin/tailscale cert ${hostname}.${tailName}
      #    ${pkgs.coreutils}/bin/chown -R nginx:nginx ${sslPath}${hostname}.${tailName}.*
      #    ${pkgs.systemd}/bin/systemctl reload nginx.service
      #  '';
      #  serviceConfig = {
      #    Type = "oneshot";
      #    User = "root";
      #  };
      #};



      # Add service definitions here.

    };                                                   
  };
}
