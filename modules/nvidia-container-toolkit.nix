{ pkgs, lib, ... }:
{
  virtualisation.containers.enable = true;

  virtualisation.podman = {
    enable = true;

    # Create a `docker` alias for podman, to use it as a drop-in replacement
    dockerCompat = true;

    # Required for containers under podman-compose to be able to talk to each other
    defaultNetwork.settings.dns_enabled = true;
  };

  hardware.nvidia-container-toolkit = {
    enable = true;

    extraArgs = [
      "--disable-hook"
      "create-symlinks"
    ];

    package = pkgs.nvidia-container-toolkit.overrideAttrs (old: {
      version = "git";
      src = pkgs.fetchFromGitHub {
        owner = "nvidia";
        repo = "nvidia-container-toolkit";
        rev = "08b3a388e7b1d447e10d4c4d4a71dca29a98a964"; # v1.18.0-rc.2
        hash = "sha256-y81UbNoMfIhl9Rf1H3RTRmGR3pysDtKlApLrIxwou9I=";
      };
      postPatch = ''
        substituteInPlace internal/config/config.go \
          --replace-fail '/usr/bin/nvidia-container-runtime-hook' "$tools/bin/nvidia-container-runtime-hook" \
          --replace-fail '/sbin/ldconfig' '${pkgs.glibc.bin}/sbin/ldconfig'

        # substituteInPlace tools/container/toolkit/toolkit.go \
        #   --replace-fail '/sbin/ldconfig' '${pkgs.glibc.bin}/sbin/ldconfig'

        substituteInPlace cmd/nvidia-cdi-hook/update-ldcache/update-ldcache.go \
          --replace-fail '/sbin/ldconfig' '${pkgs.glibc.bin}/sbin/ldconfig'
      '';
    });
  };

  environment.systemPackages = with pkgs; [
    podman-compose
  ];
}
