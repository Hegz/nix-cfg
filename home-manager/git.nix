{ inputs, outputs, lib, config, pkgs, ... }:                                                                       
# Git options                                                                                             
{ 
  programs.git = {           
    enable = true;   
    settings = {
      user = { 
        name = "Adam Fairbrother";
        email = "adam.fairbrother@gmail.com";
      };
    };
  };
}
