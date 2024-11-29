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
                  ];
    packages = with pkgs; [
      chromium
      esphome
      firefox
      gimp-with-plugins
      git
      inkscape-with-extensions
      kate
      kdePackages.ark
      kdePackages.gwenview
      kdePackages.kalk
      kdePackages.kdeconnect-kde
      kdePackages.okular
      kdePackages.yakuake
      libreoffice-fresh
      nvtopPackages.full
      openscad
      pkgs.cura
      playonlinux
      steam
      tenacity
      transmission-qt
      wine
      x2goclient
      xclip
    ];
  };
}
