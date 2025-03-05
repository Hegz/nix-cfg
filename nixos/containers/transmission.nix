{serverName}: { inputs, outputs, config, pkgs, lib, secrets, ... }:
let
  hostname = "transmission";
in
{
  containers."${hostname}" = {                                                                                              
    autoStart = true;                                      
	privateNetwork = true;
    hostBridge = "br0";

    # Filesystem mount points
    bindMounts = {                                         
      "/var/lib/private" = {                               
        hostPath = "/home/containers/${hostname}";
        isReadOnly = false;                                
      };                                                   
    };

    config = {config, pkgs, lib, ... }: {          
      system.stateVersion = "24.05";

      networking = {                                   
        hostName = "${hostname}";
        networkmanager.enable = true;
        networkmanager.ethernet.macAddress = "${secrets.${serverName}.containers.${hostname}.mac}";
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
      services.transmission = {                                                                                        
        enable = true;                                                                                                 
        rpcEnabled = true;                                                                                              
        rpcPort = 3000;                                                                                                 
        rpcUsername = "${secrets.${serverName}.containers.${hostname}.rpcUsername}";                                                  
        rpcPassword = "${secrets.${serverName}.containers.${hostname}.rpcPassword}";                                                  
        downloadDir = "/var/lib/private/downloads";                                                                     
        incompleteDir = "/var/lib/private/incomplete";                                                                  
        watchDir = "/var/lib/private/watch";                                                                            
        watchDirEnabled = true;                                                                                         
        watchDirRecursive = true;                                                                                       
        watchDirAutoAdd = true;                                                                                         
        watchDirFilter = "*";                                                                                           
        watchDirCommand = "${pkgs.transmission-cli}/bin/transmission-remote -a";                                         
        watchDirCommandEnabled = true;                                                                                  
        watchDirCommandRecursive = true;                                                                                
        watchDirCommandFilter = "*";                                                                                    
        watchDirCommandInterval = 10;                                                                                   
        watchDirCommandRunOnAdd = true;                                                                                 
        watchDirCommandRunOnStart = true;                                                                               
        watchDirCommandRunOnFinish = true;                                                                              
        watchDirCommandRunOnVerify = true;                                                                              
        watchDirCommandRunOnDownload = true;                                                                            
        watchDirCommandRunOnDownloadStart = true;                                                                       
        watchDirCommandRunOnDownloadStop = true;                                                                        
        watchDirCommandRunOnDownloadComplete = true;                                                                    
        watchDirCommandRunOnDownloadVerify = true;                                                                      
        watchDirCommandRunOnDownloadError = true;                                                                       
        watchDirCommandRunOnDownloadPause = true;                                                                       
        watchDirCommandRunOnDownloadResume = true;                                                                      
        watchDirCommandRunOnDownloadRemove = true;                                                                      
        watchDirCommandRunOnDownloadStartNow = true;                                                                    
        watchDirCommandRunOnDownloadStopNow = true;                                                                     
        watchDirCommandRunOnDownloadCompleteNow = true;                                                                 
        watchDirCommandRunOnDownloadVerifyNow = true;                                                                   
        watchDirCommandRunOnDownloadErrorNow = true;                                                                    
        watchDirCommandRunOnDownloadPauseNow = true;                                                                   
        watchDirCommandRunOnDownloadResumeNow = true;                                                                  
        watchDirCommandRunOnDownloadRemoveNow = true;                                                                  
        watchDirCommandRunOnDownloadStartLater = true;                                                                 
      };

    };                                                   
  };
}
