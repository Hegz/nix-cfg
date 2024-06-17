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
      freecad
      gimp-with-plugins
      git
      google-chrome
      inkscape-with-extensions
      kate
      libsForQt5.kdeconnect-kde
      libreoffice-fresh
      libsForQt5.ark
      libsForQt5.bluedevil
      libsForQt5.gwenview
      libsForQt5.kalk
      libsForQt5.okular
      libsForQt5.yakuake
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
