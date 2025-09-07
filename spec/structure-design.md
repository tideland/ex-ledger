# Tideland Ledger - Structure Design

## 1. Overview

This document describes the typical structure of an Elixir/Phoenix application and explains why each component is organized the way it is. Understanding this structure is crucial for maintaining and extending the application.

## 2. Application Structure Philosophy

### 2.1 Core Principles

- **Separation of Concerns**: Business logic separate from web layer
- **Explicit over Implicit**: Clear module naming and organization
- **Bounded Contexts**: Domain-driven design with clear boundaries
- **OTP Design Principles**: Supervision trees, fault tolerance
- **Convention over Configuration**: Follow Phoenix/Elixir standards

### 2.2 Why This Structure?

Elixir applications follow OTP (Open Telecom Platform) principles, which provide:

- Fault tolerance through supervision
- Hot code reloading capabilities
- Process isolation for concurrent operations
- Standardized project layout for team collaboration

## 3. Directory Structure

### 3.1 Root Level Structure

```
ledger/
├── _build/              # Compiled files (git ignored)

├── config/              # Configuration files
├── deps/                # Dependencies (git ignored)
├── doc/                 # Documentation
├── lib/                 # Application source code
├── priv/                # Private application resources
├── test/                # Test files
├── .formatter.exs       # Code formatter configuration
├── .gitignore          # Git ignore patterns
├── mix.exs             # Project definition and dependencies
└── mix.lock            # Dependency lock file
```

### 3.2 Why Each Directory?

