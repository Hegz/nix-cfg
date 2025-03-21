{ inputs, outputs, lib, config, pkgs, ... }:
{
  users.users.adam = {
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "Adam Fairbrother";
    extraGroups = [ 
                    "distrobox" 
                    "docker" 
                    "gamemode"
                    "networkmanager" 
                    "plugdev" 
                    "video" 
                    "wheel" 
                    "libvirtd"
                  ];
    packages = with pkgs; [
	git
      ];
  };
}
