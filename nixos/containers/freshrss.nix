{serverName}: { inputs, outputs, config, pkgs, lib, secrets, ... }:
let
  hostname    = "freshrss";
  servicePort = "80";
in
{
  containers."${hostname}" = {                                                                                              
    autoStart = true;                                      
	privateNetwork = true;
    hostBridge = "br0";

    # Filesystem mount points
    bindMounts = {                                         
      "/var/lib/freshrss" = {                               
        hostPath = "/home/container/${hostname}";
        isReadOnly = false;                                
      };                                                   
    # required for SSL
      "/var/lib/caddy" = {
        hostPath = "/home/container/${hostname}/ssl";
        isReadOnly = false;
      };  
    };

    config = {config, pkgs, lib, ... }: {          
      system.stateVersion = "24.05";

      imports = [
      #  (import ../../modules/container-ssl.nix {port = "${servicePort}";})
        ../../modules/container-tailscale.nix
	  #  ../../modules/wireguard.nix
	  ];

      # Enable unstable packages
      # nixpkgs.overlays = [
      #   outputs.overlays.unstable-packages
      # ];

      networking = {                                   
        hostName = "${hostname}";
        networkmanager.enable = true;
        networkmanager.ethernet.macAddress = "${secrets.${serverName}.containers.${hostname}.mac}";
        firewall = {                                                                                                  
      #    allowedTCPPorts = [ 80 443 ];
          enable = false;                                   
        };                           
        # Use systemd-resolved inside the container 
        # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
        useHostResolvConf = lib.mkForce false;             
      };                                                   
      services.resolved.enable = true;

      # Add service definitions here.
      services.freshrss = {
        enable = true;
        webserver = "caddy";
        virtualHost = "freshrss.taild7a71.ts.net";
        baseUrl = "https://freshrss.taild7a71.ts.net";
        passwordFile = "/var/lib/freshrss/password";
        extensions = with freshrss-extensions; [
            youtube
          ] ++ [
              (freshrss-extensions.buildFreshRssExtension {
                FreshRssExtUniqueId = "ReadingTime";
                pname = "reading-time";
                version = "1.5";
                src = pkgs.fetchFromGitLab {
                  domain = "framagit.org";
                  owner = "Lapineige";
                  repo = "FreshRSS_Extension-ReadingTime";
                  rev = "fb6e9e944ef6c5299fa56ffddbe04c41e5a34ebf";
                  hash = "sha256-C5cRfaphx4Qz2xg2z+v5qRji8WVSIpvzMbethTdSqsk=";
                };
              })
          ];
      };
    };                                                   
  };
}
