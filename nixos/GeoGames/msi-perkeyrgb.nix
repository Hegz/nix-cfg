{
  lib,
  python3Packages,
  fetchFromGitHub,
  hidapi,
}:
python3Packages.buildPythonApplication {
  pname = "msi-perkeyrgb";
  version = "2.1";

  pyproject = true;

  src = fetchFromGitHub {
    owner = "Askannz";
    repo = "msi-perkeyrgb";
    rev = "v2.1";
    sha256 = "0f25png4fcf7n07g57aa8nc2z3524ydx41b1vzh4dyij39r8lvs0";
  };

  build-system = with python3Packages; [
    setuptools
  ];

  buildInputs = [hidapi];

  # On NixOS, ldconfig doesn't work normally so the library discovery fails.
  # We patch out the ldconfig call and hardcode the nix store path directly.
  postPatch = ''
    substituteInPlace msi_perkeyrgb/hidapi_wrapping.py \
      --replace \
        's = popen("ldconfig -p").read()' \
        's = "${hidapi}/lib/libhidapi-hidraw.so.0\n"' \
      --replace \
        'path_matches = re.findall("/.*libhidapi-hidraw\\.so.+", s)' \
        'path_matches = ["${hidapi}/lib/libhidapi-hidraw.so.0"]' \
      --replace \
        'if len(path_matches) == 0:' \
        'if False:  # path hardcoded at build time for NixOS' \
      --replace \
        'raise HIDLibraryError("ldconfig reports HIDAPI library at %s but file does not exists." % lib_path)' \
        'pass  # path hardcoded at build time for NixOS'
  '';

  doCheck = false;

  meta = with lib; {
    description = "Per-key RGB keyboard control for MSI laptops";
    homepage = "https://github.com/Askannz/msi-perkeyrgb";
    license = licenses.mit;
  };
}
