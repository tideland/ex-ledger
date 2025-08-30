# Tideland Ledger - Deployment Design

## 1. Overview

This document describes the deployment strategy for Tideland Ledger following Elixir/OTP standards and Hex package management conventions. The application will be distributed as both a Hex package and as deployable releases.

## 2. Package Information

### 2.1 Hex Package Details

- **Package Name**: tideland-ledger
- **Organization**: Tideland
- **Repository**: https://github.com/tideland/ex-ledger
- **License**: BSD
- **Hex URL**: https://hex.pm/packages/tideland-ledger

### 2.2 Version Strategy

- Follow Semantic Versioning (SemVer)
- Format: MAJOR.MINOR.PATCH (e.g., 1.0.0)
- Pre-release versions: 0.x.x during development

## 3. Repository Structure

### 3.1 GitHub Repository

```
tideland/ex-ledger/
├── .github/
│   └── workflows/
│       ├── ci.yml          # Continuous Integration
│       └── release.yml     # Release automation
├── config/                 # Configuration files
├── lib/                    # Source code
├── priv/                   # Private application files
├── test/                   # Test files
├── .formatter.exs          # Elixir formatter config
├── .gitignore
├── CHANGELOG.md           # Version history
├── LICENSE                # License file
├── README.md              # Project documentation
├── mix.exs                # Project definition
└── mix.lock               # Dependency lock file
```

### 3.2 Naming Convention

- Repository prefix: `ex-` for Elixir projects
- Package name: `tideland-ledger` (without prefix)
- Module namespace: `Ledger`

## 4. Mix Configuration

### 4.1 mix.exs Structure

```elixir
defmodule Ledger.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/tideland/ex-ledger"

  def project do
    [
      app: :ledger,
      version: @version,
      elixir: "~> 1.14",
      name: "Tideland Ledger",
      description: description(),
      package: package(),
      docs: docs(),
      source_url: @source_url,
      homepage_url: "https://tideland.github.io/ex-ledger",
      deps: deps(),
      aliases: aliases(),
      releases: releases()
    ]
  end

  defp description do
    "A double-entry bookkeeping system with German tax support"
  end

  defp package do
    [
      name: "tideland-ledger",
      licenses: ["BSD"],
      maintainers: ["Frank Mueller"],
      links: %{
        "GitHub" => @source_url,
        "Tideland" => "https://github.com/tideland"
      },
      files: ~w(lib priv config .formatter.exs mix.exs README* LICENSE* CHANGELOG*)
    ]
  end

  defp releases do
    [
      ledger: [
        include_executables_for: [:unix],
        applications: [runtime_tools: :permanent],
        strip_beams: true,
        config_providers: [
          {Toml.Provider, path: "/etc/ledger/config.toml"}
        ]
      ]
    ]
  end
end
```

## 5. Configuration Management

### 5.1 Configuration Sources

1. **Compile-time config**: `config/config.exs`
2. **Runtime config**: `config/runtime.exs`
3. **External TOML**: `/etc/ledger/config.toml` or `./config.toml`

### 5.2 TOML Configuration Provider

```elixir
# Custom configuration provider for TOML files
defmodule Ledger.Config.TomlProvider do
  @behaviour Config.Provider

  def init(path), do: path

  def load(config, path) do
    # Load and merge TOML configuration
    {:ok, toml} = Toml.decode_file(path)
    Config.Reader.merge(config, ledger: toml)
  end
end
```

### 5.3 Configuration Locations

- **Development**: `./config.toml`
- **Production Linux**: `/etc/ledger/config.toml`
- **Production Windows**: `%PROGRAMDATA%\Ledger\config.toml`
- **User override**: `~/.ledger/config.toml`

## 6. Release Strategy

### 6.1 Mix Release

Using Elixir's built-in release mechanism:

```bash
# Build release
MIX_ENV=prod mix release

# Output location
_build/prod/rel/ledger/
```

### 6.2 Release Contents

```
ledger/
├── bin/
│   ├── ledger         # Start script
│   ├── ledger.bat     # Windows start script
│   └── ledger_ctl     # Control script
├── lib/               # Compiled BEAM files
├── releases/
│   └── 0.1.0/
│       ├── env.sh     # Environment setup
│       ├── vm.args    # VM arguments
│       └── config.toml.example
└── erts-*/            # Erlang runtime (optional)
```

### 6.3 Deployment Commands

```bash
# Start application
./bin/ledger start

# Start as daemon
./bin/ledger daemon

# Stop application
./bin/ledger stop

# Remote console
./bin/ledger remote

# Database migration
./bin/ledger eval "Ledger.Release.migrate()"
```

## 7. Database Deployment

### 7.1 SQLite Database Location

- **Development**: `./ledger_dev.db`
- **Test**: `./ledger_test.db`
- **Production**: Configurable via TOML
  - Default: `/var/lib/ledger/ledger.db`
  - Windows: `%PROGRAMDATA%\Ledger\ledger.db`

