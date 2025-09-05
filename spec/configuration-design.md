# Tideland Ledger - Configuration Design

## Overview

This document describes the configuration system for the Tideland Ledger application. The configuration uses TOML format for human readability and supports both compile-time and runtime configuration with environment-specific overrides.

**Important**: This document covers application-level configuration only. BEAM/Erlang VM configuration is handled separately through `vm.args` and environment variables.

## Configuration Strategy

### Principles

1. **Secure by default**: Sensitive values never stored in code
2. **Environment-aware**: Different settings for dev/test/prod
3. **Runtime configurable**: Key settings can change without recompilation
4. **Validated**: Configuration is validated at startup
5. **Documented**: All options have clear documentation

### Configuration Sources (Priority Order)

1. **Environment variables** (highest priority)
2. **External TOML file** (runtime configuration)
3. **Elixir config files** (compile-time defaults)
4. **Application defaults** (lowest priority)

## TOML Configuration File

### File Locations

- **Development**: `./config.toml` or `./priv/config.toml`
- **Test**: `./config/test.toml`
- **Production Linux**: `/etc/ledger/config.toml`
- **Production Windows**: `%PROGRAMDATA%\Ledger\config.toml`
- **User override**: `~/.ledger/config.toml` (optional)

### Complete Application Configuration Example

```toml
# Tideland Ledger Application Configuration
# This file contains runtime configuration for the ledger application only
# BEAM/VM configuration is handled separately in vm.args

[application]
# Server configuration
host = "127.0.0.1"
port = 4000
url = "https://ledger.example.com"  # External URL for links

# Security settings
secret_key_base = ""  # Required in production, auto-generated in dev

# Session configuration
session_timeout = 3600  # seconds (1 hour)

[database]
# Database configuration
database = "./priv/ledger.db"  # Path to SQLite database

[auth]
# Password requirements
password_min_length = 12
password_require_uppercase = true
password_require_lowercase = true
password_require_numbers = true
password_require_special = false

# Session configuration
session_timeout_minutes = 30
session_sliding_expiration = true
session_single_per_user = false

# Security settings
max_failed_attempts = 5
lockout_duration_minutes = 15
force_password_change_on_first_login = true

# Hashing algorithm: "argon2" or "bcrypt"
password_algorithm = "argon2"

# Initial admin account (only used on first run)
admin_password = ""  # If empty, generates random password

[ui]
# User interface configuration
theme = "light"  # "light", "dark", or "auto"
language = "de"  # Default language: "de" or "en"
date_format = "DD.MM.YYYY"
time_format = "HH:mm"
timezone = "Europe/Berlin"

# Branding
application_name = "Tideland Ledger"
logo_path = ""  # Path to custom logo file

# CSS/Styling (simple color customization)
primary_color = "#1a1a1a"
secondary_color = "#4a5568"
accent_color = "#3182ce"
background_color = "#ffffff"
text_color = "#1a202c"
border_color = "#e2e8f0"
success_color = "#48bb78"
warning_color = "#ed8936"
error_color = "#e53e3e"

# UI Features
show_account_codes = true

[locale]
# Localization settings
default_locale = "de_DE"
available_locales = ["de_DE", "en_US"]

# Number formats
decimal_separator = ","
thousands_separator = "."
currency_symbol = "€"
currency_position = "after"  # "before" or "after"

[accounts]
# Chart of accounts settings
hierarchy_separator = " : "  # Separator for hierarchical accounts
max_depth = 6  # Maximum nesting levels for account hierarchy
recent_transaction_days = 30  # Days to check for recent transactions when deactivating

# Note: The ledger system does not enforce account types.
# Account interpretation is based on the account hierarchy and naming

[amount]
# Amount and currency settings
default_currency = "EUR"
precision = 2  # Decimal places
rounding_mode = "half_even"  # Banker's rounding

[transactions]
# Transaction settings
auto_reference = true  # Auto-generate reference numbers
void_requires_reason = true
allow_backdated = true  # Allow transactions in the past
max_backdate_days = 365  # Maximum days a transaction can be backdated
max_positions = 100  # Maximum positions per transaction


[periods]
# Period closing configuration
closing_enabled = true
closable_types = ["month", "quarter", "year"]
allow_admin_bypass = true  # Admins can post to closed periods

[import]
# CSV import settings
csv_delimiter = ";"
csv_date_format = "DD.MM.YYYY"
max_file_size = 10485760  # 10 MB in bytes
batch_size = 100  # Records processed per batch

[export]
# Export settings
formats = ["csv", "json"]  # Supported export formats
csv_delimiter = ";"
csv_encoding = "UTF-8"
include_inactive_accounts = false

[backup]
# Backup configuration
enabled = true
backup_path = "./backups"
retention_days = 30

[logging]
# Logging configuration
level = "info"  # "debug", "info", "warn", "error"
file = "./logs/ledger.log"

[audit]
# Audit trail settings (required for compliance)
enabled = true
retention_days = 2555  # ~7 years for tax compliance




```