**\_build/**

- Contains compiled BEAM files
- Separated by environment (dev, test, prod)
- Never committed to version control
- Regenerated on each build

**config/**

- Centralized configuration management
- Environment-specific settings
- Compile-time and runtime configuration
- Follows Elixir's Config module patterns

**deps/**

- Downloaded dependencies
- Managed by Mix
- Lock file ensures reproducible builds

**lib/**

- Core application code
- Split between business logic and web layer
- The heart of your application

**priv/**

- Non-Elixir files needed at runtime
- Database migrations, static assets, etc.
- Accessible via Application.app_dir(:ledger, "priv")

**test/**

- Mirrors lib/ structure
- Unit and integration tests
- Test helpers and fixtures

## 4. The lib/ Directory Structure

### 4.1 Detailed Layout

```
lib/
├── ledger/                    # Business logic (contexts)
│   ├── application.ex         # OTP Application callback
│   ├── repo.ex               # Ecto repository
│   ├── accounts/             # Accounts context
│   │   ├── account.ex        # Account schema
│   │   └── accounts.ex       # Context API
│   ├── core/                 # Core domain types
│   │   ├── amount.ex         # Money amount type
│   │   └── account_path.ex   # Account path handling
│   ├── transactions/         # Transactions context
│   │   ├── transaction.ex    # Transaction schema
│   │   ├── position.ex       # Position schema
│   │   └── transactions.ex   # Context API
│   └── users/                # Users context
│       ├── user.ex           # User schema
│       ├── auth.ex           # Authentication logic
│       └── users.ex          # Context API
├── ledger_web/               # Web layer
│   ├── endpoint.ex           # HTTP endpoint configuration
│   ├── router.ex             # Route definitions
│   ├── telemetry.ex          # Metrics and monitoring
│   ├── components/           # Reusable UI components
│   ├── controllers/          # HTTP request handlers
│   └── live/                 # LiveView modules
└── ledger.ex                 # Main application module
```

### 4.2 Why This Organization?

**Separation of Business Logic and Web Layer**

- `ledger/` contains pure business logic
- `ledger_web/` contains only web-related code
- Allows testing business logic without web layer
- Could support multiple interfaces (API, CLI)

**Context-Based Organization**

- Each context (Accounts, Transactions, Users) is self-contained
- Clear boundaries between different domains
- Easier to understand and maintain
- Follows Domain-Driven Design principles

## 5. OTP Application Structure

### 5.1 Application Module

```elixir
defmodule Ledger.Application do
  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Ledger.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Ledger.PubSub},
      # Start the Endpoint
      LedgerWeb.Endpoint,
      # Start custom supervisors
      Ledger.TransactionProcessor
    ]

    opts = [strategy: :one_for_one, name: Ledger.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### 5.2 Why Supervision Trees?

- **Fault Tolerance**: If a process crashes, it's restarted
- **Isolation**: Errors don't propagate to other parts
- **Monitoring**: Built-in process monitoring
- **Hot Upgrades**: Can update code without stopping

### 5.3 Supervision Strategies

- **one_for_one**: Restart only the failed child
- **one_for_all**: Restart all children if one fails
- **rest_for_one**: Restart failed child and those started after it

## 6. Context Design

### 6.1 Context Structure

```
accounts/
├── accounts.ex      # Public API
├── account.ex       # Schema
├── queries.ex       # Complex queries (optional)
└── services/        # Internal services (optional)
    └── calculator.ex
```

### 6.2 Context Module Pattern

```elixir
defmodule Ledger.Accounts do
  @moduledoc """
  The Accounts context - manages chart of accounts.
  """

  alias Ledger.Repo
  alias Ledger.Accounts.Account

  # Public API functions
  def list_accounts, do: Repo.all(Account)
  def get_account!(id), do: Repo.get!(Account, id)
  def create_account(attrs), do: ...
  def update_account(account, attrs), do: ...
  def delete_account(account), do: ...
end
```

### 6.3 Why Contexts?

- **Encapsulation**: Hide internal implementation
- **Clear API**: Well-defined public functions
- **Testability**: Test through the public API
- **Flexibility**: Can change internals without breaking consumers

## 7. Schema and Changeset Pattern

### 7.1 Schema Structure

```elixir
defmodule Ledger.Accounts.Account do
  use Ecto.Schema
  import Ecto.Changeset

  schema "accounts" do
    field :path, :string
    field :name, :string
    field :type, Ecto.Enum, values: [:asset, :liability, ...]
    field :active, :boolean, default: true

    timestamps()
  end

  def changeset(account, attrs) do
    account
    |> cast(attrs, [:path, :name, :type, :active])
    |> validate_required([:path, :name, :type])
    |> validate_account_path()
  end
end
```

### 7.2 Why Schemas and Changesets?

- **Data Validation**: Centralized validation logic
- **Type Safety**: Compile-time type checking
- **Database Mapping**: Clear ORM mapping
- **Change Tracking**: Know what fields changed

## 8. Web Layer Structure

### 8.1 Controller Pattern

```elixir
defmodule LedgerWeb.AccountController do
  use LedgerWeb, :controller
  alias Ledger.Accounts

  def index(conn, _params) do
    accounts = Accounts.list_accounts()
    render(conn, :index, accounts: accounts)
  end
end
```

### 8.2 LiveView Pattern

```elixir
defmodule LedgerWeb.TransactionLive.New do
  use LedgerWeb, :live_view
  alias Ledger.Transactions

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(Transactions.change_transaction()))}
  end

  def handle_event("save", %{"transaction" => params}, socket) do
    # Handle form submission
  end
end
```

### 8.3 Why This Web Structure?

- **Thin Controllers**: Business logic stays in contexts
- **Composable Views**: Reusable components
- **LiveView for Interactivity**: Real-time updates without JavaScript
- **Clear Routing**: Explicit route definitions

## 9. Configuration Structure

### 9.1 Configuration Files

```
config/
├── config.exs          # Shared configuration
├── dev.exs            # Development environment
├── test.exs           # Test environment
├── prod.exs           # Production compile-time
└── runtime.exs        # Production runtime
```

### 9.2 Why Multiple Config Files?

- **Environment Separation**: Different settings per environment
- **Compile vs Runtime**: Some config needed at compile time
- **Security**: Sensitive data only in runtime config
- **Flexibility**: Override settings per environment

## 10. Testing Structure

### 10.1 Test Organization

```
test/
├── support/
│   ├── data_case.ex      # Database test helpers
│   ├── conn_case.ex      # Controller test helpers
│   └── fixtures.ex       # Test data factories
├── ledger/
│   ├── accounts_test.exs # Context tests
│   └── core/
│       └── amount_test.exs
└── ledger_web/
    ├── controllers/
    └── live/
```

### 10.2 Why This Test Structure?

- **Mirrors Source**: Easy to find corresponding tests
- **Shared Helpers**: Common test functionality
- **Isolation**: Tests run in isolation
- **Categories**: Unit, integration, and acceptance tests

## 11. Database Structure

### 11.1 Migration Organization

```
priv/repo/migrations/
├── 20240101000001_create_users.exs
├── 20240101000002_create_accounts.exs
├── 20240101000003_create_transactions.exs
└── 20240101000004_create_positions.exs
```

### 11.2 Why Migrations?

- **Version Control**: Database schema in git
- **Reproducibility**: Same schema everywhere
- **Rollback Capability**: Can undo changes
- **Team Coordination**: Everyone has same schema

## 12. Process and GenServer Structure

### 12.1 GenServer Pattern

```elixir
defmodule Ledger.TransactionProcessor do
  use GenServer

  # Client API
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def process_transaction(transaction) do
    GenServer.call(__MODULE__, {:process, transaction})
  end

  # Server Callbacks
  def init(opts), do: {:ok, %{}}

  def handle_call({:process, transaction}, _from, state) do
    # Process transaction
    {:reply, :ok, state}
  end
end
```

### 12.2 Why GenServers?

- **State Management**: Maintain state across requests
- **Concurrency**: Handle multiple requests
- **Fault Tolerance**: Supervised and restarted on failure
- **Message Passing**: Async communication between processes

## 13. Asset Pipeline (Without Node.js)

### 13.1 Pure Elixir Assets

```
priv/
├── static/
│   ├── css/
│   │   └── app.css      # Hand-written CSS
│   ├── js/
│   │   └── app.js       # Minimal JavaScript
│   └── images/
└── templates/           # EEx templates
```

### 13.2 Why Avoid Node.js?

- **Simplicity**: One less technology stack
- **Deployment**: Easier deployment without Node
- **Phoenix Tools**: Use Phoenix's built-in tools
- **Server-Side Focus**: Emphasize server rendering

## 14. Common Patterns

### 14.1 Repository Pattern

- All database access through Repo
- Contexts wrap Repo calls
- Never call Repo directly from web layer

### 14.2 Changeset Pattern

- All data validation in changesets
- Composable validation functions
- Clear error messages

### 14.3 Context Pattern

- Public API in context module
- Internal modules hidden
- Clear boundaries between domains

### 14.4 Supervisor Pattern

- Everything supervised
- Crash and restart philosophy
- Isolated failure domains

## 15. Best Practices

### 15.1 Module Naming

- Use full names: `Ledger.Accounts.Account`
- Avoid abbreviations
- Consistent naming patterns

### 15.2 Function Organization

1. Public API functions first
2. Private functions below
3. Callbacks at the end
4. Group related functions

### 15.3 Documentation

- Document all public functions
- Use @moduledoc for module purpose
- Examples in documentation
- Type specifications for clarity

### 15.4 Error Handling

- Let it crash philosophy
- Return {:ok, result} or {:error, reason}
- Use ! functions for exceptional cases
- Pattern match on results

This structure provides a solid foundation for building maintainable Elixir applications while following community best practices and OTP principles.