### 7.2 Migration Strategy

```elixir
defmodule Ledger.Release do
  @app :ledger

  def migrate do
    load_app()
    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end
end
```

## 8. Systemd Integration

### 8.1 Service File

Location: `/etc/systemd/system/ledger.service`

```ini
[Unit]
Description=Tideland Ledger Service
After=network.target

[Service]
Type=notify
User=ledger
Group=ledger
Restart=on-failure
RestartSec=5
Environment=MIX_ENV=prod
Environment=PORT=4000
WorkingDirectory=/opt/ledger
ExecStart=/opt/ledger/bin/ledger start
ExecStop=/opt/ledger/bin/ledger stop

[Install]
WantedBy=multi-user.target
```

### 8.2 Installation Steps

```bash
# Create system user
sudo useradd -r -s /bin/false ledger

# Create directories
sudo mkdir -p /opt/ledger /var/lib/ledger /etc/ledger

# Set permissions
sudo chown -R ledger:ledger /opt/ledger /var/lib/ledger

# Install service
sudo systemctl enable ledger.service
sudo systemctl start ledger.service
```

## 9. Docker Deployment

### 9.1 Dockerfile Structure

```dockerfile
# Build stage
FROM elixir:1.14-alpine AS build
# ... build steps ...

# Release stage
FROM alpine:3.18
RUN apk add --no-cache openssl ncurses-libs sqlite-libs
COPY --from=build /app/_build/prod/rel/ledger ./
CMD ["bin/ledger", "start"]
```

### 9.2 Docker Compose

```yaml
version: "3.8"
services:
  ledger:
    image: tideland/ledger:latest
    ports:
      - "4000:4000"
    volumes:
      - ./config.toml:/app/config.toml:ro
      - ledger-data:/var/lib/ledger
    environment:
      - DATABASE_PATH=/var/lib/ledger/ledger.db

volumes:
  ledger-data:
```

## 10. Publishing to Hex

### 10.1 Pre-publish Checklist

1. Update version in `mix.exs`
2. Update `CHANGELOG.md`
3. Run tests: `mix test`
4. Check formatting: `mix format --check-formatted`
5. Run dialyzer: `mix dialyzer`
6. Generate docs: `mix docs`

### 10.2 Publishing Process

```bash
# Login to Hex (first time)
mix hex.user register

# Publish package
mix hex.publish

# Publish documentation
mix hex.publish docs
```

### 10.3 Version Tags

```bash
# Tag release in git
git tag -a v0.1.0 -m "Release version 0.1.0"
git push origin v0.1.0
```

## 11. Distribution Channels

### 11.1 Binary Releases

- GitHub Releases with pre-built binaries
- Platform-specific packages:
  - `.deb` for Debian/Ubuntu
  - `.rpm` for RedHat/Fedora
  - `.msi` for Windows

### 11.2 Installation Methods

```bash
# Via Hex (as dependency)
{:tideland_ledger, "~> 0.1.0"}

# Via escript (standalone)
mix escript.install hex tideland_ledger

# Via OS package manager
apt install tideland-ledger
```

## 12. Monitoring and Logging

### 12.1 Log Configuration

```elixir
config :logger,
  backends: [:console, {LoggerFileBackend, :file_log}]

config :logger, :file_log,
  path: "/var/log/ledger/ledger.log",
  level: :info,
  format: "$time $metadata[$level] $message\n",
  rotate: %{max_bytes: 10_485_760, keep: 5}
```

### 12.2 Health Check Endpoint

- Path: `/health`
- Returns: JSON with system status
- Used by: Load balancers, monitoring systems

## 13. Backup and Recovery

### 13.1 Backup Strategy

- SQLite database files can be copied directly
- Scheduled backups via cron or systemd timers
- Backup location configurable via TOML

### 13.2 Backup Script

```bash
#!/bin/bash
# /opt/ledger/bin/backup.sh
BACKUP_DIR="/var/backups/ledger"
DB_PATH="/var/lib/ledger/ledger.db"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

sqlite3 "$DB_PATH" ".backup $BACKUP_DIR/ledger_$TIMESTAMP.db"
find "$BACKUP_DIR" -name "ledger_*.db" -mtime +30 -delete
```

## 14. Security Considerations

### 14.1 File Permissions

- Configuration files: 640 (readable by app user/group)
- Database files: 660 (read/write by app user/group)
- Log files: 640
- Backup files: 600

### 14.2 Network Security

- Bind to localhost by default
- Use reverse proxy (nginx) for SSL/TLS
- Configure firewall rules appropriately

## 15. Development to Production Workflow

### 15.1 Development

```bash
mix deps.get
mix ecto.create
mix phx.server
```

### 15.2 Staging

```bash
MIX_ENV=prod mix compile
MIX_ENV=prod mix release
./test_release.sh
```

### 15.3 Production

```bash
# Build on CI/CD
mix hex.publish
# Deploy via chosen method
ansible-playbook deploy.yml
```
