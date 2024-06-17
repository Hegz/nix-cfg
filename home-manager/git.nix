{ inputs, outputs, lib, config, pkgs, ... }:                                                                       
# Git options                                                                                             
{ 
  programs.git = {           
    enable = true;   
    userName = "Adam Fairbrother";
    userEmail = "adam.fairbrother@gmail.com";
  };
}
