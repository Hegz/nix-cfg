{ inputs, outputs, lib, config, pkgs, ... }:
{
  users.users.adam = {
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "Adam Fairbrother";
    extraGroups = [ "plugdev" "video" "networkmanager" "wheel" "distrobox" "docker" ];
    packag = with pkgs; [
      pkgs.cura
      pkgs.lychee
      chromium
      esphome
      firefox
      freecad
      gimp-with-plugins
      git
      inkscape-with-extensions
      kate
      kdePackages.kdeconnect-kde
      libreoffice-fresh
      kdePackages.ark
      kdePackages.gwenview
      kdePackages.kalk
      kdePackages.okular
      kdePackages.yakuake
      openscad
      playonlinux
      steam
      tenacity
      transmission-qt
      wine
      x2goclient
      xclip
      nvtopPackages.full
    ];
  };
}
