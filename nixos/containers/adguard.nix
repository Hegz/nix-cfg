{ inputs, outputs, config, pkgs, lib, ... }:
{

  containers.adGuard = {                                                                                              
    autoStart = true;                                      
	privateNetwork = true;
    hostBridge = "br0";
    config = {config, pkgs, lib, ... }: {          
      system.stateVersion = "24.05";                 
          networking = {                                   
            hostName = "adguard";
            networkmanager.enable = true;
            firewall = {                                                                                                  
              enable = true;                                   
              allowedTCPPorts = [ 80 ];
            };                           
            # Use systemd-resolved inside the container 
            # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
            useHostResolvConf = lib.mkForce false;             
          };                                                   
        services.resolved.enable = true;                                                                            
      };                                                     
  };

}
