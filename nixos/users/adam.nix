{ inputs, outputs, lib, config, pkgs, ... }:
{
  users.users.adam = {
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "Adam Fairbrother";
    extraGroups = [ "networkmanager" "wheel" "video" "docker" ];
    packages = with pkgs; [
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
      libsForQt5.ark
      libsForQt5.gwenview
      libsForQt5.kalk
      libsForQt5.okular
      libsForQt5.yakuake
      openscad
      playonlinux
      steam
      tenacity
      transmission-qt
      wine
      x2goclient
      xclip
      nvtop
    ];
  };
}
