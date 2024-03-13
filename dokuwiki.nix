{ config, pkgs, ... }:
let
  dokuwiki-plugin-edittable = pkgs.stdenv.mkDerivation {
    name = "edittable";
    src = pkgs.fetchzip {
      url = "https://github.com/cosmocode/edittable/archive/refs/tags/2023-01-14.zip";
      sha256 = "sha256-Mns8zgucpJrg1xdEopAhd4q1KH7j83Mz3wxuu4Thgsg=";
    };
    sourceRoot = ".";
    installPhase = "mkdir -p $out; cp -r source/* $out/";
  };

  dokuwiki-plugin-dw2pdf = pkgs.stdenv.mkDerivation {
    name = "dw2pdf";
    src = pkgs.fetchzip {
      url = "https://github.com/splitbrain/dokuwiki-plugin-dw2pdf/archive/refs/tags/2023-09-15.zip";
      sha256 = "sha256-vRX0YuDr2eHjz6+HpFylEaOGee2a/zfenCj/48enyH0=";
    };
    patches = [ ./patches/dw2pdf_clean.patch ];
    phases = [ "unpackPhase" "patchPhase" "installPhase" ];
    sourceRoot = ".";
    installPhase = "mkdir -p $out; cp -r source/* $out/";
  };

  dokuwiki-plugin-diagrams = pkgs.stdenv.mkDerivation {
    name = "diagrams";
    src = pkgs.fetchzip {
      url = "https://github.com/cosmocode/dokuwiki-plugin-diagrams/archive/refs/tags/2023-08-30.zip";
      sha256 = "sha256-OQqh7NvhK33U0sv2OjRnLlITAV8bBxKGnc7jBGuXUFI=";
    };
    sourceRoot = ".";
    installPhase = "mkdir -p $out; cp -r source/* $out/";
  };

  dokuwiki-plugin-drawio = pkgs.stdenv.mkDerivation {
    name = "drawio";
    src = pkgs.fetchzip {
      url = "https://github.com/lejmr/dokuwiki-plugin-drawio/archive/refs/tags/0.2.10.zip";
      sha256 = "sha256-hiAvV5ySZcnPNcWPofq7CFXDR51zA6vEeTuIfi++S8M=";
    };
    sourceRoot = ".";
    installPhase = "mkdir -p $out; cp -r source/* $out/";
  };

  dokuwiki-template-mindthedark = pkgs.stdenv.mkDerivation {
    name = "mindthedark";
    src = pkgs.fetchzip {
      url = "https://github.com/MrReSc/MindTheDark/archive/refs/tags/2023-03-05.zip";
      sha256 = "sha256-RF+Vao5nVOdeXju/ZQA47BG+q4vzoAtbw4wUwT9tnys=";
    };
    sourceRoot = ".";
    installPhase = "mkdir -p $out; cp -r source/* $out/";
  };

in {
  services.dokuwiki.sites."localhost" = {
    enable = true;
    settings = {
      title = "My Wiki";
      useacl = true;
      superuser = "@admin";
      plugin.dw2pdf.pagesize = "letter";
      plugin.dw2pdf.doublesided = false;
      plugin.dw2pdf.template = "clean";
      template = "mindthedark";
      tpl.mindthedark.autoDark = true;
      updatecheck = false;
    };
    plugins = [ dokuwiki-plugin-drawio dokuwiki-plugin-dw2pdf dokuwiki-plugin-edittable ];
    templates = [ dokuwiki-template-mindthedark ];

    acl = [
      {
        page = "*";
        actor = "@ALL";
        level = "none";
      }
      {
        page = "*";
        actor = "@user";
        level = "delete";
      }
    ];
  };
}