## Simplified Configuration Philosophy

The configuration has been intentionally kept minimal, focusing only on essential settings:

1. **No Over-Engineering**: Only settings that users actually need to change
2. **Convention Over Configuration**: Many values use sensible defaults
3. **Security Focused**: Only security-critical settings exposed (like secret_key_base)
4. **Business Logic Not Configurable**: Core accounting rules remain in code

This approach avoids:

- Feature flags for unimplemented features
- Complex performance tuning options better left as code
- Overly granular settings that complicate deployment
- Options that would rarely change in practice

## Environment Variables

Environment variables override TOML configuration. They follow the pattern `LEDGER_SECTION_KEY`:

```bash
# Application settings
LEDGER_APPLICATION_HOST=0.0.0.0
LEDGER_APPLICATION_PORT=4000
LEDGER_APPLICATION_SECRET_KEY_BASE=your-secret-key

# Database settings
LEDGER_DATABASE_DATABASE=/var/lib/ledger/ledger.db
LEDGER_DATABASE_POOL_SIZE=10

# Authentication
LEDGER_AUTH_ADMIN_PASSWORD=initial-admin-password

# Logging
LEDGER_LOGGING_LEVEL=info
LEDGER_LOGGING_FILE=/var/log/ledger/ledger.log
```

## Elixir Configuration

### Base Configuration (config/config.exs)

```elixir
import Config

# Application configuration
config :ledger, Ledger.Web.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: Ledger.Web.ErrorView, accepts: ~w(html json)],
  pubsub_server: Ledger.PubSub

# Database configuration (compile-time defaults)
config :ledger, Ledger.Repo,
  adapter: Ecto.Adapters.SQLite3,
  pool_size: 5

# Logger configuration
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config
import_config "#{config_env()}.exs"
```

### Runtime Configuration (config/runtime.exs)

```elixir
import Config

if config_env() == :prod do
  # Load configuration from TOML file
  toml_path = System.get_env("LEDGER_CONFIG_PATH", "/etc/ledger/config.toml")

  if File.exists?(toml_path) do
    {:ok, toml} = Toml.decode_file(toml_path)

    # Application configuration
    if app_config = toml["application"] do
      config :ledger, Ledger.Web.Endpoint,
        http: [
          ip: parse_ip(app_config["host"]),
          port: app_config["port"]
        ],
        secret_key_base: app_config["secret_key_base"]
    end

    # Database configuration
    if db_config = toml["database"] do
      config :ledger, Ledger.Repo,
        database: db_config["database"],
        pool_size: db_config["pool_size"],
        timeout: db_config["timeout"]
    end
  end
end
```

## Configuration Module

```elixir
defmodule Ledger.Config do
  @moduledoc """
  Central configuration access for the Ledger application.
  Provides validated access to configuration values with defaults.
  """

  @doc "Get application configuration"
  def get_app(key, default \\ nil) do
    get([:application, key], default)
  end

  @doc "Get database configuration"
  def get_db(key, default \\ nil) do
    get([:database, key], default)
  end

  @doc "Get UI configuration"
  def get_ui(key, default \\ nil) do
    get([:ui, key], default)
  end

  @doc "Get configuration value by path"
  def get(path, default \\ nil) when is_list(path) do
    Application.get_env(:ledger, :config, %{})
    |> get_in(path)
    |> case do
      nil -> default
      value -> value
    end
  end

  @doc "Validate configuration at startup"
  def validate! do
    validations = [
      {:application, :secret_key_base, &validate_secret_key/1},
      {:database, :database, &validate_database_path/1},
      {:auth, :bcrypt_rounds, &validate_bcrypt_rounds/1},
      {:backup, :backup_path, &validate_backup_path/1}
    ]

    Enum.each(validations, fn {section, key, validator} ->
      value = get([section, key])
      case validator.(value) do
        :ok -> :ok
        {:error, message} ->
          raise "Configuration error [#{section}.#{key}]: #{message}"
      end
    end)
  end

  defp validate_secret_key(nil), do: {:error, "secret_key_base is required in production"}
  defp validate_secret_key(key) when byte_size(key) < 64, do: {:error, "secret_key_base must be at least 64 bytes"}
  defp validate_secret_key(_), do: :ok

  defp validate_database_path(nil), do: {:error, "database path is required"}
  defp validate_database_path(path) do
    dir = Path.dirname(path)
    if File.dir?(dir), do: :ok, else: {:error, "database directory does not exist: #{dir}"}
  end

  defp validate_bcrypt_rounds(rounds) when rounds < 4, do: {:error, "bcrypt_rounds must be at least 4"}
  defp validate_bcrypt_rounds(rounds) when rounds > 31, do: {:error, "bcrypt_rounds must be at most 31"}
  defp validate_bcrypt_rounds(_), do: :ok

  defp validate_backup_path(nil), do: :ok
  defp validate_backup_path(path) do
    if File.dir?(path), do: :ok, else: {:error, "backup directory does not exist: #{path}"}
  end
end
```

