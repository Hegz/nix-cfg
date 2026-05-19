{serverName}: { inputs, outputs, config, pkgs, lib, secrets, ... }:
let
  hostname    = "freshrss";
  servicePort = "8080";
  oauth2Port  = 4180;
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
        # Caddy proxies directly to nginx — oauth2-proxy is used via
        # nginx auth_request instead of as an upstream proxy.
        (import ../../modules/container-ssl.nix { port = servicePort; inherit secrets; })
      ];

      networking = {
        hostName = "${hostname}";
        networkmanager.enable = true;
        networkmanager.ethernet.macAddress = "${secrets.${serverName}.containers.${hostname}.mac}";
        firewall = {
          allowedTCPPorts = [ 80 443 ];
          enable = true;
        };
        useHostResolvConf = lib.mkForce false;
      };
      services.resolved.enable = true;

      services.freshrss = {
        enable       = true;
        webserver    = "nginx";
        virtualHost  = "freshrss.${domain}";
        baseUrl      = "https://freshrss.${domain}";
        passwordFile = "/var/lib/freshrss/password";
        authType     = "http_auth";

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

      services.nginx = {
        # Strip @domain suffix from the SPN so FreshRSS gets just "adam"
        # rather than "adam@kanidm.taild7a71.ts.net".
        appendHttpConfig = ''
          map $auth_request_user $auth_user_stripped {
            "~^(?P<user>[^@]+)@.*$" $user;
            default                 $auth_request_user;
          }
        '';
        virtualHosts."freshrss.${domain}" = {
          listen = [ { addr = "127.0.0.1"; port = 8080; } ];

          extraConfig = ''
            # auth_request sends a subrequest to oauth2-proxy to validate the session.
            # oauth2-proxy returns X-Auth-Request-User in the response headers which
            # nginx captures and passes to php-fpm as REMOTE_USER.
            auth_request /oauth2/auth;
            error_page 401 = /oauth2/start;

            # Capture the authenticated username from oauth2-proxy's response header
            auth_request_set $auth_request_user $upstream_http_x_auth_request_preferred_username;

            # Skip auth for API paths so mobile apps keep working
            # API paths bypass oauth2 auth_request so mobile apps work.
            # ^~ prefix match takes priority over regex locations.
            location ^~ /api/ {
              auth_request off;
              fastcgi_pass unix:/run/phpfpm/freshrss.sock;
              fastcgi_split_path_info ^(.+\.php)(/.*)$;
              set $path_info $fastcgi_path_info;
              fastcgi_param PATH_INFO $path_info;
              include ${pkgs.nginx}/conf/fastcgi_params;
              include ${pkgs.nginx}/conf/fastcgi.conf;
            }
            location ^~ /greader.php {
              auth_request off;
              fastcgi_pass unix:/run/phpfpm/freshrss.sock;
              fastcgi_split_path_info ^(.+\.php)(/.*)$;
              set $path_info $fastcgi_path_info;
              fastcgi_param PATH_INFO $path_info;
              include ${pkgs.nginx}/conf/fastcgi_params;
              include ${pkgs.nginx}/conf/fastcgi.conf;
            }
            location ^~ /fever.php {
              auth_request off;
              fastcgi_pass unix:/run/phpfpm/freshrss.sock;
              fastcgi_split_path_info ^(.+\.php)(/.*)$;
              set $path_info $fastcgi_path_info;
              fastcgi_param PATH_INFO $path_info;
              include ${pkgs.nginx}/conf/fastcgi_params;
              include ${pkgs.nginx}/conf/fastcgi.conf;
            }
          '';

          # Override the php location block to pass REMOTE_USER from the
          # auth_request_set variable captured above.
          locations."~ ^.+?\\.php(/.*)?$" = lib.mkForce {
            extraConfig = ''
              fastcgi_pass unix:/run/phpfpm/freshrss.sock;
              fastcgi_split_path_info ^(.+\.php)(/.*)$;
              set $path_info $fastcgi_path_info;
              fastcgi_param PATH_INFO $path_info;
              fastcgi_param REMOTE_USER $auth_user_stripped;
              include ${pkgs.nginx}/conf/fastcgi_params;
              include ${pkgs.nginx}/conf/fastcgi.conf;
            '';
          };

          # oauth2-proxy subrequest endpoint
          locations."/oauth2/" = {
            proxyPass = "http://127.0.0.1:${toString oauth2Port}";
            extraConfig = ''
              auth_request off;
              proxy_set_header X-Auth-Request-Redirect $request_uri;
            '';
          };

          locations."/oauth2/auth" = {
            proxyPass = "http://127.0.0.1:${toString oauth2Port}";
            extraConfig = ''
              auth_request off;
              proxy_pass_request_body off;
              proxy_set_header Content-Length "";
              proxy_set_header X-Original-URI $request_uri;
            '';
          };
        };
      };

      # oauth2-proxy in auth_request mode — doesn't proxy upstream,
      # just validates the session and returns user info in headers.
      services.oauth2-proxy = {
        enable   = true;
        provider = "oidc";

        clientID      = "freshrss";
        keyFile = "/var/lib/${lib.toLower hostname}/oidc.env";
        cookie.secure = true;
        cookie.domain = "freshrss.${domain}";
        httpAddress   = "127.0.0.1:${toString oauth2Port}";

        oidcIssuerUrl = "https://kanidm.${domain}/oauth2/openid/freshrss";
        redirectURL   = "https://freshrss.${domain}/oauth2/callback";

        setXauthrequest = true;
        email.domains   = [ "*" ];

        extraConfig = {
          # No upstream — nginx handles proxying, oauth2-proxy just validates
          upstream        = "static://202";
          reverse-proxy   = true;
          silence-ping-logging = true;
          client-secret-file  = "/run/oauth2-proxy-secrets-freshrss/client-secret";
          cookie-secret-file  = "/run/oauth2-proxy-secrets-freshrss/cookie-secret";
          oidc-email-claim = "preferred_username";
          # X-Auth-Request-User will contain the preferred_username (SPN).
          # nginx strips the @domain suffix before passing to FreshRSS.
        };
      };

      systemd.services.oauth2-proxy = {
        serviceConfig.ExecStartPre = [
          ("+" + toString (pkgs.writeShellScript "oauth2-proxy-secrets" ''
            set -eu
            dir=/run/oauth2-proxy-secrets-freshrss
            mkdir -p "$dir"
            chmod 700 "$dir"
            grep '^OAUTH2_PROXY_CLIENT_SECRET=' /var/lib/freshrss/oidc.env | head -1 | cut -d= -f2- \
              > "$dir/client-secret"
            grep '^OAUTH2_PROXY_COOKIE_SECRET=' /var/lib/freshrss/oidc.env | head -1 | cut -d= -f2- \
              > "$dir/cookie-secret"
            chmod 400 "$dir/client-secret" "$dir/cookie-secret"
            chown oauth2-proxy "$dir/client-secret" "$dir/cookie-secret"
          ''))
        ];
      };
    };
  };
}
