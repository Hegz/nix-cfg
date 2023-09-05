{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "adam";
  home.homeDirectory = "/home/adam";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "23.05"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # pkgs.hello

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {

    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # You can also manage environment variables but you will have to manually
  # source
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/afairbrother/etc/profile.d/hm-session-vars.sh
  #
  # if you don't want to manage your shell through Home Manager.
  home.sessionVariables = {
    # EDITOR = "vim";
  };

  programs = {
    git = {
      enable = true;
      userName = "Adam Fairbrother";
      userEmail = "adam.fairbrother@gmail.com";
    };
    tmux ={
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
    ssh ={
      enable = true;
      extraConfig = ''
        AddKeysToAgent yes
      '';
      forwardAgent = true;
      matchBlocks = { 
        "github.com" = {
          identityFile = "~/.ssh/github";
          user = "git";
        };
      };
    };
    vim = {
      enable = true;
      defaultEditor = true;
      extraConfig = ''
        set nocompatible
        filetype plugin indent on
        syntax on
        noremap <space> za
        set foldmethod=indent
        set foldlevel=99
        if has("autocmd")
          autocmd BufReadPost * if line("'\"") > 0 && line ("'\"") <= line("$") | exe "normal g'\"" | endif
        endif
                    '';
      # plugins = [ pkgs.vimPlugins.syntastic ];
      settings = {
        background = "dark";
        copyindent = true;
        number = true;
        shiftwidth = 4;
        tabstop = 4;
      };
    };
    zsh = {
      enable = true;
      enableCompletion = true;
      oh-my-zsh = {
        enable = true;
        theme = "risto";
        plugins = [ "sudo" "common-aliases" "mosh" "ssh-agent" ];
        extraConfig = ''
          zstyle :omz:plugins:ssh-agent agent-forwarding yes
          zstyle :omz:plugins:ssh-agent lazy yes
        '';
      };
    };
  };
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
