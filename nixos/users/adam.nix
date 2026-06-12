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
      llm
      gorilla-cli
      nvtopPackages.full
      openscad
      pkgs.cura
      pkgs.unstable.opencode
      #playonlinux
      #prismlauncher
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
}
