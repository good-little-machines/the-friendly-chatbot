{ config, pkgs, ... }:

let
  appHost = "127.0.0.1";
  appPort = config.processes.laravel.ports.http.value;
  vitePort = config.processes.vite.ports.http.value;
  postgresPort = config.processes.postgres.ports.main.value;
  redisPort = config.processes.redis.ports.main.value;
  mailpitSmtpPort = config.processes.mailpit.ports.smtp.value;
  mailpitUiPort = config.processes.mailpit.ports.ui.value;
  runtimeEnv = {
    APP_URL = "http://${appHost}:${toString appPort}";

    DB_CONNECTION = "pgsql";
    DB_HOST = appHost;
    DB_PORT = toString postgresPort;
    DB_DATABASE = "laravel";
    DB_USERNAME = "laravel";
    DB_PASSWORD = "laravel";

    CACHE_STORE = "redis";
    QUEUE_CONNECTION = "redis";
    REDIS_CLIENT = "phpredis";
    REDIS_HOST = appHost;
    REDIS_PORT = toString redisPort;

    MAIL_MAILER = "smtp";
    MAIL_HOST = appHost;
    MAIL_PORT = toString mailpitSmtpPort;
    MAIL_USERNAME = "null";
    MAIL_PASSWORD = "null";
  };
  syncEnvScript = ''
    set -euo pipefail

    if [[ ! -f composer.json || ! -f .env.example ]]; then
      echo "Run setup from the repository root." >&2
      exit 1
    fi

    if [[ ! -f .env ]]; then
      cp .env.example .env
    fi

    set_env_value() {
      local key="$1"
      local value="$2"

      if grep --quiet "^''${key}=" .env; then
        sed --in-place "s|^''${key}=.*|''${key}=''${value}|" .env
      else
        printf '\n%s=%s\n' "$key" "$value" >> .env
      fi
    }

    set_env_value APP_URL "http://${appHost}:${toString appPort}"
    set_env_value DB_CONNECTION "pgsql"
    set_env_value DB_HOST "${appHost}"
    set_env_value DB_PORT "${toString postgresPort}"
    set_env_value DB_DATABASE "laravel"
    set_env_value DB_USERNAME "laravel"
    set_env_value DB_PASSWORD "laravel"
    set_env_value CACHE_STORE "redis"
    set_env_value QUEUE_CONNECTION "redis"
    set_env_value REDIS_CLIENT "phpredis"
    set_env_value REDIS_HOST "${appHost}"
    set_env_value REDIS_PORT "${toString redisPort}"
    set_env_value MAIL_MAILER "smtp"
    set_env_value MAIL_HOST "${appHost}"
    set_env_value MAIL_PORT "${toString mailpitSmtpPort}"
    set_env_value MAIL_USERNAME "null"
    set_env_value MAIL_PASSWORD "null"
  '';
  setupScript = ''
    set -euo pipefail

    if [[ ! -f package-lock.json ]]; then
      echo "Run setup from the repository root." >&2
      exit 1
    fi

    ${syncEnvScript}

    echo "Installing Composer dependencies..."
    composer install --no-interaction

    if ! grep --quiet --extended-regexp '^APP_KEY=base64:.+' .env; then
      php artisan key:generate --force --no-interaction
    fi

    echo "Running PostgreSQL migrations..."
    php artisan migrate --force --no-interaction

    echo "Installing Node dependencies..."
    npm ci
    npm run build

    echo
    echo "Setup complete. Run 'devenv up' to start the full development stack."
  '';
