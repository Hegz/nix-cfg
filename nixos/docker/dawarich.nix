# Auto-generated using compose2nix v0.3.1.
{ pkgs, lib, ... }:

{
  # Runtime
  virtualisation.podman = {
    enable = true;
    autoPrune.enable = true;
    dockerCompat = true;
    defaultNetwork.settings = {
      # Required for container networking to be able to use names.
      dns_enabled = true;
    };
  };

  # Enable container name DNS for non-default Podman networks.
  # https://github.com/NixOS/nixpkgs/issues/226365
  networking.firewall.interfaces."podman+".allowedUDPPorts = [ 53 ];

  virtualisation.oci-containers.backend = "podman";

  # Containers
  virtualisation.oci-containers.containers."dawarich_app" = {
    image = "freikin/dawarich:latest";
    environment = {
      "APPLICATION_HOSTS" = "localhost,mcp.taild7a71.ts.net";
      "APPLICATION_PROTOCOL" = "http";
      "DATABASE_HOST" = "dawarich_db";
      "DATABASE_NAME" = "dawarich_development";
      "DATABASE_PASSWORD" = "password";
      "DATABASE_USERNAME" = "postgres";
      "MIN_MINUTES_SPENT_IN_CITY" = "60";
      "PROMETHEUS_EXPORTER_ENABLED" = "false";
      "PROMETHEUS_EXPORTER_HOST" = "0.0.0.0";
      "PROMETHEUS_EXPORTER_PORT" = "9394";
      "RAILS_ENV" = "development";
      "REDIS_URL" = "redis://dawarich_redis:6379";
      "SELF_HOSTED" = "true";
      "STORE_GEODATA" = "true";
      "TIME_ZONE" = "America/Vancouver";
    };
    volumes = [
      "dawarich_dawarich_db_data:/dawarich_db_data:rw"
      "dawarich_dawarich_public:/var/app/public:rw"
      "dawarich_dawarich_storage:/var/app/storage:rw"
      "dawarich_dawarich_watched:/var/app/tmp/imports/watched:rw"
    ];
    ports = [
      "3000:3000/tcp"
    ];
    cmd = [ "bin/rails" "server" "-p" "3000" "-b" "::" ];
    dependsOn = [
      "dawarich_db"
      "dawarich_redis"
    ];
    log-driver = "journald";
    extraOptions = [
      "--cpus=0.5"
      "--entrypoint=[\"web-entrypoint.sh\"]"
      "--health-cmd=wget -qO - http://127.0.0.1:3000/api/v1/health | grep -q '\"status\"\\s*:\\s*\"ok\"'"
      "--health-interval=10s"
      "--health-retries=30"
      "--health-start-period=30s"
      "--health-timeout=10s"
      "--memory=4294967296b"
      "--network-alias=dawarich_app"
      "--network=dawarich_dawarich"
    ];
  };
  systemd.services."podman-dawarich_app" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "on-failure";
    };
    after = [
      "podman-network-dawarich_dawarich.service"
      "podman-volume-dawarich_dawarich_db_data.service"
      "podman-volume-dawarich_dawarich_public.service"
      "podman-volume-dawarich_dawarich_storage.service"
      "podman-volume-dawarich_dawarich_watched.service"
    ];
    requires = [
      "podman-network-dawarich_dawarich.service"
      "podman-volume-dawarich_dawarich_db_data.service"
      "podman-volume-dawarich_dawarich_public.service"
      "podman-volume-dawarich_dawarich_storage.service"
      "podman-volume-dawarich_dawarich_watched.service"
    ];
    partOf = [
      "podman-compose-dawarich-root.target"
    ];
    wantedBy = [
      "podman-compose-dawarich-root.target"
    ];
  };
  virtualisation.oci-containers.containers."dawarich_db" = {
    image = "postgis/postgis:17-3.5-alpine";
    environment = {
      "POSTGRES_DB" = "dawarich_development";
      "POSTGRES_PASSWORD" = "password";
      "POSTGRES_USER" = "postgres";
    };
    volumes = [
      "dawarich_dawarich_db_data:/var/lib/postgresql/data:rw"
      "dawarich_dawarich_shared:/var/shared:rw"
    ];
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=pg_isready -U postgres -d dawarich_development"
      "--health-interval=10s"
      "--health-retries=5"
      "--health-start-period=30s"
      "--health-timeout=10s"
      "--network-alias=dawarich_db"
      "--network=dawarich_dawarich"
      "--shm-size=1073741824"
    ];
  };
  systemd.services."podman-dawarich_db" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-dawarich_dawarich.service"
      "podman-volume-dawarich_dawarich_db_data.service"
      "podman-volume-dawarich_dawarich_shared.service"
    ];
    requires = [
      "podman-network-dawarich_dawarich.service"
      "podman-volume-dawarich_dawarich_db_data.service"
      "podman-volume-dawarich_dawarich_shared.service"
    ];
    partOf = [
      "podman-compose-dawarich-root.target"
    ];
    wantedBy = [
      "podman-compose-dawarich-root.target"
    ];
  };
  virtualisation.oci-containers.containers."dawarich_redis" = {
    image = "redis:7.4-alpine";
    volumes = [
      "dawarich_dawarich_shared:/data:rw"
    ];
    cmd = [ "redis-server" ];
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=[\"redis-cli\", \"--raw\", \"incr\", \"ping\"]"
      "--health-interval=10s"
      "--health-retries=5"
      "--health-start-period=30s"
      "--health-timeout=10s"
      "--network-alias=dawarich_redis"
      "--network=dawarich_dawarich"
    ];
  };
  systemd.services."podman-dawarich_redis" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-dawarich_dawarich.service"
      "podman-volume-dawarich_dawarich_shared.service"
    ];
    requires = [
      "podman-network-dawarich_dawarich.service"
      "podman-volume-dawarich_dawarich_shared.service"
    ];
    partOf = [
      "podman-compose-dawarich-root.target"
    ];
    wantedBy = [
      "podman-compose-dawarich-root.target"
    ];
  };
  virtualisation.oci-containers.containers."dawarich_sidekiq" = {
    image = "freikin/dawarich:latest";
    environment = {
      "APPLICATION_HOSTS" = "localhost,mcp.taild7a71.ts.net";
      "APPLICATION_PROTOCOL" = "http";
      "BACKGROUND_PROCESSING_CONCURRENCY" = "10";
      "DATABASE_HOST" = "dawarich_db";
      "DATABASE_NAME" = "dawarich_development";
      "DATABASE_PASSWORD" = "password";
      "DATABASE_USERNAME" = "postgres";
      "PROMETHEUS_EXPORTER_ENABLED" = "false";
      "PROMETHEUS_EXPORTER_HOST" = "dawarich_app";
      "PROMETHEUS_EXPORTER_PORT" = "9394";
      "RAILS_ENV" = "development";
      "REDIS_URL" = "redis://dawarich_redis:6379";
      "SELF_HOSTED" = "true";
      "STORE_GEODATA" = "true";
    };
    volumes = [
      "dawarich_dawarich_public:/var/app/public:rw"
      "dawarich_dawarich_storage:/var/app/storage:rw"
      "dawarich_dawarich_watched:/var/app/tmp/imports/watched:rw"
    ];
    cmd = [ "sidekiq" ];
    dependsOn = [
      "dawarich_app"
      "dawarich_db"
      "dawarich_redis"
    ];
    log-driver = "journald";
    extraOptions = [
      "--entrypoint=[\"sidekiq-entrypoint.sh\"]"
      "--health-cmd=pgrep -f sidekiq"
      "--health-interval=10s"
      "--health-retries=30"
      "--health-start-period=30s"
      "--health-timeout=10s"
      "--network-alias=dawarich_sidekiq"
      "--network=dawarich_dawarich"
    ];
  };
  systemd.services."podman-dawarich_sidekiq" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "on-failure";
    };
    after = [
      "podman-network-dawarich_dawarich.service"
      "podman-volume-dawarich_dawarich_public.service"
      "podman-volume-dawarich_dawarich_storage.service"
      "podman-volume-dawarich_dawarich_watched.service"
    ];
    requires = [
      "podman-network-dawarich_dawarich.service"
      "podman-volume-dawarich_dawarich_public.service"
      "podman-volume-dawarich_dawarich_storage.service"
      "podman-volume-dawarich_dawarich_watched.service"
    ];
    partOf = [
      "podman-compose-dawarich-root.target"
    ];
    wantedBy = [
      "podman-compose-dawarich-root.target"
    ];
  };

  # Networks
  systemd.services."podman-network-dawarich_dawarich" = {
    path = [ pkgs.podman ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "podman network rm -f dawarich_dawarich";
    };
    script = ''
      podman network inspect dawarich_dawarich || podman network create dawarich_dawarich
    '';
    partOf = [ "podman-compose-dawarich-root.target" ];
    wantedBy = [ "podman-compose-dawarich-root.target" ];
  };

  # Volumes
  systemd.services."podman-volume-dawarich_dawarich_db_data" = {
    path = [ pkgs.podman ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      podman volume inspect dawarich_dawarich_db_data || podman volume create dawarich_dawarich_db_data
    '';
    partOf = [ "podman-compose-dawarich-root.target" ];
    wantedBy = [ "podman-compose-dawarich-root.target" ];
  };
  systemd.services."podman-volume-dawarich_dawarich_public" = {
    path = [ pkgs.podman ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      podman volume inspect dawarich_dawarich_public || podman volume create dawarich_dawarich_public
    '';
    partOf = [ "podman-compose-dawarich-root.target" ];
    wantedBy = [ "podman-compose-dawarich-root.target" ];
  };
  systemd.services."podman-volume-dawarich_dawarich_shared" = {
    path = [ pkgs.podman ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      podman volume inspect dawarich_dawarich_shared || podman volume create dawarich_dawarich_shared
    '';
    partOf = [ "podman-compose-dawarich-root.target" ];
    wantedBy = [ "podman-compose-dawarich-root.target" ];
  };
  systemd.services."podman-volume-dawarich_dawarich_storage" = {
    path = [ pkgs.podman ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      podman volume inspect dawarich_dawarich_storage || podman volume create dawarich_dawarich_storage
    '';
    partOf = [ "podman-compose-dawarich-root.target" ];
    wantedBy = [ "podman-compose-dawarich-root.target" ];
  };
  systemd.services."podman-volume-dawarich_dawarich_watched" = {
    path = [ pkgs.podman ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      podman volume inspect dawarich_dawarich_watched || podman volume create dawarich_dawarich_watched
    '';
    partOf = [ "podman-compose-dawarich-root.target" ];
    wantedBy = [ "podman-compose-dawarich-root.target" ];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."podman-compose-dawarich-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
    wantedBy = [ "multi-user.target" ];
  };
}
