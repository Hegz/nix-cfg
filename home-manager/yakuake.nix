{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}:
# yakuake options
{
  imports = [
    # yakuake pulls options from konsole, bring that along.
    ./konsole.nix
  ];

  xdg.configFile."yakuake".text = ''
    [Desktop Entry]
    DefaultProfile=yakuake.profile

    [Dialogs]
    FirstRun=false

    [Window]
    Height=100
    ShowTabBar=false
    ShowTitleBar=false
    Width=100
  '';
}
