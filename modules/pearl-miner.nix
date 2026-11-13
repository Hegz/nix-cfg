{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.pearl-miner;
  ic = cfg.idleControl;
  cpu = cfg.cpuMining;

  # CPU-load check: needs the CPU miner and a threshold (null disables it).
  cpuCheck = cpu.enable && ic.cpuBusyPercent != null;
  cpuFlag =
    if cpuCheck
    then "1"
    else "0";
  cpuThreshold =
    if ic.cpuBusyPercent == null
    then 100
    else ic.cpuBusyPercent;

  # SRBMiner-MULTI is not in nixpkgs: package the upstream Linux binary.
  # Hash verified against the MD5 published on the GitHub release page.
  srbminer = pkgs.stdenv.mkDerivation rec {
    pname = "srbminer-multi";
    version = "3.8.4";

    src = pkgs.fetchurl {
      url = "https://github.com/doktor83/SRBMiner-Multi/releases/download/${version}/SRBMiner-Multi-${lib.replaceStrings ["."] ["-"] version}-Linux.tar.gz";
      #hash = "sha256-xyUNOf4jVJqI712NIEHXXmAWb11quMja9ydKt7Co2iA=";
      hash = "sha256-PPSJxdyUdN9y0cT/n1c+qJH13BMkTutF9F3Z3vmGLaw=";
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
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      platforms = ["x86_64-linux"];
      mainProgram = "SRBMiner-MULTI";
    };
  };

  nvsmi = "${config.hardware.nvidia.package.bin}/bin/nvidia-smi";
  systemctl = "${config.systemd.package}/bin/systemctl";

  # The ignore list joined into one alternation for awk. An empty list becomes
  # "^$" (matches nothing real): an empty regex would match every process.
  # escapeShellArg quotes it safely for the generated script.
  ignoreRe = lib.escapeShellArg (
    if ic.ignore == []
    then "^$"
    else lib.concatStringsSep "|" ic.ignore
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

  # Polls per-process GPU utilisation, and optionally machine-wide CPU load.
  #
  # GPU: any process other than the miner itself (excluded by PID) at or above
  # the threshold counts as "busy". Sustained GPU load stops BOTH miners; once
  # the GPU has been quiet for idleSeconds they may start again.
  #
  # CPU: load from everything except the miners' own cgroups. Sustained CPU
  # load stops only the CPU miner (the GPU miner barely needs the CPU), and it
  # restarts after the CPU has also been quiet for idleSeconds.
  #
  # Every change of state, start and stop is written to the journal.
  controller = pkgs.writeShellScript "pearl-miner-idle-control" ''
        set -u
        g_idle=0; g_strikes=0; c_idle=0; c_strikes=0
        last=""; clast=""
        cpu_pct=0
        note() { echo "idle-control: $*"; }

        stop_unit() {
          if ${systemctl} is-active --quiet "$1"; then
            note "stopping $1 ($2)"
            ${systemctl} stop "$1"
          fi
        }
        start_unit() {
          if ! ${systemctl} is-active --quiet "$1"; then
            note "starting $1 ($2)"
            ${systemctl} start "$1" || note "failed to start $1"
          fi
        }

        # CPU accounting. "Other" load = machine-wide busy time minus what the
        # miners' own cgroups used, so the miners never count against themselves.
        # /proc/stat is in USER_HZ ticks (100 per second on Linux = 10000 us each).
        cpu_ticks() {
          read -r _ user nice system idl iowait irq softirq steal _ < /proc/stat
          echo "$((user + nice + system + irq + softirq + steal)) $((user + nice + system + idl + iowait + irq + softirq + steal))"
        }
        cg_usec() {
          f=/sys/fs/cgroup/system.slice/$1/cpu.stat
          if [ -r "$f" ]; then
            ${pkgs.gawk}/bin/awk '$1 == "usage_usec" { print $2 }' "$f"
          else
            echo 0
          fi
        }
        read -r p_busy p_total <<< "$(cpu_ticks)"
        p_mine=$(( $(cg_usec pearl-miner.service) + $(cg_usec xmrig-idle.service) ))

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

          ckey="idle"
          if [ ${cpuFlag} -eq 1 ]; then
            read -r busy_t total_t <<< "$(cpu_ticks)"
            mine=$(( $(cg_usec pearl-miner.service) + $(cg_usec xmrig-idle.service) ))
            d_busy=$(( (busy_t - p_busy) * 10000 ))
            d_total=$(( (total_t - p_total) * 10000 ))
            d_mine=$(( mine - p_mine ))
            [ "$d_mine" -ge 0 ] || d_mine=0
            other=$(( d_busy - d_mine ))
            [ "$other" -ge 0 ] || other=0
            if [ "$d_total" -gt 0 ]; then cpu_pct=$(( other * 100 / d_total )); else cpu_pct=0; fi
            p_busy=$busy_t; p_total=$total_t; p_mine=$mine
            if [ "$cpu_pct" -ge ${toString cpuThreshold} ]; then ckey="busy"; fi

            if [ "$ckey" != "$clast" ]; then
              if [ "$ckey" = "idle" ]; then
                note "CPU quiet ($cpu_pct% from other processes)"
              else
                note "CPU busy ($cpu_pct% from other processes, limit ${toString cpuThreshold}%)"
              fi
              clast="$ckey"
            fi
          fi

          if [ "$key" != "idle" ]; then
            g_idle=0; g_strikes=$((g_strikes + 1))
          else
            g_strikes=0; g_idle=$((g_idle + ${toString ic.pollSeconds}))
          fi
          if [ "$ckey" != "idle" ]; then
            c_idle=0; c_strikes=$((c_strikes + 1))
          else
            c_strikes=0; c_idle=$((c_idle + ${toString ic.pollSeconds}))
          fi

          # GPU miner: governed by GPU activity only.
          if [ "$g_strikes" -ge ${toString ic.busyPolls} ]; then
            stop_unit pearl-miner.service "$reason"
          fi
          if [ "$g_idle" -ge ${toString ic.idleSeconds} ]; then
            start_unit pearl-miner.service "GPU idle for $g_idle s"
          fi
    ${lib.optionalString cpu.enable ''
      # CPU miner: stopped by GPU load or CPU load; started when both are quiet.
      if [ "$g_strikes" -ge ${toString ic.busyPolls} ]; then
        stop_unit xmrig-idle.service "$reason"
      elif [ "$c_strikes" -ge ${toString ic.busyPolls} ]; then
        stop_unit xmrig-idle.service "CPU busy: $cpu_pct% from other processes"
      fi
      if [ "$g_idle" -ge ${toString ic.idleSeconds} ] \
         && [ "$c_idle" -ge ${toString ic.idleSeconds} ]; then
        start_unit xmrig-idle.service "GPU and CPU quiet for $g_idle s"
      fi
    ''}
          sleep ${toString ic.pollSeconds}
        done
  '';
in {
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
      default = [];
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
        default =
          if cpu.oneGibPages > 0
          then 256
          else 1280;
        defaultText = lib.literalExpression "if oneGibPages > 0 then 256 else 1280";
        description = ''
          2 MiB huge pages reserved at boot for RandomX, held even while the
          miner is stopped. Without 1 GiB pages (oneGibPages = 0) the whole
          2 GiB dataset lives here, so 1280 (about 2.5 GiB) is needed. With
          1 GiB pages only the cache and scratchpads remain (about 150 pages),
          so the default drops to 256 (512 MiB). 0 disables the reservation.
        '';
      };

      oneGibPages = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 0;
        example = 3;
        description = ''
          Number of 1 GiB huge pages reserved at boot, for XMRig's RandomX
          dataset (it needs 3). Typically a few percent faster than 2 MiB
          pages. Costs that much RAM permanently, even while the miner is
          stopped, and needs a reboot to take effect (the kernel can only
          reserve 1 GiB pages reliably at boot). 0 disables it.
        '';
      };

      msrMod = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Let XMRig apply its model-specific-register (MSR) tweak for Ryzen
          CPUs, which is what removes its "HASHRATE WILL BE LOW" warning.
          Loads the `msr` kernel module and gives the XMRig service two extra
          capabilities (CAP_SYS_RAWIO, CAP_DAC_OVERRIDE) so it can write
          /dev/cpu/*/msr. XMRig restores the original values when it stops.
          Off by default because it grants a network-facing service low-level
          hardware access, and writing MSRs taints the kernel.
        '';
      };

      extraArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
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

      cpuBusyPercent = lib.mkOption {
        type = lib.types.nullOr (lib.types.ints.between 1 100);
        default = 25;
        description = ''
          Stop the CPU miner while other processes use at least this percent of
          the whole CPU (all threads; 25 is about four of sixteen threads busy),
          sustained for busyPolls polls, and restart it after the CPU has been
          quiet for idleSeconds. The miners' own usage is subtracted. Only the
          CPU miner is affected. null disables the check. Needs cpuMining.enable.
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
        default = [];
        example = ["chrome" "firefox"];
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
      after = ["network-online.target"];
      wants = ["network-online.target"];
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
            "--algorithm"
            "pearlhash"
            "--pool"
            cfg.pool
            "--wallet"
            "${cfg.account}.${cfg.worker}"
          ]
          ++ cfg.extraArgs);

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
      wantedBy = ["multi-user.target"];
      after = ["pearl-miner.service"];
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
      after = ["network-online.target"];
      wants = ["network-online.target"];
      partOf = lib.optional ic.enable "pearl-miner-idle-control.service";

      serviceConfig =
        {
          ExecStart = lib.escapeShellArgs ([
              "${pkgs.unstable.xmrig}/bin/xmrig"
              "--no-color"
              "--coin"
              "XMR"
              "--url"
              cpu.pool
              "--user"
              "${cpu.account}/${cpu.worker}"
              "--pass"
              "x"
            ]
            ++ lib.optional cpu.tls "--tls"
            ++ lib.optional (cpu.oneGibPages > 0) "--randomx-1gb-pages"
            ++ cpu.extraArgs);

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
        }
        // lib.optionalAttrs cpu.msrMod {
          # Only what the MSR tweak needs: the msr driver demands CAP_SYS_RAWIO
          # to open and write the device, and the nodes are root-only (0600).
          AmbientCapabilities = ["CAP_SYS_RAWIO" "CAP_DAC_OVERRIDE"];
          CapabilityBoundingSet = ["CAP_SYS_RAWIO" "CAP_DAC_OVERRIDE"];
        };
    };

    boot.kernelModules = lib.optional (cpu.enable && cpu.msrMod) "msr";

    # `hugepages=N` applies to the `hugepagesz=` before it, so this reserves
    # 1 GiB pages only; the default page size stays 2 MiB, which the
    # vm.nr_hugepages sysctl below continues to control.
    boot.kernelParams = lib.optionals (cpu.enable && cpu.oneGibPages > 0) [
      "hugepagesz=1G"
      "hugepages=${toString cpu.oneGibPages}"
    ];

    boot.kernel.sysctl."vm.nr_hugepages" =
      lib.mkIf (cpu.enable && cpu.hugepages > 0) cpu.hugepages;

    # Provides /lib64/ld-linux-x86-64.so.2 so the unpatched miner can start.
    programs.nix-ld.enable = lib.mkDefault true;

    # SRBMiner is unfree.
    nixpkgs.config.allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) ["srbminer-multi"];
  };
}