in
{
  dotenv.disableHint = true;

  languages.php = {
    enable = true;
    version = "8.5";
    extensions = [
      "bcmath"
      "intl"
      "mbstring"
      "pcntl"
      "pdo_pgsql"
      "redis"
    ];
    ini = ''
      memory_limit = 512M
    '';
    lsp.enable = false;
  };

  languages.javascript = {
    enable = true;
    package = pkgs.nodejs_24;
    npm.enable = true;
  };

  services.postgres = {
    enable = true;
    package = pkgs.postgresql_18;
    listen_addresses = appHost;
    port = 5432;
    initialDatabases = [
      {
        name = "laravel";
        user = "laravel";
        pass = "laravel";
      }
    ];
  };

  services.redis = {
    enable = true;
    bind = appHost;
    port = 6379;
  };

  services.mailpit = {
    enable = true;
    smtpListenAddress = "${appHost}:1025";
    uiListenAddress = "${appHost}:8025";
  };

  processes = {
    laravel = {
      env = runtimeEnv;
      exec = "php artisan serve --host=${appHost} --port=${toString appPort}";
      ports.http.allocate = 8080;
      after = [ "devenv:processes:postgres" ];
      ready.http.get = {
        host = appHost;
        port = appPort;
        path = "/";
      };
    };

    vite = {
      env = runtimeEnv;
      exec = "npm run dev -- --host=${appHost} --port=${toString vitePort} --strictPort";
      ports.http.allocate = 5174;
    };

    queue = {
      env = runtimeEnv;
      exec = "php artisan queue:work --sleep=1 --tries=1";
      after = [
        "devenv:processes:postgres"
        "devenv:processes:redis"
      ];
    };

    scheduler = {
      env = runtimeEnv;
      exec = "php artisan schedule:work";
      after = [ "devenv:processes:postgres" ];
    };
  };

  tasks = {
    "app:sync-env" = {
      description = "Synchronize Laravel environment values with allocated devenv ports";
      exec = syncEnvScript;
      env = runtimeEnv;
      before = [
        "devenv:processes:laravel"
        "devenv:processes:vite"
        "devenv:processes:queue"
        "devenv:processes:scheduler"
      ];
    };

    "app:setup" = {
      description = "Initialize the Laravel application for devenv";
      exec = setupScript;
      env = runtimeEnv;
      after = [ "devenv:processes:postgres" ];
    };
  };

  scripts = {
    setup = {
      description = "Initialize the Laravel application and local database";
      exec = ''
        set -euo pipefail

        process_manager_was_running=false
        postgres_was_running=false

        if devenv processes list >/dev/null 2>&1; then
          process_manager_was_running=true
        fi

        if devenv processes list 2>/dev/null | \
          grep --quiet --extended-regexp '^postgres[[:space:]]+(starting|running|ready)([[:space:]]|$)'; then
          postgres_was_running=true
        fi

        stop_temporary_postgres() {
          if [[ "$postgres_was_running" == false ]]; then
            devenv processes stop postgres >/dev/null 2>&1 || true
          fi

          if [[ "$process_manager_was_running" == false ]]; then
            devenv down >/dev/null 2>&1 || true
          fi
        }

        trap stop_temporary_postgres EXIT
        devenv processes start postgres
        devenv tasks run --mode single app:setup
      '';
    };

    fresh = {
      description = "Rebuild and seed the local PostgreSQL database";
      exec = "php artisan migrate:fresh --seed";
    };

    test = {
      description = "Run the application test suite";
      exec = "php artisan test --compact";
    };

    status = {
      description = "Show service endpoints and process status";
      exec = ''
        set -u

        process_listing="$(devenv processes list 2>/dev/null || true)"

        process_line() {
          local process_name="$1"
          local line

          while IFS= read -r line; do
            if [[ "$line" == "$process_name "* ]]; then
              printf '%s' "$line"
              return
            fi
          done <<< "$process_listing"
        }

        process_state() {
          local line
          local name
          local state
          local remainder

          line="$(process_line "$1")"

          if [[ -z "$line" ]]; then
            printf '%s' "not_running"
            return
          fi

          read -r name state remainder <<< "$line"
          printf '%s' "$state"
        }

        process_port() {
          local line
          local pattern

          line="$(process_line "$1")"
          pattern="$2:([0-9]+)"

          if [[ "$line" =~ $pattern ]]; then
            printf '%s' "''${BASH_REMATCH[1]}"
          else
            printf '%s' "$3"
          fi
        }

        app_port="$(process_port laravel http ${toString appPort})"
        vite_port="$(process_port vite http ${toString vitePort})"
        mailpit_smtp_port="$(process_port mailpit smtp ${toString mailpitSmtpPort})"
        mailpit_ui_port="$(process_port mailpit ui ${toString mailpitUiPort})"
        postgres_port="$(process_port postgres main ${toString postgresPort})"
        redis_port="$(process_port redis main ${toString redisPort})"

        printf '%-16s %-14s %s\n' "Service" "State" "Endpoint"
        printf '%-16s %-14s %s\n' "Laravel" "$(process_state laravel)" "http://${appHost}:$app_port"
        printf '%-16s %-14s %s\n' "Vite" "$(process_state vite)" "http://${appHost}:$vite_port"
        printf '%-16s %-14s %s\n' "Mailpit UI" "$(process_state mailpit)" "http://${appHost}:$mailpit_ui_port"
        printf '%-16s %-14s %s\n' "Mailpit SMTP" "$(process_state mailpit)" "smtp://${appHost}:$mailpit_smtp_port"
        printf '%-16s %-14s %s\n' "PostgreSQL" "$(process_state postgres)" "postgresql://${appHost}:$postgres_port/laravel"
        printf '%-16s %-14s %s\n' "Redis" "$(process_state redis)" "redis://${appHost}:$redis_port"
        printf '%-16s %-14s %s\n' "Queue" "$(process_state queue)" "-"
        printf '%-16s %-14s %s\n' "Scheduler" "$(process_state scheduler)" "-"

        if [[ -z "$process_listing" ]]; then
          echo
          echo "No devenv process manager is running. Start it with 'devenv up'."
        fi
      '';
    };
  };

  enterShell = ''
    echo "Run 'devenv up' to start the development stack."
    echo "Run 'status' to see process states and resolved service endpoints."
  '';
}
