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
      set-option -g allow-rename on
      set-option -g automatic-rename on
      set-option -g automatic-rename-format '#{b:pane_current_path}'
      set-option -g status-interval 1

    '';
  };
}
