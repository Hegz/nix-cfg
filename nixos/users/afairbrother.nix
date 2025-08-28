{ inputs, outputs, config, pkgs, lib, secrets, ... }:
{
  users.users.afairbrother = {
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "${secrets.users.adam.fullname}";
    hashedPassword = "${secrets.users.afairbrother.passhash}";
    extraGroups = [ "_lldpd" "plugdev" "networkmanager" "wheel" "distrobox" "docker" "dialout" ];
    packages = with pkgs; [
      chromium
      firefox
      gam
      gimp-with-plugins
      git
      google-chrome
      inkscape-with-extensions
      kdePackages.kate
      kdePackages.kdeconnect-kde
      libreoffice-fresh
      kdePackages.ark
      kdePackages.gwenview
      kdePackages.kalk
      kdePackages.okular
      kdePackages.yakuake
      pkgs.cura
      orca-slicer
      lldpd
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
      uni2ascii 
      file
      vlc
    ];
  };
}
