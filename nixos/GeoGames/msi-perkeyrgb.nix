{ lib, python3Packages, fetchFromGitHub, hidapi }:

python3Packages.buildPythonApplication {
  pname = "msi-perkeyrgb";
  version = "2.1";

  src = fetchFromGitHub {
    owner = "Askannz";
    repo = "msi-perkeyrgb";
    rev = "v2.1";
    sha256 = "0f25png4fcf7n07g57aa8nc2z3524ydx41b1vzh4dyij39r8lvs0";
    # Run: nix-prefetch-url --unpack https://github.com/Askannz/msi-perkeyrgb/archive/v2.1.tar.gz
    # and replace the sha256 above with the result
  };

  propagatedBuildInputs = with python3Packages; [
    hidapi
  ];

  doCheck = false;

  meta = with lib; {
    description = "Per-key RGB keyboard control for MSI laptops";
    homepage = "https://github.com/Askannz/msi-perkeyrgb";
    license = licenses.mit;
  };
}
