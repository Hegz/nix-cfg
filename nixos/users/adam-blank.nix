{ inputs, outputs, lib, config, pkgs, secrets, ... }:
{
  users.users.adam = {
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "${secrets.users.adam.fullname}";
    hashedPassword = "${secrets.users.adam.passhash}";
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
