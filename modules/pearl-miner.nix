{ config, lib, pkgs, ... }:

let
  cfg = config.services.pearl-miner;
  ic = cfg.idleControl;
  cpu = cfg.cpuMining;

  # Units the idle controller starts and stops together.
  units = lib.concatStringsSep " " (
    [ "pearl-miner.service" ] ++ lib.optional cpu.enable "xmrig-idle.service"
  );

  # SRBMiner-MULTI is not in nixpkgs: package the upstream Linux binary.
  # Hash verified against the MD5 published on the GitHub release page.
  srbminer = pkgs.stdenv.mkDerivation rec {
    pname = "srbminer-multi";
    version = "3.7.3";

    src = pkgs.fetchurl {
      url = "https://github.com/doktor83/SRBMiner-Multi/releases/download/${version}/SRBMiner-Multi-${lib.replaceStrings [ "." ] [ "-" ] version}-Linux.tar.gz";
      hash = "sha256-xyUNOf4jVJqI712NIEHXXmAWb11quMja9ydKt7Co2iA=";
    };

    # The binary must stay byte-for-byte pristine. It has no .interp section
    # (patchelf cannot patch it), `strip` corrupts its program interpreter
    # (exec format error), and it refuses to start when launched through
    # ld.so directly. It runs via nix-ld instead, so skip all fixup steps.
    dontFixup = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 SRBMiner-MULTI $out/bin/SRBMiner-MULTI
      runHook postInstall
    '';

    meta = {
      description = "SRBMiner-MULTI GPU/CPU miner (upstream binary)";
      homepage = "https://github.com/doktor83/SRBMiner-Multi";
      license = lib.licenses.unfree;
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      platforms = [ "x86_64-linux" ];
      mainProgram = "SRBMiner-MULTI";
    };
  };

  nvsmi = "${config.hardware.nvidia.package.bin}/bin/nvidia-smi";
  systemctl = "${config.systemd.package}/bin/systemctl";

  # The ignore list joined into one alternation for awk. An empty list becomes
  # "^$" (matches nothing real): an empty regex would match every process.
  # escapeShellArg quotes it safely for the generated script.
  ignoreRe = lib.escapeShellArg (
    if ic.ignore == [ ] then "^$" else lib.concatStringsSep "|" ic.ignore
  );

  tuning = cfg.powerLimitW != null || cfg.memoryClockMHz != null;

  # Applied as root just before the miner starts and undone when it stops, so
  # games get the card's stock limits back the moment the idle controller
  # stops mining. Failures only warn: mining still starts.
  gpuTune = pkgs.writeShellScript "pearl-miner-gpu-tune" ''
    ${lib.optionalString (cfg.powerLimitW != null) ''
      min=$(${nvsmi} --query-gpu=power.min_limit --format=csv,noheader,nounits \
        | head -n1 | cut -d. -f1)
      want=${toString cfg.powerLimitW}
      if [ -n "$min" ] && [ "$want" -lt "$min" ]; then
        echo "pearl-miner: ${toString cfg.powerLimitW} W is below the card minimum ($min W); using $min W" >&2
        want=$min
      fi
      ${nvsmi} -pl "$want" \
        || echo "pearl-miner: could not set power limit" >&2
    ''}
    ${lib.optionalString (cfg.memoryClockMHz != null) ''
      ${nvsmi} -lmc ${toString cfg.memoryClockMHz},${toString cfg.memoryClockMHz} \
        || echo "pearl-miner: could not lock memory clock" >&2
    ''}
    exit 0
  '';

  gpuRestore = pkgs.writeShellScript "pearl-miner-gpu-restore" ''
    ${lib.optionalString (cfg.memoryClockMHz != null) ''
      ${nvsmi} -rmc || true
    ''}
    ${lib.optionalString (cfg.powerLimitW != null) ''
      def=$(${nvsmi} --query-gpu=power.default_limit --format=csv,noheader,nounits \
        | head -n1 | cut -d. -f1)
      [ -n "$def" ] && ${nvsmi} -pl "$def" || true
    ''}
    exit 0
  '';

  # Polls per-process GPU utilisation. Any process other than the miner itself
  # (excluded by PID) at or above the threshold counts as "busy": the miner is
  # stopped once that load is sustained. After the GPU has stayed quiet for
  # idleSeconds, the miner is started again. Every change of state, and every
  # start and stop, is written to the journal with the reason.
  controller = pkgs.writeShellScript "pearl-miner-idle-control" ''
    set -u
    idle=0
    strikes=0
    last=""
    note() { echo "idle-control: $*"; }

    while true; do
      if ! out=$(${nvsmi} pmon -c 1 -s u 2>&1); then
        if [ "$last" != "pmon-failed" ]; then
          note "nvidia-smi pmon failed: $out"
          last="pmon-failed"
        fi
        sleep ${toString ic.pollSeconds}
        continue
      fi

      # The miner's own load must never count against it. Match it by PID, not
      # by name: its process name is not reliable when run through nix-ld.
      mpid=$(${systemctl} show -p MainPID --value pearl-miner.service)
      [ -n "$mpid" ] || mpid=0

      # First other process at or above the threshold, as "name sm%".
      busy=$(printf '%s\n' "$out" | ${pkgs.gawk}/bin/awk \
        -v t=${toString ic.busyThreshold} -v ig=${ignoreRe} -v mp="$mpid" '
        /^#/ { next }
        $2 ~ /^[0-9]+$/ {
          sm = ($4 == "-") ? 0 : $4
          if ($2 != mp && $NF !~ ig && sm + 0 >= t) { print $NF " " sm "%"; exit }
        }')

      # VRAM held by other CUDA/compute processes (LLM servers and the like),
      # even while they sit at 0% utilisation.
      vram=$(${nvsmi} --query-compute-apps=pid,process_name,used_gpu_memory \
        --format=csv,noheader,nounits 2>/dev/null | ${pkgs.gawk}/bin/awk \
        -F', ' -v ig=${ignoreRe} -v mp="$mpid" '
        $1 != mp && $0 !~ ig { m = $NF; if (m ~ /^[0-9]+$/) s += m }
        END { print s + 0 }')

      if [ -n "$busy" ]; then
        key="busy $(printf '%s' "$busy" | cut -d' ' -f1)"
        reason="GPU busy: $busy"
      elif [ ${toString ic.vramThresholdMiB} -gt 0 ] \
           && [ "$vram" -ge ${toString ic.vramThresholdMiB} ]; then
        key="vram"
        reason="VRAM held by other apps: $vram MiB (limit ${toString ic.vramThresholdMiB})"
      else
        key="idle"
        reason=""
      fi

      if [ "$key" != "$last" ]; then
        if [ "$key" = "idle" ]; then
          note "GPU quiet; mining starts after ${toString ic.idleSeconds}s of idleness"
        else
          note "holding miner off: $reason"
        fi
        last="$key"
      fi

      if [ "$key" != "idle" ]; then
        idle=0
        strikes=$((strikes + 1))
        if [ "$strikes" -ge ${toString ic.busyPolls} ]; then
          for u in ${units}; do
            if ${systemctl} is-active --quiet "$u"; then
              note "stopping $u ($reason)"
              ${systemctl} stop "$u"
            fi
          done
        fi
      else
        strikes=0
        idle=$((idle + ${toString ic.pollSeconds}))
        if [ "$idle" -ge ${toString ic.idleSeconds} ]; then
          for u in ${units}; do
            if ! ${systemctl} is-active --quiet "$u"; then
              note "starting $u after ''${idle}s idle"
              ${systemctl} start "$u" || note "failed to start $u"
            fi
          done
        fi
      fi
      sleep ${toString ic.pollSeconds}
    done
  '';
in
{
  options.services.pearl-miner = {
    enable = lib.mkEnableOption "Pearl (PRL) GPU miner";

    account = lib.mkOption {
      type = lib.types.str;
      example = "your-kryptex-username";
      description = ''
        Kryptex Mining Username (auto-exchange, e.g. to BTC) or a PRL wallet address.
      '';
    };

    worker = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      description = "Worker name shown on the pool dashboard.";
    };

    pool = lib.mkOption {
      type = lib.types.str;
      default = "prl-us.kryptex.network:7048";
      description = "Stratum host:port. Use port 8048 for SSL.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra SRBMiner-MULTI arguments.";
    };

    powerLimitW = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      example = 100;
      description = ''
        GPU power limit in watts, applied (as root) only while the miner runs
        and restored to the card's default when it stops. Check the allowed
        range with `nvidia-smi -q -d POWER`. null leaves the limit alone.
      '';
    };

    memoryClockMHz = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      example = 810;
      description = ''
        Lock the GPU memory clock (MHz) while mining and release the lock
        afterwards. SRBMiner 3.7 recommends 810 for its default Ampere
        pearlhash kernel. null leaves the clock alone.
      '';
    };

    cpuMining = {
      enable = lib.mkEnableOption "Monero CPU mining (XMRig) while the machine is idle";

      account = lib.mkOption {
        type = lib.types.str;
        default = cfg.account;
        defaultText = lib.literalExpression "config.services.pearl-miner.account";
        description = ''
          Kryptex Mining Username (BTC auto-exchange), Kryptex account email,
          or an XMR wallet address.
        '';
      };

      worker = lib.mkOption {
        type = lib.types.str;
        default = "${config.networking.hostName}-cpu";
        description = "Worker name shown on the pool dashboard.";
      };

      pool = lib.mkOption {
        type = lib.types.str;
        default = "xmr.kryptex.network:7777";
        description = "Stratum host:port (Kryptex: 7777 plain, 8888 TLS).";
      };

      tls = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Use TLS (set pool port to 8888 for Kryptex).";
      };

      hugepages = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 1280;
        description = ''
          2 MiB huge pages reserved at boot for RandomX (1280 is about 2.5 GiB
          of RAM, held even while the miner is stopped). Without them the
          hashrate drops sharply. 0 disables the reservation.
        '';
      };

      extraArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra XMRig arguments.";
      };
    };

    idleControl = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Run the miner only while the GPU is otherwise idle.";
      };

      idleSeconds = lib.mkOption {
        type = lib.types.ints.positive;
        default = 120;
        description = "Seconds of continuous GPU idleness before mining starts.";
      };

      pollSeconds = lib.mkOption {
        type = lib.types.ints.positive;
        default = 5;
        description = "How often GPU activity is sampled.";
      };

      busyThreshold = lib.mkOption {
        type = lib.types.ints.between 1 100;
        default = 10;
        description = ''
          Per-process GPU SM utilisation (percent) at or above which a process
          counts as real GPU work.
        '';
      };

      busyPolls = lib.mkOption {
        type = lib.types.ints.positive;
        default = 3;
        description = ''
          Consecutive busy samples required before the miner is stopped
          (sustained time is busyPolls x pollSeconds, 15 s by default).
          Filters brief spikes such as switching windows.
        '';
      };

      vramThresholdMiB = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 1024;
        description = ''
          Total VRAM (MiB) held by other compute processes at or above which
          the miner is kept off, even if they are idle. 0 disables the check.
        '';
      };

      ignore = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        # Empty on purpose: the built-in entries are contributed from this
        # module's `config` section below. Because they are an ordinary
        # definition (not the option default), anything you add in your own
        # configuration is merged onto them (lists concatenate) instead of
        # replacing them.
        default = [ ];
        example = [ "chrome" "firefox" ];
        description = ''
          Process names the idle controller disregards, matched as regular
          expression fragments against nvidia-smi's process name. The module
          already ignores the miner and common compositors (see its `config`
          section); entries you add here are appended to those. To replace the
          built-in entries instead, use `lib.mkForce [ ... ]`.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Built-in ignore entries. `mkBefore` puts them ahead of any entries you
    # define, and the list type concatenates all definitions.
    services.pearl-miner.idleControl.ignore = lib.mkBefore [
      "SRBMiner"
      "Xorg"
      "Xwayland"
      "gnome-shell"
      "kwin"
      "plasmashell"
      "Hyprland"
      "sway"
    ];

    systemd.services.pearl-miner = {
      description = "Pearl (PRL) miner (SRBMiner-MULTI)";
      # With idle control on, the controller decides when this runs.
      wantedBy = lib.optional (!ic.enable) "multi-user.target";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      # Stopping or restarting the controller (including at shutdown) stops
      # the miner as part of the same systemd transaction. This replaces a
      # `systemctl stop` call inside the controller's ExecStopPost, which
      # deadlocked at shutdown (see the controller unit below).
      partOf = lib.optional ic.enable "pearl-miner-idle-control.service";

      # The binary is unpatched: nix-ld (enabled below) supplies its loader.
      # NIX_LD_LIBRARY_PATH is passed to the miner as LD_LIBRARY_PATH, which
      # also lets it dlopen the NVIDIA userspace libraries.
      environment = {
        NIX_LD = pkgs.stdenv.cc.bintools.dynamicLinker;
        NIX_LD_LIBRARY_PATH = lib.concatStringsSep ":" [
          "/run/opengl-driver/lib"
          "${lib.getLib pkgs.stdenv.cc.cc}/lib"
        ];
      };

      serviceConfig = {
        ExecStart = lib.escapeShellArgs ([
          "${srbminer}/bin/SRBMiner-MULTI"
          "--disable-cpu"
          "--algorithm" "pearlhash"
          "--pool" cfg.pool
          "--wallet" "${cfg.account}.${cfg.worker}"
        ] ++ cfg.extraArgs);

        DynamicUser = true;
        Restart = "always";
        RestartSec = 10;
        Nice = 10;
        # Never let a stuck miner or nvidia-smi hold up shutdown for 90 s.
        TimeoutStopSec = 20;

        # The "+" prefix runs these as root outside the sandbox, which
        # nvidia-smi needs to change limits and clocks.
        ExecStartPre = lib.optional tuning "+${gpuTune}";
        ExecStopPost = lib.optional tuning "+${gpuRestore}";

        # Hardening (GPU device nodes stay reachable; PrivateDevices is NOT set)
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      };
    };

    systemd.services.pearl-miner-idle-control = lib.mkIf ic.enable {
      description = "Start/stop Pearl miner based on GPU activity";
      wantedBy = [ "multi-user.target" ];
      after = [ "pearl-miner.service" ];
      serviceConfig = {
        ExecStart = controller;
        # Deliberately no ExecStopPost that runs `systemctl stop` on the
        # miners. This unit is ordered After= the miner, so at shutdown it
        # stops first; a `systemctl stop pearl-miner` from here waits for the
        # miner's stop job, which cannot start until this unit has finished
        # stopping. That deadlock hung shutdown until the stop timeout. The
        # miners' PartOf= handles it inside the one systemd transaction.
        Restart = "always";
        RestartSec = 5;
        TimeoutStopSec = 10;
      };
    };

    systemd.services.xmrig-idle = lib.mkIf cpu.enable {
      description = "Monero CPU miner (XMRig), idle-only";
      wantedBy = lib.optional (!ic.enable) "multi-user.target";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      partOf = lib.optional ic.enable "pearl-miner-idle-control.service";

      serviceConfig = {
        ExecStart = lib.escapeShellArgs ([
          "${pkgs.xmrig}/bin/xmrig"
          "--no-color"
          "--coin" "XMR"
          "--url" cpu.pool
          "--user" "${cpu.account}/${cpu.worker}"
          "--pass" "x"
        ] ++ lib.optional cpu.tls "--tls" ++ cpu.extraArgs);

        DynamicUser = true;
        Restart = "always";
        RestartSec = 10;

        # Only consume cycles nothing else wants.
        CPUSchedulingPolicy = "idle";
        IOSchedulingClass = "idle";

        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      };
    };

    boot.kernel.sysctl."vm.nr_hugepages" =
      lib.mkIf (cpu.enable && cpu.hugepages > 0) cpu.hugepages;

    # Provides /lib64/ld-linux-x86-64.so.2 so the unpatched miner can start.
    programs.nix-ld.enable = lib.mkDefault true;

    # SRBMiner is unfree.
    nixpkgs.config.allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) [ "srbminer-multi" ];
  };
}
