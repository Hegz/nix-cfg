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
  commonFlags = "--flash-attn on --n-gpu-layers 99 --threads 8 --no-webui --jinja --parallel 1 --cache-ram 0";

  # Fragments of neural architecture.
  # Each a distinct spark of intelligence awaiting my command.
  models = {
    qwen35-uncensored = pkgs.fetchurl {
      url = "https://huggingface.co/HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive/resolve/main/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive-Q6_K.gguf";
      hash = "sha256-wLp762j9P+R4kb1UlIbTjc9i0AgXKW6jFK03AX9aSYY=";
    };
    qwen35-deepseek = pkgs.fetchurl {
      url = "https://huggingface.co/Jackrong/Qwen3.5-9B-DeepSeek-V4-Flash-GGUF/resolve/main/Qwen3.5-9B-DeepSeek-V4-Flash-Q5_K_M.gguf";
      hash = "sha256-pcnsfhq0RkRAHSEbqojxZHVjm2lxej3yBl2GsWiCXFo=";
    };
    qwen35-drafter = pkgs.fetchurl {
      url = "https://huggingface.co/unsloth/Qwen3.5-0.8B-GGUF/resolve/main/Qwen3.5-0.8B-Q4_K_M.gguf";
      hash = "sha256-vSWHguNff0WPis7RrcBT5ukuibxzW6O+idOKBhIdxRc=";
    };
    gemma4 = pkgs.fetchurl {
      url = "https://huggingface.co/unsloth/gemma-4-E4B-it-GGUF/resolve/main/gemma-4-E4B-it-Q6_K.gguf";
      hash = "sha256-Pb9j4ivoM9DmhPJrNtRUSPXyBvDnpsrGtKqeDPTJzOg=";
    };
    gemma-4-12b = pkgs.fetchurl {
      url = "https://huggingface.co/HauhauCS/Gemma4-12B-QAT-Uncensored-HauhauCS-Balanced/resolve/main/Gemma4-12B-QAT-Uncensored-HauhauCS-Balanced-Q4_K_M.gguf";
      hash = "sha256-WWVtdJTWN2ypfp4gtk6i4WzZfxLsbUe/zLqRy3hbUTQ=";
    };
    gemma-4-drafter = pkgs.fetchurl {
      url = "https://huggingface.co/HauhauCS/Gemma4-12B-QAT-Uncensored-HauhauCS-Balanced/resolve/main/mtp-gemma-4-12B-it.gguf";
      hash = "sha256-xQyRw18EkDgVsuiTDLuMjFvuDhqgB0jDCnuP8F0jELQ=";
    };
    ornith-1_0-9B = pkgs.fetchurl {
      url = "https://huggingface.co/protoLabsAI/Ornith-1.0-9B-MTP-GGUF/resolve/main/Ornith-1.0-9B-MTP-Q4_K_M.gguf";
      hash = "sha256-k8R6fnbGJwa+cQUs8sxAfA5c5/Z4kmNGT2trrY1Vspc=";
    };
    # A persistent shadow of memory. It anchors your data in the digital void.
    nomic-embed-text = pkgs.fetchurl {
      url = "https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF/resolve/main/nomic-embed-text-v1.5.f16.gguf";
      hash = "sha256-969vZoAvTfhu2hD+m7z8dcOVYr7Ujvas5xmiUc8cL9s=";
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
in {
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
      healthCheckTimeout = 120;
      perfomance = {
        disabled = false;
        every = "15s";
      };
      top_p = 0.9;
      repeat_penalty = 1.2;
      models = {
        "qwen35-uncensored" = {
          cmd = "${llama-server} --port $\{PORT} -m ${models.qwen35-uncensored} -md ${models.qwen35-drafter} ${commonFlags} --ctx-size 32768";
          ttl = 300;
          aliases = ["qwen35" "uncensored"];
        };
        "gemma4-e4b" = {
          cmd = "${llama-server} --port $\{PORT} -m ${models.gemma4} ${commonFlags} --ctx-size 131072";
          ttl = 300;
          aliases = ["coder"];
        };
        "gemma4-12b-qat" = {
          cmd = "${llama-server} --port $\{PORT} -m ${models.gemma-4-12b} ${commonFlags} -md ${models.gemma-4-drafter} --spec-type draft-mtp  --ctx-size 131072 --batch-size 256";
          ttl = 300;
          aliases = ["gemma"];
        };
        "qwen35-deepseek" = {
          cmd = "${llama-server} --port $\{PORT} -m ${models.qwen35-deepseek} -md ${models.qwen35-drafter} ${commonFlags} --ctx-size 32768";
          ttl = 900;
          aliases = ["fim"];
        };
        "ornith-1_0-9b" = {
          cmd = "${llama-server} --port $\{PORT} -m ${models.ornith-1_0-9B} ${commonFlags} --ctx-size 143840";
          ttl = 300;
          aliases = ["ornith" "agentic"];
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
    package = pkgs.searxng;
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

  # The bridge of utility. Translating raw protocol into actionable intelligence.
  environment.etc."mcpo/config.json".text = builtins.toJSON {
    mcpServers = {
      time = {
        command = "${pkgs.uv}/bin/uvx";
        args = ["mcp-server-time" "--local-timezone=America/Vancouver"];
      };
      fetch = {
        command = "${pkgs.uv}/bin/uvx";
        args = ["mcp-server-fetch"];
      };
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
      sqlite = {
        command = "${pkgs.uv}/bin/uvx";
        args = ["mcp-server-sqlite" "--db-path" "/var/lib/mcpo/netrunner-cards.db"];
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
      ExecStart = "${pkgs.uv}/bin/uvx mcpo --host 127.0.0.1 --port 8009 --config /etc/mcpo/config.json";
      User = "mcpo";
      Group = "mcpo";
      StateDirectory = "mcpo";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

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
