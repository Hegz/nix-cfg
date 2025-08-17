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
                    "dialout"
                    "wheel" 
                  ];
    packages = with pkgs; [
      chromium
      esphome
      firefox
      gimp-with-plugins
      git
      inkscape-with-extensions
      kdePackages.kate
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
      prismlauncher
    ];
  };
}
