{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  secrets,
  ...
}: let
  # Define the llama-cpp package once, reused across all model commands
  llama-cpp = pkgs.unstable.llama-cpp.override {cudaSupport = true;};
  llama-server = "${llama-cpp}/bin/llama-server";
  commonFlags = "--n-gpu-layers 99 --threads 8 --no-webui --jinja --parallel 1 --cache-ram 0";

  # Fetch models into the Nix store at build time
  # additional models to try:
  # https://huggingface.co/squ11z1/Mythos-nano
  # https://huggingface.co/squ11z1/Mythos-nano
  # https://huggingface.co/empero-ai/Qwythos-9B-Claude-Mythos-5-1M-GGUF
  # https://huggingface.co/prithivMLmods/VibeThinker-3B-GGUF
  # https://huggingface.co/empero-ai/Qwable-9B-Claude-Fable-5-GGUF
  models = {
    qwen35-uncensored = pkgs.fetchurl {
      url = "https://huggingface.co/HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive/resolve/main/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive-Q6_K.gguf";
      hash = "sha256-wLp762j9P+R4kb1UlIbTjc9i0AgXKW6jFK03AX9aSYY="; # replace with real hash
    };
    gemma4 = pkgs.fetchurl {
      url = "https://huggingface.co/unsloth/gemma-4-E4B-it-GGUF/resolve/main/gemma-4-E4B-it-Q6_K.gguf";
      hash = "sha256-A75pV0BO8kTB++PQggMGOwjXWf7htYMSm0XgtOMau/k=";
    };
    gemma-4-12b-it-Q5_K_M = pkgs.fetchurl {
      url = "https://huggingface.co/unsloth/gemma-4-12b-it-GGUF/resolve/main/gemma-4-12b-it-Q5_K_M.gguf";
      hash = "sha256-CeneDekx4jt8jvwl25YXkcp65MFu+cUvBFKLTC++ZoE=";
    };
    qwen35-deepseek = pkgs.fetchurl {
      url = "https://huggingface.co/Jackrong/Qwen3.5-9B-DeepSeek-V4-Flash-GGUF/resolve/main/Qwen3.5-9B-DeepSeek-V4-Flash-Q5_K_M.gguf";
      hash = "sha256-pcnsfhq0RkRAHSEbqojxZHVjm2lxej3yBl2GsWiCXFo=";
    };

    # Small, dedicated embedding model — kept separate from the chat models above
    # because it runs in its own always-on llama-server instance (see below),
    # not inside llama-swap's single-model rotation.
    nomic-embed-text = pkgs.fetchurl {
      url = "https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF/resolve/main/nomic-embed-text-v1.5.f16.gguf";
      hash = "sha256-969vZoAvTfhu2hD+m7z8dcOVYr7Ujvas5xmiUc8cL9s=";
    };
  };
