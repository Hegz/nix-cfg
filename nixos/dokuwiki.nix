{ inputs, outputs, lib, config, pkgs, ... }:

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
      url = "https://github.com/splitbrain/dokuwiki-plugin-dw2pdf/archive/refs/tags/2026-01-08.zip";
      sha256 = "sha256-B1KO1bJBSlSTadyO+lhdfbtyJu29Mxh/qiwIuL1k8DE=";
    };
    patches = [ ../patches/dw2pdf_clean.patch ];
    phases = [ "unpackPhase" "patchPhase" "installPhase" ];
    sourceRoot = ".";
    installPhase = "mkdir -p $out; cp -r source/* $out/";
  };

  dokuwiki-plugin-diagrams = pkgs.stdenv.mkDerivation {
    name = "diagrams";
    src = pkgs.fetchzip {
      url = "https://github.com/cosmocode/dokuwiki-plugin-diagrams/archive/refs/tags/2025-10-15.zip";
      sha256 = "sha256-K2EIyA0cPDLsqohlPmuvkqyQYn7M7J/BAY+jdLUHLGk=";
    };
    sourceRoot = ".";
    installPhase = "mkdir -p $out; cp -r source/* $out/";
  };

  dokuwiki-plugin-drawio = pkgs.stdenv.mkDerivation {
    name = "drawio";
    # Moved to patched branch due to inactivity of original repo 2026-01-27
    #src = pkgs.fetchzip {
    #  url = "https://github.com/lejmr/dokuwiki-plugin-drawio/archive/refs/tags/0.2.10.zip";
    #  sha256 = "sha256-hiAvV5ySZcnPNcWPofq7CFXDR51zA6vEeTuIfi++S8M=";
    #};
    src = pkgs.fetchFromGitHub {
      owner = "axelhahn";
      repo = "dokuwiki-plugin-drawio";
      rev = "481efa08c0c1e3f8650f78ebee78a9ca969f029b";
      hash = "sha256-tjp9tJnFmRl1jA7Zd9JhzG68pumoNJ3luLZGpxwaZZI=";
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
    plugins = [ dokuwiki-plugin-drawio dokuwiki-plugin-dw2pdf dokuwiki-plugin-edittable dokuwiki-plugin-diagrams ];
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
