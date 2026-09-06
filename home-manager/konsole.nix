{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}:
# konsole options
{
  home.file.".local/share/konsole/yakuake.profile".text = ''
    [Appearance]
    ColorScheme=GreenOnBlack
    WordMode=false

    [General]
    Command=/etc/profiles/per-user/adam/bin/tmux
    Name=Yakuake Fullscreen
    Parent=FALLBACK/
    TerminalCenter=true
    TerminalColumns=130
  '';
}
