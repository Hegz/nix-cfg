{ inputs, outputs, lib, config, pkgs, ... }:
# Tmux config options
{
  programs.tmux ={
    baseIndex = 1;
    customPaneNavigationAndResize = true;
    enable = true;
    keyMode = "vi";
    mouse = false;
    prefix = "C-a";
    sensibleOnTop = true;
    extraConfig = ''
      # C-a C-a swap to last window
      bind-key C-a last-window

      # C-a a send C-a
      bind-key a send-prefix

      # Auto rename windows
      set-window-option -g automatic-rename
    '';
  };
}
