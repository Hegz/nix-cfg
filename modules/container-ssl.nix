# modules/container-ssl.nix
#
# Provides TLS termination via Caddy using Tailscale certificates, with an
# optional oauth2-proxy layer for OIDC authentication via Kanidm.
#
# Parameters:
#   port    - the port of the backend service (required)
#   secrets - the secrets attrset (required)
#   oauth   - optional attrset enabling SSO. When provided:
#               clientID  - the OAuth2 client ID registered in Kanidm (required)
#               skipPaths - list of path regexes to bypass auth (optional)
#
# Without oauth (existing behaviour — no changes needed in the container):
#   (import ../../modules/container-ssl.nix { port = "8096"; inherit secrets; })
#
# With oauth (Caddy → oauth2-proxy → backend):
#   (import ../../modules/container-ssl.nix {
#     port    = "9000";
#     inherit secrets;
#     oauth = {
#       clientID  = "mealie";
#       skipPaths = [ "^/api" ];   # optional
#     };
#   })
#
# Create /home/container/<name>/oidc.env on the HOST with:
#   OAUTH2_PROXY_CLIENT_SECRET=<kanidm system oauth2 show-basic-secret <clientID>>
#   OAUTH2_PROXY_COOKIE_SECRET=<openssl rand -base64 32 | tr -d '\n' | head -c 32>

{ port, secrets, oauth ? null }:
{ inputs, outputs, config, pkgs, lib, specialArgs, ... }:

let
  hostName   = config.networking.hostName;
  domain     = secrets.tailnet.domain;
  oauth2Port = 4180;

  caddyUpstream =
    if oauth != null
    then "http://localhost:${toString oauth2Port}"
    else "http://localhost:${port}";

  # Script run before oauth2-proxy starts that extracts the two secrets from
  # oidc.env into individual files that can be passed as --*-file flags.
  # This avoids CLI flags containing secrets in the Nix store, and works
  # around oauth2-proxy 7.x ignoring env vars when flags are already set.
  secretExtractScript = pkgs.writeShellScript "oauth2-proxy-extract-secrets" ''
    set -eu
    dir=/run/oauth2-proxy-secrets-${lib.toLower hostName}
    mkdir -p "$dir"
    chmod 700 "$dir"

    extract() {
      local key="$1" out="$2"
      grep "^''${key}=" /var/lib/${lib.toLower hostName}/oidc.env \
        | head -1 \
        | cut -d= -f2- \
        > "$dir/$out"
      chmod 400 "$dir/$out"
      chown oauth2-proxy "$dir/$out"
    }

    extract OAUTH2_PROXY_CLIENT_SECRET  client-secret
    extract OAUTH2_PROXY_COOKIE_SECRET  cookie-secret
  '';

in
{
  # ---------------------------------------------------------------------------
  # Tailscale certificate refresh (quarterly)
  # ---------------------------------------------------------------------------
  systemd.timers."ssl-refresh" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "quarterly";
      Persistent = true;
      Unit       = "ssl-refresh.service";
    };
  };

  systemd.services."ssl-refresh" = {
    script = ''
      set -eu
      cd /var/lib/caddy
      ${pkgs.tailscale}/bin/tailscale cert ${lib.toLower hostName}.${domain}
      ${pkgs.coreutils}/bin/chown caddy ${lib.toLower hostName}.${domain}.*
      ${pkgs.systemd}/bin/systemctl restart caddy.service
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };

  # ---------------------------------------------------------------------------
  # Caddy — TLS termination
  # ---------------------------------------------------------------------------
  services.caddy = {
    enable = true;
    virtualHosts."${hostName}.${domain}".extraConfig = ''
      reverse_proxy ${caddyUpstream}
      tls /var/lib/caddy/${lib.toLower hostName}.${domain}.crt /var/lib/caddy/${lib.toLower hostName}.${domain}.key {
        protocols tls1.3
      }
    '';
  };

  # ---------------------------------------------------------------------------
  # oauth2-proxy — only configured when oauth != null
  # ---------------------------------------------------------------------------
  services.oauth2-proxy = lib.mkIf (oauth != null) {
    enable   = true;
    provider = "oidc";

    clientID     = oauth.clientID;
    #clientSecret = "placeholder";   # overridden by --client-secret-file below
    #cookie.secret = "placeholder";  # overridden by --cookie-secret-file below
    keyFile = "/var/lib/${lib.toLower hostName}/oidc.env";
    cookie.secure = true;
    cookie.domain = "${lib.toLower hostName}.${domain}";
    httpAddress   = "127.0.0.1:${toString oauth2Port}";

    oidcIssuerUrl = "https://kanidm.${domain}/oauth2/openid/${oauth.clientID}";

    setXauthrequest = true;
    email.domains   = [ "*" ];

    extraConfig = {
      upstream             = "http://127.0.0.1:${port}";
      silence-ping-logging = true;
      pass-user-headers    = true;
      reverse-proxy = true;
      # These file-based flags take precedence over the placeholder flags above.
      client-secret-file   = "/run/oauth2-proxy-secrets-${lib.toLower hostName}/client-secret";
      cookie-secret-file   = "/run/oauth2-proxy-secrets-${lib.toLower hostName}/cookie-secret";
    } // lib.optionalAttrs
        (oauth ? skipPaths && oauth.skipPaths != [])
        { skip-auth-route = oauth.skipPaths; };
  };

  systemd.services.oauth2-proxy = lib.mkIf (oauth != null) {
    serviceConfig = {
      # Run the secret extraction script as root before dropping to oauth2-proxy user.
      ExecStartPre = [ ("+" + toString secretExtractScript) ];
    };
  };
}
