{ inputs, outputs, lib, config, pkgs, ... }:
# ssh options
{
  services.ssh-agent.enable = true;
  programs.ssh ={
    enable = true;
    addKeysToAgent = "yes";
    forwardAgent = true;
    matchBlocks = { 
      "github.com" = {
        identityFile = "~/.ssh/github";
        user = "git";
      };
    };  
  };
}
