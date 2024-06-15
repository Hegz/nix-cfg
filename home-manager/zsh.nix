{ inputs, outputs, lib, config, pkgs, ... }:
# Zsh configuration  options
{
  programs.zsh = {
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
}
