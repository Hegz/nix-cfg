{ inputs, outputs, lib, config, pkgs, ... }:
# ssh options
{
  programs.ssh ={
    enable = true;
    extraConfig = ''
      AddKeysToAgent yes
    '';
    forwardAgent = true;
    matchBlocks = { 
      "github.com" = {
        identityFile = "~/.ssh/github";
        user = "git";
      };
    };  
  };
}
