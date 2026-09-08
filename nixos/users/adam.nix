{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  secrets,
  ...
}: {
  users.users.adam = {
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "${secrets.users.adam.fullname}";
    hashedPassword = "${secrets.users.adam.passhash}";
    extraGroups = [
      "adbusers"
      "dialout"
      "distrobox"
      "docker"
      "gamemode"
      "kvm"
      "networkmanager"
      "plugdev"
      "video"
      "wheel"
      "audio" #Rocksmith
      "rtkit" #Rocksmith
    ];
    packages = with pkgs; [
      chromium
      esphome
      firefox
      gimp-with-plugins
      git
      inkscape-with-extensions
      kdePackages.ark
      kdePackages.gwenview
      kdePackages.kalk
      kdePackages.kate
      kdePackages.kdeconnect-kde
      kdePackages.okular
      kdePackages.yakuake
      libreoffice-fresh
      nvtopPackages.full
      openscad
      pkgs.cura
      pkgs.unstable.opencode
      #playonlinux
      prismlauncher
      #steam
      tenacity
      transmission_4-qt
      vinegar
      vlc
      wine
      x2goclient
      xclip
    ];
  };

home-manager.users.adam = {
  imports = [ ../../home-manager/adam.nix ];
  home.stateVersion = "23.05";
};
home-manager.extraSpecialArgs = { inherit inputs outputs secrets; };

  # Revert firefox to using xwayland.  Something going on with text display.
  environment.sessionVariables.MOZ_ENABLE_WAYLAND = "0";

  xdg.portal = {
    enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-gtk]; # or xdg-desktop-portal-kde
  };
}
