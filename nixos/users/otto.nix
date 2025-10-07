{ inputs, outputs, lib, config, pkgs, secrets, ... }:
let
  username = "otto";
in
{
  users.users.${username} = {
    shell = pkgs.zsh;
    isSystemUser = true;
    description = "${secrets.users.${username}.fullname}";
    hashedPassword = "${secrets.users.${username}.passhash}";
  };
}
