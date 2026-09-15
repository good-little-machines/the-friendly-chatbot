# The Friendly Chatbot

This Laravel application uses [devenv](https://devenv.sh/) for a reproducible
local development environment. Entering the repository automatically activates
the environment through direnv.

## Included tools and services

- PHP 8.5 with Composer and the application extensions
- PostgreSQL 18
- Node.js 24 with npm
- Redis
- Mailpit
- Laravel HTTP server, Vite, queue worker, and scheduler processes

## Prerequisites

Install the following tools before setting up the project:

- [Nix](https://nixos.org/download/)
- [devenv](https://devenv.sh/getting-started/) 2.3.1 or newer
- [direnv](https://direnv.net/) with its shell hook enabled

## First-time setup

Clone the repository and enter it:

```sh
cd ~/Sites/the-friendly-chatbot
```

Approve the repository's `.envrc` the first time direnv prompts you:

```sh
direnv allow
```

The environment will subsequently load and unload automatically as you enter
and leave the directory. Tools and AI assistants launched from an activated
shell inherit the project-specific package versions.

Initialize the application:

```sh
setup
```

The setup command:

1. Creates `.env` from `.env.example` when necessary.
2. Configures Laravel to use the devenv PostgreSQL, Redis, and Mailpit services.
3. Installs Composer dependencies and generates an application key when needed.
4. Runs database migrations.
5. Installs Node dependencies and builds the frontend assets.

Without direnv, enter the environment manually before running setup:

```sh
devenv shell
setup
```

## Running the project

Start the complete development stack in the foreground:

```sh
devenv up
```

Start it in the background instead:

```sh
devenv up -d
```

Stop a background stack with:

```sh
devenv down
```

The default service endpoints are:

| Service | Default endpoint |
| --- | --- |
| Laravel | `http://127.0.0.1:8080` |
| Vite | `http://127.0.0.1:5174` |
| Mailpit web UI | `http://127.0.0.1:8025` |
| Mailpit SMTP | `smtp://127.0.0.1:1025` |
| PostgreSQL | `postgresql://127.0.0.1:5432/laravel` |
| Redis | `redis://127.0.0.1:6379` |

If a default port is occupied, devenv automatically tries each successive port
until it finds one that is available. Use the status command to see the resolved
endpoints and current process state:

```sh
status
```

If the current shell is not activated through direnv, use:

```sh
devenv shell -- status
```

## Useful commands

| Command | Purpose |
| --- | --- |
| `setup` | Initialize dependencies, environment settings, database, and assets |
| `devenv up` | Start and attach to the complete process stack |
| `devenv up -d` | Start the complete process stack in the background |
| `devenv down` | Stop the process stack |
| `status` | Show resolved service endpoints and process state |
| `devenv processes logs laravel` | Show recent Laravel process logs |
| `devenv processes restart laravel` | Restart the Laravel process |
| `fresh` | Rebuild and seed the PostgreSQL database |
| `test` | Run the Laravel test suite |

Run `devenv processes --help` to see the complete process-management command
set.
