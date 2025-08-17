{ inputs, outputs, lib, config, pkgs, ... }:
{
  users.users.gio = {
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "${secrets.users.gio.fullname}";
    hashedPassword = "${secrets.users.gio.passhash}";
    extraGroups = [ 
                    "gamemode"
                    "networkmanager" 
                    "plugdev" 
                    "video" 
                  ];
    packages = with pkgs; [
      chromium
      firefox
      gimp-with-plugins
      inkscape-with-extensions
      kdePackages.kate
      kdePackages.ark
      kdePackages.gwenview
      kdePackages.kalk
      kdePackages.okular
      libreoffice-fresh
      openscad
      pkgs.cura
      playonlinux
      steam
      tenacity
      wine
      xclip
      prismlauncher
      heroiclauncher
    ];
  };
}
