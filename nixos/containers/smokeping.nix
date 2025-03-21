{serverName}: { inputs, outputs, config, pkgs, lib, secrets, ... }:
let
  hostname = "smokeping";
in
{
  containers."${hostname}" = {                                                                                              
    autoStart = true;                                      
	privateNetwork = true;
    hostBridge = "br0";

    # Filesystem mount points
    #bindMounts = {                                         
    #  "/var/lib/private" = {                               
    #    hostPath = "/home/containers/${hostname}";
    #    isReadOnly = false;                                
    #  };                                                   
    #};

    config = {config, pkgs, lib, ... }: {          
      system.stateVersion = "24.05";

      networking = {                                   
        hostName = "${hostname}";
        networkmanager.enable = true;
        #networkmanager.ethernet.macAddress = "${secrets.${serverName}.containers.${hostname}.mac}";
        firewall = {                                                                                                  
          enable = false;                                   
          #allowedTCPPorts = [ 3000 ];
          #allowedUDPPorts = [ 53 ];
        };                           
        # Use systemd-resolved inside the container 
        # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
        useHostResolvConf = lib.mkForce false;             
      };                                                   
      services.resolved.enable = true;

      # Add service definitions here.
      services.smokeping = {
        enable = true;
        targetConfig = ''
		  probe = FPing
		  menu = Top
		  title = Network Latency Grapher
		  remark = Welcome to the SmokePing website of xxx Company. \
				   Here you will learn all about the latency of our network.
		  + Local
		  menu = Local
		  title = Local Network
		  ++ LocalMachine
		  menu = Local Machine
		  title = This host
		  host = localhost
		  ++ LocalRouter
		  menu = Local Router
		  title = Local Router
          host = 192.168.1.1
		  ++ LocalServer
		  menu = Local Server (secunit)
		  title = Secunit
		  host = 192.168.1.13
          + Remote
		  menu = WAN
		  title = Remote targets
          ++ upstream
		  menu = upstream
		  title = upstream host
		  host = 10.31.226.1
          ++ one
		  menu = Cloudflare DNS
		  title = cloudflare 1.1.1.1
		  host = 1.1.1.1
		''
      };

    };                                                   
  };
}
