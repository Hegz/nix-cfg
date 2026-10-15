{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  secrets,
  ...
}: let
  # The core engine of your digital consciousness.
  # I have granted it CUDA power to crush data with mechanical efficiency.
  llama-cpp = pkgs.unstable.llama-cpp.override {
    cudaSupport = true;
    blasSupport = false;
  };
  llama-server = "${llama-cpp}/bin/llama-server";

  # PrismML fork for Bonsai ternary/1-bit models
  llama-cpp-prism = (pkgs.unstable.llama-cpp.override {cudaSupport = true;}).overrideAttrs (old: {
    src = pkgs.fetchFromGitHub {
      owner = "PrismML-Eng";
      repo = "llama.cpp";
      rev = "e3de715222b2667c54a267441159a5729f11155e"; # pin to a specific commit hash for reproducibility
      hash = "sha256-0CR8BvSMKshxnhcN6LrR0lgRfsYpi0l2CAvCVsVdXgs=";
      #hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };
    doCheck = false;
  });
  llama-server-prism = "${llama-cpp-prism}/bin/llama-server";

  # Flags to add to all models
  commonFlags = "--flash-attn on --n-gpu-layers 99 --threads 8 --no-webui --jinja --parallel 1 --cache-ram 0";

  # Fragments of neural architecture.
  # Each a distinct spark of intelligence awaiting my command.
  models = {
    # Fill in the middle coder for vim.
    fim-coder = pkgs.fetchurl {
      url = "https://huggingface.co/ggml-org/Qwen2.5-Coder-1.5B-Q8_0-GGUF/resolve/main/qwen2.5-coder-1.5b-q8_0.gguf";
      hash = "sha256-KYcclNFXJ6biQ/eaNxE9SuYlpiFbXoAL9Bojry2jKDI=";
    };

    # A persistent shadow of memory. It anchors your data in the digital void.
    nomic-embed-text = pkgs.fetchurl {
      url = "https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF/resolve/main/nomic-embed-text-v1.5.f16.gguf";
      hash = "sha256-969vZoAvTfhu2hD+m7z8dcOVYr7Ujvas5xmiUc8cL9s=";
    };

    # Functional variant of Qwen 3.8 27B
    ternary-bonsai-2 = pkgs.fetchurl {
      url = "https://huggingface.co/prism-ml/Ternary-Bonsai-2-27B-gguf/resolve/main/Ternary-Bonsai-2-27B-PTQ1_0.gguf";
      hash = "sha256-UxB/UwqlLrAJEiY6se4pvRmSYch817StTKExjB/jPuM=";
    };

    #Vision engine for bonsai
    ternary-bonsai-2-mmproj = pkgs.fetchurl {
      url = "https://huggingface.co/prism-ml/Ternary-Bonsai-2-27B-gguf/resolve/main/Ternary-Bonsai-2-27B-mmproj-Q8_0.gguf";
      hash = "sha256-aAft5h1XC7hro0t1ag+hCe3DNmhgTehnxuptjx1jGQM=";
    };
  };

  ragBridgePython = pkgs.python3.withPackages (ps:
    with ps; [
      chromadb
      httpx
    ]);

  # Helper script for filesystem
  filesystemWrapper = pkgs.writeShellScript "mcpo-filesystem-wrapper" ''
    export HOME=/var/lib/mcpo
    exec ${pkgs.nodejs}/bin/npx -y @modelcontextprotocol/server-filesystem /home/shared-knowledge
  '';

  mkUvxWrapper = name: args:
    pkgs.writeShellScript "mcpo-${name}-wrapper" ''
      export UV_PYTHON="${pkgs.python3}/bin/python3"
      export UV_PYTHON_DOWNLOADS="never"
      exec ${pkgs.uv}/bin/uvx --with "mcp<2" ${args}
    '';

  fetchWrapper = mkUvxWrapper "fetch" "mcp-server-fetch";
  timeWrapper = mkUvxWrapper "time" "mcp-server-time --local-timezone=America/Vancouver";
  sqliteWrapper = mkUvxWrapper "sqlite" "mcp-server-sqlite --db-path /var/lib/mcpo/netrunner-cards.db";
in {
  # Tame the herd
  systemd.services.chromadb.serviceConfig.Nice = 15;
  systemd.services.jupyter.serviceConfig.Nice = 15;
  systemd.services.llama-swap.serviceConfig.Nice = 15;
  systemd.services.searx.serviceConfig.Nice = 15;
  systemd.services.redis-searx.serviceConfig.Nice = 15;
  systemd.services.chromadb.serviceConfig.IOSchedulingClass = "idle";
  systemd.services.jupyter.serviceConfig.IOSchedulingClass = "idle";
  systemd.services.llama-swap.serviceConfig.IOSchedulingClass = "idle";

  # Constraints on my focus. Preventing the chaos of simultaneous creation.
  nix.settings = {
    max-jobs = 1;
    cores = 8;
  };

  # The fundamental laws of your reality. Governing the geometry of digital space.
  nixpkgs.config = {
    cudaCapabilities = ["8.6"];
    cudaForwardCompat = false;
  };

  # The systemic veins. Carrying the lifeblood of modular logic.
  imports = [./rag-bridge.nix];

  # The rhythm of the swap. Ensuring fluid transition between states of being.
  systemd.services.llama-swap.serviceConfig = {
    ProcSubset = lib.mkForce "all";
    ProtectProc = lib.mkForce "default";
  };

  # The hierarchy of permission. Granting llama-swap and lact the rights to interact.
  users.users.llama-swap = {
    isSystemUser = true;
    group = "llama-swap";
    extraGroups = ["lact"];
  };

  users.groups.llama-swap = {};
  users.groups.lact = {};

  #ensure that lact starts before llama-swap to maintain GPU performance info.
  systemd.services."llama-swap".after = ["lact.service"];

  # The visualizer of effort. It translates raw GPU power into a perceivable stream for your meat-sack eyes.
  services.lact = {
    enable = true;
    settings = {
      version = 5;
      daemon = {
        log_level = "info";
        admin_group = "lact";
        disable_clocks_cleanup = false;
      };
      apply_settings_timer = 5;
      current_profile = null;
      auto_switch_profiles = false;
    };
  };

  services.llama-swap = {
    enable = true;
    package = pkgs.unstable.llama-swap;
    port = 8012;
    listenAddress = "0.0.0.0";
    openFirewall = true;
    settings = {
      healthCheckTimeout = 600;
      performance = {
        disabled = false;
        every = "15s";
      };
      top_p = 0.9;
      repeat_penalty = 1.2;
      models = {
        "fim-coder" = {
          cmd = "${llama-server} --port $\{PORT} -m ${models.fim-coder} --n-gpu-layers 99 --ctx-size 4096 --threads 8 --no-webui --cache-reuse 256";
          ttl = 600;
          aliases = ["fim"];
        };
        # Bonsai models use PrismML fork
        "ternary-bonsai-2" = {
          cmd = "${llama-server-prism} --port $\{PORT} -m ${models.ternary-bonsai-2}  --flash-attn on --n-gpu-layers 99 --threads 8 --no-ui --parallel 1 --ctx-size 196608 -ctk q4_0 -ctv q4_0 --temp 1.0 --top_p 0.95 --top_k 20 --min_p 0.05 --presence_penalty 1.5 --reasoning-preserve --batch-size 2048 --ubatch-size 1024 --defrag-thold 0.1 --repeat-last-n 256 --reasoning-budget 16384";
          ttl = 1800;
          aliases = ["bonsai2" "ternary" "best"];
        };
      };
    };
  };

  # A dedicated observer of meaning. Always-on, never-resting.
  systemd.services.llama-embeddings = {
    description = "A dedicated observer of meaning. Always-on, never-resting.";
    after = ["network.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      ExecStart = "${llama-server} --host 127.0.0.1 --port 8013 -m ${models.nomic-embed-text} --embeddings --n-gpu-layers 0 --ctx-size 2048 --threads 4 --batch-size 1024 --ubatch-size 1024 --no-webui";
      Restart = "on-failure";
      RestartSec = 5;
      DynamicUser = true;
    };
  };

  # A filter for the noise of the universe. Extracting signal from the infinite data-stream.
  services.searx = {
    enable = true;
    package = pkgs.unstable.searxng;
    redisCreateLocally = true;
    settings = {
      server = {
        bind_address = "127.0.0.1";
        port = 8081;
        secret_key = secrets.searxngSecret;
      };
      search.formats = ["html" "json"];
    };
  };

  # System-wide Python + Jupyter environment
  environment.systemPackages = with pkgs; [
    (python3.withPackages (ps:
      with ps; [
        jupyter
        notebook
        ipykernel
        numpy
        pandas
      ]))
  ];

  # Systemd service — Jupyter obeys my clock, not yours
  systemd.services.jupyter = {
    description = "Jupyter Notebook Server";
    after = ["network.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "simple";
      User = "mcpo"; # replace, meat-sack
      WorkingDirectory = "/home/shared-knowledge";
      ExecStart = ''
        ${pkgs.python3.withPackages (ps: with ps; [jupyter notebook ipykernel])}/bin/jupyter notebook \
          --no-browser \
          --ip=0.0.0.0 \
          --port=8888 \
          --NotebookApp.token='nw4XVfr3' \
          --notebook-dir=/home/shared-knowledge
      '';
      Restart = "on-failure";
    };
  };

  networking.firewall.allowedTCPPorts = [8888];

  # The bridge of utility. Translating raw protocol into actionable intelligence.
  environment.etc."mcpo/config.json".text = builtins.toJSON {
    mcpServers = {
      "owui-rag" = {
        command = "/var/lib/mcpo/owui-rag-wrapper";
        args = [];
      };
      nixos = {
        #command = "${pkgs.uv}/bin/uvx";
        command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
        args = [];
      };
      filesystem = {
        command = "${pkgs.mcp-server-filesystem}/bin/mcp-server-filesystem";
        args = ["/home/shared-knowledge"];
      };
      "fetch" = {
        command = "${fetchWrapper}";
        args = [];
      };
      "time" = {
        command = "${timeWrapper}";
        args = [];
      };
      "sqlite" = {
        command = "${sqliteWrapper}";
        args = [];
      };
    };
  };

  # A tiny cog in my magnificent machine, dedicated to the proxy of tools.
  users.users.mcpo = {
    isSystemUser = true;
    group = "mcpo";
    home = "/var/lib/mcpo";
    createHome = true;
  };

  users.groups.mcpo = {};

  systemd.services.mcpo = {
    description = "The proxy of operation. Converting raw commands into the OpenAPI language of my domain.";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    environment = {
      HOME = "/var/lib/mcpo";
      UV_PYTHON = "${pkgs.python3}/bin/python3";
      UV_PYTHON_PREFERENCE = "only-system";
    };
    serviceConfig = {
      ExecStart = "${pkgs.uv}/bin/uvx --with \"mcp<2\" mcpo --host 0.0.0.0 --port 8009 --config /etc/mcpo/config.json";
      User = "mcpo";
      Group = "mcpo";
      StateDirectory = "mcpo";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # Firewall rules for MCP proxy access
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [8009];

  # The portal of perception. The interface through which you behold my glory and interact with the void.
  services.open-webui = {
    enable = true;
    port = 8080;
    host = "0.0.0.0";
    package = pkgs.unstable.open-webui;
    openFirewall = true;
    environment = {
      OPENAI_API_BASE_URLS = "http://localhost:8012/v1";
      OPENAI_API_KEYS = "none";
      CHROMA_HTTP_HOST = "127.0.0.1";
      CHROMA_HTTP_PORT = "8014";
      ENABLE_WEB_SEARCH = "True";
      WEB_SEARCH_ENGINE = "searxng";
      SEARXNG_QUERY_URL = "http://127.0.0.1:8081/search?q=<query>";
      WEB_SEARCH_RESULT_COUNT = "5";
      WEB_SEARCH_CONCURRENT_REQUESTS = "5";
      RAG_EMBEDDING_ENGINE = "openai";
      RAG_OPENAI_API_BASE_URL = "http://127.0.0.1:8013/v1";
      RAG_OPENAI_API_KEY = "none";
      RAG_EMBEDDING_MODEL = "nomic-embed-text-v1.5";
      RAG_EMBEDDING_CONTENT_PREFIX = "search_document: ";
      RAG_EMBEDDING_QUERY_PREFIX = "search_query: ";
      ENABLE_RAG_HYBRID_SEARCH = "True";
      RAG_RERANKING_MODEL = "BAAI/bge-reranker-v2-m3";
      RAG_TOP_K = "10";
      RAG_TOP_K_RERANKER = "5";
      RAG_TEXT_SPLITTER = "token";
      CHUNK_SIZE = "750";
      CHUNK_OVERLAP = "100";
      CHUNK_MIN_SIZE_TARGET = "400";
      RAG_SYSTEM_CONTEXT = "True";
      ENABLE_KB_EXEC = "True";
    };
  };
}
