{
  config,
  pkgs,
  lib,
  ...
}: let
  driverVersion = "cb27cc483f4fe98be03a4f4bef466c00aa7d244b";

  suspendFixPatch = pkgs.writeText "suspend-fix.patch" ''
  --- a/patch_cirrus/patch_cirrus_apple.h
  +++ b/patch_cirrus/patch_cirrus_apple.h
  @@ -1396,17 +1396,6 @@ static int cs_8409_apple_init(struct hda_codec *codec)
   	return 0;
   }
   
  -static int cs_8409_apple_resume(struct hda_codec *codec)
  -{
  -        myprintk("snd_hda_intel: cs_8409_apple_resume\n");
  -        // code copied from default resume patch ops
  -	if (codec->patch_ops.init)
  -		codec->patch_ops.init(codec);
  -	snd_hda_regmap_sync(codec);
  -        myprintk("snd_hda_intel: end cs_8409_apple_resume\n");
  -        return 0;
  -}
  -
   static int cs_8409_apple_suspend(struct hda_codec *codec)
   {
           myprintk("snd_hda_intel: cs_8409_apple_suspend\n");
  @@ -1716,24 +1705,6 @@ void cs_8409_apple_free(struct hda_codec *codec)
   	snd_hda_gen_free(codec);
   }
   
  -
  -// note this must come after any function definitions used
  -
  -static const struct hda_codec_ops cs_8409_apple_patch_ops = {
  -	.build_controls = cs_8409_apple_build_controls,
  -	.build_pcms = cs_8409_apple_build_pcms,
  -	.init = cs_8409_apple_init,
  -	.free = cs_8409_apple_free,
  -	.unsol_event = cs_8409_cs42l83_jack_unsol_event,
  -#ifdef CONFIG_PM
  -        .resume = cs_8409_apple_resume,
  -        .suspend = cs_8409_apple_suspend,
  -        .check_power_status = cs_8409_apple_check_power_status,
  -#endif
  -};
  -
  -
  -
   //      jack handling analysis
   //      now it appears that unsolicited events are assumed to be due to jack plug/unplug events
   //      so the .unsol_event function is the primary handling function for this
  @@ -2555,6 +2526,32 @@ static struct cs8409_apple_spec *cs8409_apple_alloc_spec(struct hda_codec *codec
   	return spec;
   }
   
  +// for the moment split the new code into an include file
  +
  +#include "patch_cirrus_new84.h"
  +
  +static int cs_8409_apple_resume(struct hda_codec *codec)
  +{
  +        myprintk("snd_hda_intel: start cs_8409_apple_resume\n");
  +        cs_8409_boot_setup_real(codec);
  +        myprintk("snd_hda_intel: end cs_8409_apple_resume\n");
  +        return 0;
  +}
  +
  +// note this must come after any function definitions used
  +
  +static const struct hda_codec_ops cs_8409_apple_patch_ops = {
  +	.build_controls = cs_8409_apple_build_controls,
  +	.build_pcms = cs_8409_apple_build_pcms,
  +	.init = cs_8409_apple_init,
  +	.free = cs_8409_apple_free,
  +	.unsol_event = cs_8409_cs42l83_jack_unsol_event,
  +#ifdef CONFIG_PM
  +        .resume = cs_8409_apple_resume,
  +        .suspend = cs_8409_apple_suspend,
  +        .check_power_status = cs_8409_apple_check_power_status,
  +#endif
  +};
   
   static int patch_cs8409_apple(struct hda_codec *codec)
   {
  @@ -3091,12 +3088,6 @@ static int patch_cs8409_apple(struct hda_codec *codec)
          return err;
   }
   
  -
  -// for the moment split the new code into an include file
  -
  -#include "patch_cirrus_new84.h"
  -
  -
   // new function to use "vendor" defined commands to run
   // a specific code
   // has to be here to use functions defined in patch_cirrus_new84.h
  '';


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

    makeFlags = [
      "KERNELRELEASE=${config.boot.kernelPackages.kernel.modDirVersion}"
      "KERNEL_DIR=${config.boot.kernelPackages.kernel.dev}/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/build"
    ];

    preBuild = ''
      makeFlags="$makeFlags INSTALL_MOD_PATH=$out"
    '';

    installFlags = [ "INSTALL_MOD_PATH=$(out)" ];

    # The suspend/resume fix patch (PR #90 commit 085678c):
    # Moves the #include of patch_cirrus_new84.h earlier so that
    # cs_8409_boot_setup_real() is defined before the resume callback
    # uses it. Replaces the old resume path (init + regmap_sync) with
    # a full boot setup, restoring all codec register state after S3 sleep.

    prePatch = ''
      cp ${suspendFixPatch} ./suspend-fix.patch
    '';
  
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
      
      # Apply suspend fix to patch_cirrus/patch_cirrus_apple.h BEFORE copying to build/hda
      # patch -b -p1 <./suspend-fix.patch

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
