{ config, pkgs, ... }:
let
  unstable = import
  (builtins.fetchTarball {
      url = "https://github.com/NixOS/nixpkgs/tarball/ecda1d8e2b265b48646a851e279442873d76616f";
      # 3807ab24077dd827482cc76c2a0d598e12578119 -- September 13, 2023. 
      # 3919f9de265b354aa9dc92316dce8ad75b89140a -- Nov 1 , 2023. 
      # ecda1d8e2b265b48646a851e279442873d76616f -- Jan 17, 2024 
      sha256 = "sha256:02w01jggis42hi1mw266mshfhglhzha74np9krpy23wwdrlp0iwg";
    })
    { config = config.nixpkgs.config; };
in
{
  environment.systemPackages = with pkgs; [
    unstable.keybase
    unstable.keybase-gui
  ];
}