## Usage Examples

### Accessing Configuration in Code

```elixir
# Get configuration values
defmodule Ledger.Accounts do
  alias Ledger.Config

  def hierarchy_separator do
    Config.get([:accounts, :hierarchy_separator], " : ")
  end

  def max_depth do
    Config.get([:accounts, :max_depth], 6)
  end

  def recent_transaction_days do
    Config.get([:accounts, :recent_transaction_days], 30)
  end
end

# Using in Phoenix controllers
defmodule Ledger.Web.PageController do
  use Ledger.Web, :controller
  alias Ledger.Config

  def index(conn, _params) do
    render(conn, "index.html",
      app_name: Config.get_ui(:application_name, "Tideland Ledger"),
      theme: Config.get_ui(:theme, "light"),
      styles: build_custom_styles()
    )
  end

  defp build_custom_styles do
    """
    :root {
      --primary-color: #{Config.get_ui(:primary_color, "#1a1a1a")};
      --secondary-color: #{Config.get_ui(:secondary_color, "#4a5568")};
      --accent-color: #{Config.get_ui(:accent_color, "#3182ce")};
      --background-color: #{Config.get_ui(:background_color, "#ffffff")};
      --text-color: #{Config.get_ui(:text_color, "#1a202c")};
      --border-color: #{Config.get_ui(:border_color, "#e2e8f0")};
      --success-color: #{Config.get_ui(:success_color, "#48bb78")};
      --warning-color: #{Config.get_ui(:warning_color, "#ed8936")};
      --error-color: #{Config.get_ui(:error_color, "#e53e3e")};
    }
    """
  end
end
```

### Configuration Provider

```elixir
defmodule Ledger.Config.Provider do
  @behaviour Config.Provider

  def init(opts), do: opts

  def load(config, opts) do
    toml_path = opts[:path] || find_config_file()

    with {:ok, toml_content} <- File.read(toml_path),
         {:ok, toml} <- Toml.decode(toml_content) do
      merge_config(config, toml)
    else
      _ -> config
    end
  end

  defp find_config_file do
    paths = [
      System.get_env("LEDGER_CONFIG_PATH"),
      "./config.toml",
      "/etc/ledger/config.toml",
      Path.expand("~/.ledger/config.toml")
    ]

    Enum.find(paths, &(&1 && File.exists?(&1))) || "./config.toml"
  end

  defp merge_config(config, toml) do
    ledger_config = Keyword.get(config, :ledger, [])
    updated_config = deep_merge(ledger_config, atomize_keys(toml))
    Keyword.put(config, :ledger, updated_config)
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {String.to_atom(k), atomize_keys(v)} end)
  end
  defp atomize_keys(v), do: v

  defp deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _k, l, r -> deep_merge(l, r) end)
  end
  defp deep_merge(_, right), do: right
end
```

## Security Considerations

1. **Sensitive Values**: Never commit secrets to version control
2. **File Permissions**: Configuration files should be readable only by the application user
3. **Encryption**: Consider encrypting sensitive configuration values
4. **Validation**: Always validate configuration at startup
5. **Defaults**: Use secure defaults for all security-related settings

## Static Configuration

Some values are intentionally hardcoded in the application rather than made configurable:

### User Roles

```elixir
# Defined in lib/ledger/accounts/user.ex
@roles [:admin, :bookkeeper, :viewer]
```

### Transaction States

```elixir
# Defined in lib/ledger/transactions/transaction.ex
@states [:draft, :posted, :voided]
```

