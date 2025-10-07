{ inputs, outputs, lib, config, pkgs, secrets, ... }:
let
  username = "otto";
in
{
  users.users.${username} = {
    isNormalUser = true;
    description = "${secrets.users.${username}.fullname}";
    openssh.authorizedKeys.keys = [
      ];
  };
}
