{ inputs, outputs, lib, config, pkgs, ... }:
{
  # You can import other home-manager modules here
  imports = [
      ./git.nix
      ./ssh.nix
      ./tmux.nix
      ./vim.nix
      ./zsh.nix
      ./home.nix
  ];

  home = {
    username = "adam";
    homeDirectory = "/home/adam";
  };

}
