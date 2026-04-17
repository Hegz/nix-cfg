{ lib, stdenv, fetchFromGitHub, python3, coreutils }:

stdenv.mkDerivation rec {
  pname = "isw";
  # Release is old and missing features such as setting the battery charging limit
  version = "unstable-2021-02-26";

  src = fetchFromGitHub {
    owner = "YoyPa";
    repo = pname;
    rev = "7c88670504ecd4462b1825a55bdb0be2944dfe94";
    sha256 = "13ax1npr6mwk8zg725vm4n5x58g4lf87crdw92yj1w7lnn0dxp8w";
  };

  buildInputs = [ python3 coreutils ];

  dontBuild = true;
  dontConfigure = true;

  postPatch = ''
    patchShebangs isw
    substituteInPlace usr/lib/systemd/system/isw@.service \
      --replace "/usr/bin/sleep" "${coreutils}/bin/sleep" \
      --replace "/usr/bin/isw" "$out/bin/isw"
  '';

  installPhase = ''
    runHook preInstall

    install -Dm644 etc/isw.conf $out/etc/isw.conf
    install -Dm644 usr/lib/systemd/system/isw@.service $out/lib/systemd/system/isw@.service
    install -Dm644 isw $out/bin/isw

    runHook postInstall
  '';

  meta = with lib; {
    description = "Fan control tool for MSI gaming series laptops";
    homepage = "https://github.com/YoyPa/isw";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ ];
  };
}

