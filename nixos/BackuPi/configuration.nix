{ inputs, outputs, lib, config, pkgs, secrets, ... }:

let
  hostName      = "BackuPi";
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../users/adam-blank.nix
    ];

  boot = { 
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
    supportedFilesystems = [ "zfs" "nfs" ];
  };

  networking = {
    hostName = "${hostName}";
    hostId = "${secrets.${hostName}.hostId}";
    networkmanager.enable = true;
  };

  services.tailscale.enable = true;

  # Set your time zone.
  time.timeZone = "America/Vancouver";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_CA.UTF-8";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];


  # Compensate for lack of ram
  zramSwap.enable = true;

  # add a swapfile to compensate for low ram.
  swapDevices = [{
    device = "/var/lib/swapfile";
    size = 8*1024; # 8 GB
  }];

  programs.zsh.enable = true;

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    git
    git-crypt
  ];

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  system.stateVersion = "25.05"; # Did you read the comment?

}

