{ inputs, outputs, lib, config, pkgs, ... }:
# Vim configuration options
{
  nixpkgs.overlays = [
    inputs.nur.overlays.default
  ];
  
  programs.firefox = {
    enable = true;
    profiles.homeManager = {
      isDefault = true;
      extraConfig = ''
        user_pref("sidebar.verticalTabs", true);
        user_pref("browser.toolbars.bookmarks.visibility", "newtab");
      '';
      # https://nur.nix-community.org/repos/rycee/
      extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
        bitwarden
        ublock-origin
        privacy-badger
        darkreader
        plasma-integration
      ];
      settings = {
        "extensions.autoDisableScopes" = 0;
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "signon.rememberSignons" = false;
      };
      bookmarks = {
        force = true;
        settings = [
          {
            name = "SD73 Sites";
            toolbar = true;
            bookmarks = [
              {
                name = "My wiki";
                tags = [ "wiki" ];
                keyword = "wiki";
                url = "http://cromulent/";
              }
              {
                name = "SD73 Email";
                url = "https://outlook.office.com/mail/inbox/";
              }
              {
                name = "Teams";
                url = "https://teams.microsoft.com/v2/";
              }
              {
                name = "GLPI";
                url = "https://assets.sd73.bc.ca";
              }
              {
                name = "Oasis";
                url = "srb-web.sd73.bc.ca";
              }
              {
                name = "Q";
                url = "https://q.sd73.bc.ca/index.php";
              }
              {
                name = "SD73 Outages";
                url = "https://www.sd73.bc.ca/en/working-together-departments/it-inter.aspx";
              }
            ];
          }
        ];
      };
    };
  };
}
