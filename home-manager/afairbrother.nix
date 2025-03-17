{ inputs, outputs, lib, config, pkgs, ... }:
{
  # You can import other home-manager modules here
  imports = [
      ./git.nix
      ../secrets/ssh-hosts.nix 
      ./ssh.nix
      ./tmux.nix
      ./vim.nix
      ./zsh.nix
      ./home.nix
      ./firefox.nix
      #inputs.nur.hmModules.nur
  ];

  home = {
    username = "afairbrother";
    homeDirectory = "/home/afairbrother";
  };

}
