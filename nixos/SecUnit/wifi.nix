# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{interface, ... }: { inputs, outputs, lib, config, pkgs, secrets, ... }:
{
  # Hostapd based Access point
  services.hostapd = {
    enable        = true;
    radios."${interface}" = {
      band        = "2g";
      channel     = 1;
      countryCode = "CA";
      #noScan      = true;
      networks."${interface}" = {
    	ssid          = "${secrets.secunit.wifi_name}";
        authentication = {
          mode        = "wpa2-sha1";
          wpaPassword = "${secrets.secunit.wifi_pass}";
        };
        macAcl = "allow";
        macAllow = builtins.map (x: "${x.mac}") (secrets.secunit.hosts);
      };
      wifi4 = {
        enable = true;
        # Capibilities obtained from '$iw phys ' and compaired to 
        # https://web.mit.edu/freebsd/head/contrib/wpa/hostapd/hostapd.conf
        capabilities = [
            "LDPC"
            "HT40+"
            "HT40-"
            "SHORT-GI-20"
            "SHORT-GI-40"
			"TX-STBC"
			"RX-STBC1"
			"MAX-AMSDU-7935"
			"DSSS_CCK-40"
          ];
      }; 
      wifi6 = {
        enable = true;
        operatingChannelWidth = "20or40";
        singleUserBeamformee = true;
      };
    }; 
  }; 

  # Enable TPM for better wifi performance?
  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;  # expose /run/current-system/sw/lib/libtpm2_pkcs11.so
    tctiEnvironment.enable = true;  # TPM2TOOLS_TCTI and TPM2_PKCS11_TCTI env variables
  };
}
