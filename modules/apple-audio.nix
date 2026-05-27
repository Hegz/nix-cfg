{
  config,
  pkgs,
  lib,
  ...
}: let
  driverVersion = "cb27cc483f4fe98be03a4f4bef466c00aa7d244b";
    snd-hda-cirrus = pkgs.stdenv.mkDerivation {
    pname = "snd-hda-cirrus";
    name = "snd-hda-codec-cirrus-${driverVersion}-module-${config.boot.kernelPackages.kernel.modDirVersion}";
    version = driverVersion;
    src = pkgs.fetchgit {
      url = "https://github.com/davidjo/snd_hda_macbookpro";
      rev = driverVersion;
      sha256 = "sha256-I1wueOMaYvdF80LdH8gua1h5sgmiD7oU9flNbutESkk=";
    };
    hardeningDisable = ["pic"];
    nativeBuildInputs = config.boot.kernelPackages.kernel.moduleBuildDependencies;
    NIX_CFLAGS_COMPILE = ["-g" "-Wall" "-Wno-unused-variable" "-Wno-unused-function"];

    # Don't use makeFlags for variables that need shell expansion
    makeFlags = [
      "KERNELRELEASE=${config.boot.kernelPackages.kernel.modDirVersion}"
      "KERNEL_DIR=${config.boot.kernelPackages.kernel.dev}/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/build"
    ];

    # Set the paths that need shell expansion here instead
    preBuild = ''
      makeFlags="$makeFlags INSTALL_MOD_PATH=$out"
    '';

    installFlags = [ "INSTALL_MOD_PATH=$(out)" ];

    postPatch = ''
      printf '
      snd-hda-codec-cs8409-objs := patch_cs8409.o patch_cs8409-tables.o
      obj-$(CONFIG_SND_HDA_CODEC_CS8409) += snd-hda-codec-cs8409.o
      KBUILD_EXTRA_CFLAGS = "-DAPPLE_PINSENSE_FIXUP -DAPPLE_CODECS -DCONFIG_SND_HDA_RECONFIG=1"
      PWD := $(CURDIR)/build/hda
      default:
      	make -C $(KERNEL_DIR) M=$(PWD) CFLAGS_MODULE=$(KBUILD_EXTRA_CFLAGS)
      install:
      	make -C $(KERNEL_DIR) M=$(PWD) modules_install
      ' \
      > Makefile
      mkdir build
      tar -xf ${config.boot.kernelPackages.kernel.src} -C ./build --strip-components=3 "linux-${config.boot.kernelPackages.kernel.modDirVersion}/sound/pci/hda"
      cp patch_cirrus/Makefile patch_cirrus/patch_cirrus_* build/hda
      cd build/hda
      patch -b -p2 <../../patch_patch_cs8409.c.diff
      patch -b -p2 <../../patch_patch_cs8409.h.diff
      patch -b -p2 <../../patch_patch_cirrus_apple.h.diff
      cd -
    '';
    meta = {platforms = lib.platforms.linux;};
  };

in {
  boot.extraModulePackages = [snd-hda-cirrus];
}
