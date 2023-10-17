{ config, pkgs, ... }:
let
  dokuwiki-plugin-edittable = pkgs.stdenv.mkDerivation {
    name = "edittable";
    src = pkgs.fetchzip {
      url = "https://github.com/cosmocode/edittable/archive/refs/tags/2023-01-14.zip";
      sha256 = "sha256-Mns8zgucpJrg1xdEopAhd4q1KH7j83Mz3wxuu4Thgsg=";
    };
    sourceRoot = ".";
    installPhase = "mkdir -p $out; cp -r * $out/";
  };

  dokuwiki-plugin-dw2pdf = pkgs.stdenv.mkDerivation {
    name = "dw2pdf";
    src = pkgs.fetchzip {
      url = "https://github.com/splitbrain/dokuwiki-plugin-dw2pdf/archive/refs/tags/2023-09-15.zip";
      sha256 = "sha256-vRX0YuDr2eHjz6+HpFylEaOGee2a/zfenCj/48enyH0=";
    };
    sourceRoot = ".";
    installPhase = "mkdir -p $out; cp -r * $out/";
  };

  dokuwiki-plugin-drawio = pkgs.stdenv.mkDerivation {
    name = "draw.io";
    src = pkgs.fetchzip {
      url = "https://github.com/lejmr/dokuwiki-plugin-drawio/archive/refs/tags/0.2.10.zip";
      sha256 = "sha256-hiAvV5ySZcnPNcWPofq7CFXDR51zA6vEeTuIfi++S8M=";
    };
    sourceRoot = ".";
    installPhase = "mkdir -p $out; cp -r * $out/";
  };

in {
  services.dokuwiki.sites."localhost" = {
    enable = true;
    settings = {
      title = "My Wiki";
      useacl = true;
      superuser = "@admin";
      allowdebug = true;
      dontlog = "";
    };
    plugins = [ dokuwiki-plugin-drawio dokuwiki-plugin-dw2pdf dokuwiki-plugin-edittable ];
    acl = [
      {
        page = "*";
        actor = "@ALL";
        level = "none";
      }
      {
        page = "start";
        actor = "@external";
        lelvel = "read";
      }
      {
        page = "*";
        actor = "@user";
        level = "delete";
      }
        ];

  };
};
