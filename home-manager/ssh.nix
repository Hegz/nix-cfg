{ inputs, outputs, lib, config, pkgs, ... }:
# ssh options
{
  services.ssh-agent.enable = true;
  programs.ssh ={
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = { 
      "*" = {
        addKeysToAgent = "yes";
        forwardAgent = false;
      };
      "github.com" = {
        identityFile = "~/.ssh/github";
        user = "git";
      };
    };  
  };
}