in {
  # Building more then 1 big thing at a time causes problems.
  nix.settings = {
    max-jobs = 1;
    cores = 8;
  };

  systemd.services.llama-swap.serviceConfig = {
    ProcSubset = lib.mkForce "all";
    ProtectProc = lib.mkForce "default";
  };

  services.llama-swap = {
    enable = true;
    package = pkgs.unstable.llama-swap;
    port = 8012;
    listenAddress = "0.0.0.0";
    openFirewall = true;
    settings = {
      # How long in seconds to wait for a model to load before giving up
      healthCheckTimeout = 120;

      # How long an idle model stays loaded before being swapped out (seconds)
      # This is the key feature of llama-swap — only one model in VRAM at a time
      #
      # NOTE: --jinja is required on every model below for Open WebUI's "Native"
      # function calling (web search, tools, knowledge-base exec) to work at all.
      # Without it, llama-server never parses tool_calls out of the chat template,
      # and Open WebUI's Native Mode tool calls will silently fail for that model.
      models = {
        "qwen35-uncensored" = {
          cmd = "${llama-server} --port $\{PORT} -m ${models.qwen35-uncensored} ${commonFlags} --ctx-size 147456";
          ttl = 300; # unload after 5 minutes of inactivity
          aliases = ["qwen35" "uncensored"];
        };
        "gemma4-e4b" = {
          cmd = "${llama-server} --port $\{PORT} -m ${models.gemma4} ${commonFlags} --ctx-size 131072";
          ttl = 300;
          aliases = ["coder"];
        };
        "gemma4-12b" = {
          cmd = "${llama-server} --port $\{PORT} -m ${models.gemma-4-12b-it-Q5_K_M} ${commonFlags} --ctx-size 131072";
          ttl = 300;
          aliases = ["gemma"];
        };
        "qwen35-deepseek" = {
          cmd = "${llama-server} --port $\{PORT} -m ${models.qwen35-deepseek} ${commonFlags} --ctx-size 163840";
          ttl = 900;
          aliases = ["fim-coder"];
        };
      };
    };
  };

  # ---------------------------------------------------------------------------
  # Dedicated, always-on embedding server.
  #
  # Deliberately NOT part of llama-swap: if it were just another entry in the
  # swap rotation, every RAG-using chat turn would force two extra model
  # swaps (chat model -> embed query -> swap back to chat model), and each
  # swap costs several seconds of reload time. A second tiny llama-server
  # process avoids that thrashing entirely, at the cost of a small fixed
  # amount of RAM/VRAM held permanently.
  #
  # Defaults to CPU (--n-gpu-layers 0) so it never competes with whichever
  # chat model llama-swap currently has loaded in VRAM. If you have spare
  # VRAM, raise --n-gpu-layers to speed up bulk document ingestion.
  # ---------------------------------------------------------------------------
  systemd.services.llama-embeddings = {
    description = "Dedicated llama-server instance for embeddings (always-on)";
    after = ["network.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      ExecStart = "${llama-server} --host 127.0.0.1 --port 8013 -m ${models.nomic-embed-text} --embeddings --n-gpu-layers 0 --ctx-size 2048 --threads 4 --no-webui";
      Restart = "on-failure";
      RestartSec = 5;
      DynamicUser = true;
    };
  };

  # ---------------------------------------------------------------------------
  # SearXNG — self-hosted metasearch backend so Open WebUI's web search tool
  # doesn't depend on an external/commercial search API. Bound to localhost
  # only; Open WebUI is the only consumer.
  #
  # `search.formats = ["html" "json"]` is required — without "json", SearXNG
  # returns 403s to Open WebUI's queries.
  #
  # secret_key is sourced from secrets.json (via the `secrets` specialArg
  # your flake already wires up) rather than a standalone environment file.
  #
  # Worth knowing: because secrets.json is read with builtins.readFile at
  # *evaluation* time, this value gets baked into the rendered settings.yml
  # derivation in /nix/store — which is world-readable by default, same as
  # every other value your flake already pulls from secrets.json. That's a
  # different trade-off than environmentFile (which keeps a secret on disk,
  # outside the store, read only at service start) — fine for a single-admin
  # box, worth knowing if SecUnit or another multi-user host ever imports
  # this module.
  # ---------------------------------------------------------------------------
  services.searx = {
    enable = true;
    package = pkgs.searxng;
    redisCreateLocally = true;
    settings = {
      server = {
        bind_address = "127.0.0.1";
        port = 8081;
        secret_key = secrets.searxngSecret; # add this key to secrets/secrets.json
      };
      search.formats = ["html" "json"];
    };
  };

  # ---------------------------------------------------------------------------
  # mcpo — bridges stdio-based MCP servers into OpenAPI HTTP servers that
  # Open WebUI can call as Tools. Bound to localhost only.
  #
  # CAVEAT: mcpo is not yet packaged in nixpkgs (tracked upstream as
  # NixOS/nixpkgs#409642), so this isn't fully pinned/reproducible the way
  # the rest of this file is — `uvx` fetches it from PyPI at service start
  # and caches it under /var/lib/mcpo. Once you've confirmed your chosen
  # version works, consider pinning with `uvx mcpo==<version>` for
  # repeatability.
  #
  # The MCP servers listed below (time, fetch) are intentionally low-risk
  # examples. A filesystem MCP server is commented out — only enable it if
  # you deliberately want models to read/write a specific directory, and
  # keep the path scoped tightly.
  # ---------------------------------------------------------------------------
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
      # filesystem = {
      #   command = "${pkgs.nodejs}/bin/npx";
      #   args = ["-y" "@modelcontextprotocol/server-filesystem" "/srv/llm-shared"];
      # };
    };
  };

  users.users.mcpo = {
    isSystemUser = true;
    group = "mcpo";
    home = "/var/lib/mcpo";
    createHome = true;
  };
  users.groups.mcpo = {};

  systemd.services.mcpo = {
    description = "mcpo: MCP-to-OpenAPI proxy for Open WebUI tool servers";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    environment = {
      HOME = "/var/lib/mcpo";
      # Forcing the Nix-built interpreter fixed the *first* exec failure
      # (uv's downloaded standalone CPython), but the real problem is
      # broader: DynamicUser's implied hardening (ProtectSystem=strict
      # and friends) blocks executing *anything* freshly written under
      # the service's own StateDirectory — which uv does repeatedly
      # (the tool venv, the mcpo console-script wrapper inside it, etc).
      # Kept these two anyway; they're harmless and avoid a redundant
      # Python download now that we're on a static, unsandboxed user.
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

  # Point Open WebUI at llama-swap instead of (or alongside) Ollama
  services.open-webui = {
    enable = true;
    port = 8080;
    host = "0.0.0.0";
    package = pkgs.unstable.open-webui;
    openFirewall = true;
    environment = {
      OPENAI_API_BASE_URLS = "http://localhost:8012/v1";
      OPENAI_API_KEYS = "none";

      # --- Web search --------------------------------------------------
      ENABLE_WEB_SEARCH = "True";
      WEB_SEARCH_ENGINE = "searxng";
      SEARXNG_QUERY_URL = "http://127.0.0.1:8081/search?q=<query>";
      WEB_SEARCH_RESULT_COUNT = "5";
      WEB_SEARCH_CONCURRENT_REQUESTS = "5";

      # --- RAG: embeddings ----------------------------------------------
      # Routed to the dedicated llama-embeddings service above, not the
      # default in-process CPU SentenceTransformers model.
      # NOTE: RAG_OPENAI_* does NOT inherit from OPENAI_API_* (open-webui
      # issue #22084) — both must be set explicitly even though they point
      # at the same kind of backend as the chat connection above.
      RAG_EMBEDDING_ENGINE = "openai";
      RAG_OPENAI_API_BASE_URL = "http://127.0.0.1:8013/v1";
      RAG_OPENAI_API_KEY = "none";
      RAG_EMBEDDING_MODEL = "nomic-embed-text-v1.5";

      # nomic-embed-text expects task-prefixed input to hit its benchmarked
      # quality: text being indexed should read "search_document: <text>",
      # queries should read "search_query: <text>". llama-server's embeddings
      # endpoint has no idea this model wants that, so Open WebUI has to add
      # it instead. Trailing space in both is intentional — it's part of the
      # prefix format ("search_document: text", not "search_document:text").
      RAG_EMBEDDING_CONTENT_PREFIX = "search_document: ";
      RAG_EMBEDDING_QUERY_PREFIX = "search_query: ";

      # --- RAG: hybrid search + reranking ---------------------------------
      # No RAG_RERANKING_ENGINE set -> defaults to the local CrossEncoder,
      # which downloads this model from Hugging Face on first use and runs
      # on CPU inside the open-webui process (no extra service needed).
      ENABLE_RAG_HYBRID_SEARCH = "True";
      RAG_RERANKING_MODEL = "BAAI/bge-reranker-v2-m3";
      RAG_TOP_K = "10";
      RAG_TOP_K_RERANKER = "5";

      # --- RAG: chunking ---------------------------------------------------
      RAG_TEXT_SPLITTER = "token";
      CHUNK_SIZE = "750";
      CHUNK_OVERLAP = "100";
      CHUNK_MIN_SIZE_TARGET = "400"; # merges tiny fragments from header splitting

      # Keeps retrieved context out of the per-turn prompt prefix so
      # llama-server's KV cache can be reused across turns in a chat.
      RAG_SYSTEM_CONTEXT = "True";

      # Filesystem-style ls/grep/cat access over knowledge bases.
      # Only takes effect once a model is on Native function calling
      # (see the setup guide — that part is UI-only, not an env var).
      ENABLE_KB_EXEC = "True";
    };
  };
}
