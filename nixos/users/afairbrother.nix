{ inputs, outputs, config, pkgs, lib, ... }:
{
  users.users.afairbrother = {
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "Adam Fairbrother";
    extraGroups = [ "plugdev" "networkmanager" "wheel" "distrobox" "docker" ];
    packages = with pkgs; [
      chromium
      firefox
      #freecad
      gam
      gimp-with-plugins
      git
      google-chrome
      inkscape-with-extensions
      kate
      kdePackages.kdeconnect-kde
      libreoffice-fresh
      kdePackages.ark
      kdePackages.gwenview
      kdePackages.kalk
      kdePackages.okular
      kdePackages.yakuake
      pkgs.cura
      pkgs.freecad
      pkgs.s3drive
      playonlinux
      quickemu
      tenacity
      tigervnc
      x2goclient
      xclip
      usbimager
      teams-for-linux
      scrcpy
      steam
    ];
  };
}