### Validation Rules

```elixir
# Defined in respective modules
@min_transaction_lines 2
@max_description_length 500
@max_account_code_length 20
@max_account_name_length 100
```

### Why These Are Hardcoded

1. **Core Business Rules**: These represent fundamental accounting principles
2. **Type Safety**: Compile-time checking prevents invalid values
3. **Performance**: No runtime lookup needed
4. **Simplicity**: Reduces configuration complexity
5. **Standards Compliance**: Follows accounting standards

### Design Note: Account Types

The ledger system intentionally does not have a concept of account types (asset, liability, equity, revenue, expense). Instead:

- Accounts are identified only by their code and name
- The hierarchical account structure defines the meaning through naming
- Reporting logic interprets accounts based on their hierarchical position and names
- This provides maximum flexibility and avoids hard-coding accounting standards

## Configuration Summary

The Tideland Ledger configuration system provides:

1. **TOML Format**: Human-readable configuration files
2. **Hierarchical Structure**: Logical grouping of related settings
3. **Environment Flexibility**: Different configurations per environment
4. **Runtime Updates**: Key settings changeable without recompilation
5. **Secure Defaults**: Production-ready security settings
6. **Validation**: Startup validation ensures correctness
7. **Simple UI Customization**: CSS colors configurable via TOML

### Key Design Decisions

- **No Complex Theming**: Simple color configuration only
- **Hardcoded Business Rules**: Core accounting logic not configurable
- **Single Configuration File**: One TOML file per environment
- **Elixir-Native**: No external configuration services
- **Conservative Defaults**: Secure and standard-compliant

## Best Practices

1. **Documentation**: Document all configuration options
2. **Validation**: Validate configuration values at startup
3. **Types**: Use appropriate types (don't store numbers as strings)
4. **Defaults**: Provide sensible defaults for all options
5. **Grouping**: Group related configuration together
6. **Naming**: Use consistent, descriptive names
7. **Comments**: Include helpful comments in TOML files
8. **Examples**: Provide example configuration files

## Deployment Notes

### Development

```bash
# Uses ./config.toml if present, otherwise defaults
mix phx.server
```

### Production

```bash
# Expects /etc/ledger/config.toml
LEDGER_CONFIG_PATH=/etc/ledger/config.toml ./bin/ledger start
```

### Docker

```bash
# Mount configuration file
docker run -v /path/to/config.toml:/etc/ledger/config.toml:ro tideland/ledger
```

This configuration system balances flexibility with simplicity, providing enough customization for different deployments while maintaining the integrity of core business logic.

## BEAM/Erlang VM Configuration

The BEAM virtual machine configuration is handled separately from application configuration:

### VM Arguments (vm.args)

```erlang
## Distributed Erlang
-name ledger@127.0.0.1
-setcookie your-secret-cookie

## Erlang VM Flags
+P 1000000  # Maximum number of processes
+Q 1000000  # Maximum number of ports
+K true     # Enable kernel poll
+A 10       # Async thread pool size

## Memory Management
+MMmcs 30   # Main multi-block carrier size (MB)
+MBas aobf  # Best fit allocator strategy

## Scheduler Settings
+S 4:4      # 4 schedulers, 4 online
+sbt db     # Bind schedulers to cores
```

### Environment Variables for BEAM

```bash
# Memory limits
ERL_MAX_ETS_TABLES=10000
ERL_CRASH_DUMP=/var/log/ledger/erl_crash.dump

# Garbage collection tuning
ERL_FULLSWEEP_AFTER=10
ERL_MAX_PORTS=4096

# Distribution
RELEASE_DISTRIBUTION=name
RELEASE_NODE=ledger@127.0.0.1
```

### Key Differences

1. **Application Config (TOML)**:
   - Business logic settings
   - Feature flags
   - UI preferences
   - Database paths
   - Authentication rules

2. **BEAM Config (vm.args/env)**:
   - Memory allocation
   - Process limits
   - Scheduler configuration
   - Distribution settings
   - Garbage collection tuning

### Production VM Configuration

For production, VM args are typically set in the release:

```elixir
# rel/vm.args.eex
-name <%= release_name %>@<%= hostname %>
-setcookie <%= cookie %>
+P 5000000
+Q 1000000
+K true
+A 128
+SDio 128
+zdbbl 8192
```

The separation ensures that:

- Application developers focus on business configuration
- System administrators can tune the BEAM without touching application code
- VM settings can be adjusted without application knowledge
