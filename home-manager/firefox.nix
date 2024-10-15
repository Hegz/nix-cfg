{ inputs, outputs, lib, config, pkgs, ... }:
# Vim configuration options
{
  programs.firefox = {
    enable = true;
    profiles.homeManager = {
      isDefault = true;
      userChrome = ''
        #tabbrowser-tabs { visibility: collapse !important; }
        #TabsToolbar-customization-target { visibility: collapse !important; }
      '';
      extraConfig = ''
        # Enable the userChrome by default
        user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
      '';
  };
}
