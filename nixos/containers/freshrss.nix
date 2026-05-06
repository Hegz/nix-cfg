{serverName}: { fetchFromGitHub, inputs, outputs, config, pkgs, lib, secrets, ... }:
let
  hostname    = "freshrss";
  servicePort = "80";
  domain      = secrets.tailnet.domain;
in
{
  containers."${hostname}" = {
    autoStart = true;
    privateNetwork = true;
    hostBridge = "br0";

    bindMounts = {
      "/var/lib/freshrss" = {
        hostPath   = "/home/container/${hostname}";
        isReadOnly = false;
      };
      "/var/lib/caddy" = {
        hostPath   = "/home/container/${hostname}/ssl";
        isReadOnly = false;
      };
    };

    config = {config, pkgs, lib, ... }: {
      system.stateVersion = "24.05";

      imports = [
        ../../modules/container-tailscale.nix
      ];

      networking = {
        hostName = "${hostname}";
        networkmanager.enable = true;
        networkmanager.ethernet.macAddress = "${secrets.${serverName}.containers.${hostname}.mac}";
        firewall = {
          enable = false;
        };
        useHostResolvConf = lib.mkForce false;
      };
      services.resolved.enable = true;

      services.freshrss = {
        enable = true;
        webserver = "caddy";
        virtualHost = "freshrss.${domain}";
        baseUrl    = "https://freshrss.${domain}";
        passwordFile = "/var/lib/freshrss/password";

        # OIDC via Kanidm.
        # FreshRSS reads these at startup; store the secret outside the Nix store.
        # Add to /home/container/freshrss/oidc.env on the host:
        #   OIDC_CLIENT_SECRET=<kanidm system oauth2 show-basic-secret freshrss>
        # then reference it from the FreshRSS environment:
        config = {
          OIDC_ENABLED           = "1";
          OIDC_PROVIDER_METADATA_URL = "https://kanidm.${domain}/oauth2/openid/freshrss/.well-known/openid-configuration";
          OIDC_CLIENT_ID         = "freshrss";
          # Client secret is injected via environment — see environmentFile below.
          OIDC_REMOTE_USER_CLAIM = "preferred_username";
          OIDC_SCOPES            = "openid email profile";
          OIDC_X_FORWARDED_HEADERS = "X-Forwarded-Host X-Forwarded-Port X-Forwarded-Proto";
        };

        extensions = with pkgs.freshrss-extensions; [
          youtube
        ] ++ [
          (pkgs.freshrss-extensions.buildFreshRssExtension {
            FreshRssExtUniqueId = "af-Readability";
            pname   = "af-readability";
            version = "1.0";
            src = pkgs.fetchFromGitHub {
              owner = "Niehztog";
              repo  = "freshrss-af-readability";
              rev   = "d1b8ff0c9ea98c5705b06dd2a6339af89f441193";
              hash  = "sha256-9/AELLkWwSkYiTBl9t7yVtlsnF+dZRccNbo2nr2ga7w=";
            };
          })
        ];
      };

      # Inject the OIDC client secret via an environment file kept off the
      # Nix store.  Create /home/container/freshrss/oidc.env on the host with:
      #   OIDC_CLIENT_SECRET=<secret>
      systemd.services.freshrss-config.serviceConfig.EnvironmentFile =
        lib.mkIf (builtins.pathExists "/var/lib/freshrss/oidc.env")
          "/var/lib/freshrss/oidc.env";
    };
  };
}
