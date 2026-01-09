{serverName}: { fetchFromGitHub, inputs, outputs, config, pkgs, lib, secrets, ... }:
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
        extensions = with pkgs.freshrss-extensions; [
            youtube
           ] ++ [
              (pkgs.freshrss-extensions.buildFreshRssExtension {
                FreshRssExtUniqueId = "af-Readability";
                pname = "af-readability";
                version = "1.0";
                src = pkgs.fetchFromGitHub {
                  owner = "Niehztog";
                  repo = "freshrss-af-readability";
                  rev = "d1b8ff0c9ea98c5705b06dd2a6339af89f441193";
                  hash = "sha256-9/AELLkWwSkYiTBl9t7yVtlsnF+dZRccNbo2nr2ga7w=";
                };
              })
          ];
      };
    };                                                   
  };
}
