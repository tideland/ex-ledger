# Tideland Ledger - Pattern Design

## 1. Overview

This document describes common Elixir patterns and idioms that will be used throughout the Tideland Ledger application. Understanding these patterns is essential for writing idiomatic Elixir code that is maintainable, performant, and follows community standards.

## 2. Core Elixir Patterns

### 2.1 Pattern Matching

Pattern matching is fundamental to Elixir. Use it for:

- Function definitions
- Case statements
- Control flow
- Data extraction

```elixir
# Function heads with pattern matching
# This function will only match if positions list is empty
def process_transaction(%Transaction{positions: []} = transaction) do
  # Return error tuple - standard Elixir error handling pattern
  {:error, "Transaction must have positions"}
end

# This function matches when positions exist and uses guard clause
# Guards add extra conditions beyond pattern matching
def process_transaction(%Transaction{positions: positions} = transaction) when length(positions) >= 2 do
  # The '= transaction' captures the whole struct for use in function body
  # Process valid transaction
  {:ok, transaction}
end

# Case statement pattern matching
# 'case' lets us match different outcomes from a function call
case validate_transaction(transaction) do
  # Match successful validation - destructure the tuple and bind valid_transaction
  {:ok, valid_transaction} ->
    post_transaction(valid_transaction)

  # Match any error - underscore means we don't care about the specific error atom
  {:error, reason} ->
    Logger.error("Transaction validation failed: #{reason}")
    # Return the error tuple to caller
    {:error, reason}
end
```

### 2.2 The Pipe Operator

Use pipes to transform data through a series of functions:

```elixir
# Instead of nested function calls (hard to read right-to-left):
String.trim(String.downcase(String.replace(input, "-", " ")))

# Use pipes for clarity (reads left-to-right like a pipeline):
input
|> String.replace("-", " ")    # First: replace dashes with spaces
|> String.downcase()           # Then: convert to lowercase
|> String.trim()               # Finally: remove whitespace

# Real example from ledger:
def create_transaction(attrs) do
  %Transaction{}                # Start with empty Transaction struct
  |> Transaction.changeset(attrs)  # Apply changes and basic validation
  |> validate_positions()          # Custom validation: check positions
  |> validate_zero_sum()           # Custom validation: ensure balance
  |> Repo.insert()                 # Save to database if all validations pass
  # Each step returns either {:ok, result} or {:error, changeset}
end
```

### 2.3 With Statements

Use `with` for happy path programming with multiple operations that might fail:

```elixir
def post_transaction(transaction_params) do
  # 'with' chains operations that might fail
  # Each line must return {:ok, value} to continue
  with {:ok, transaction} <- validate_transaction(transaction_params),
       # Notice we rebind 'transaction' - each step can transform it
       {:ok, transaction} <- check_accounts_exist(transaction),
       {:ok, transaction} <- validate_zero_sum(transaction),
       # Final step returns 'posted' instead of 'transaction'
       {:ok, posted} <- Repo.insert(transaction) do
    # If all succeed, return the final result
    {:ok, posted}
  else
    # 'else' handles any {:error, reason} from above
    # Pattern match specific errors to provide better messages
    {:error, :invalid_transaction} -> {:error, "Transaction validation failed"}
    {:error, :accounts_not_found} -> {:error, "One or more accounts do not exist"}
    {:error, :non_zero_sum} -> {:error, "Transaction does not balance"}
    # Catch-all for unexpected errors (like changeset errors from Repo.insert)
    {:error, changeset} -> {:error, changeset}
  end
end
```

## 3. OTP Patterns

### 3.1 GenServer Pattern

GenServer for stateful processes:

```elixir
defmodule Ledger.BalanceCache do
  # GenServer is OTP's generic server behavior for stateful processes
  use GenServer

  # Client API - These functions run in the caller's process

  # Start the GenServer process and register it by module name
  def start_link(opts \\ []) do
    # __MODULE__ is the current module name (Ledger.BalanceCache)
    # name: __MODULE__ registers this process globally by module name
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Synchronous call - waits for response
  def get_balance(account_path) do
    # :call sends message and waits for reply (blocking)
    GenServer.call(__MODULE__, {:get_balance, account_path})
  end

  # Asynchronous cast - doesn't wait for response
  def update_balance(account_path, amount) do
    # :cast sends message and returns immediately (non-blocking)
    GenServer.cast(__MODULE__, {:update_balance, account_path, amount})
  end

  # Server Callbacks - These run in the GenServer process

  # @impl true tells compiler this implements a callback
  @impl true
  def init(_opts) do
    # Called when GenServer starts
    # Returns {:ok, initial_state}
    # State is just a map: account_path => balance
    {:ok, %{}}
  end

  # Handle synchronous calls (must reply)
  @impl true
  def handle_call({:get_balance, account_path}, _from, state) do
    # Look up balance, default to zero if not found
    balance = Map.get(state, account_path, Amount.zero())
    # {:reply, response, new_state}
    # State unchanged, so we return same state
    {:reply, balance, state}
  end

  # Handle asynchronous casts (no reply needed)
  @impl true
  def handle_cast({:update_balance, account_path, amount}, state) do
    # Map.update: if key exists, apply function; else use default
    # &Amount.add(&1, amount) is shorthand for fn(old) -> Amount.add(old, amount) end
    new_state = Map.update(state, account_path, amount, &Amount.add(&1, amount))
    # {:noreply, new_state} - no response sent to caller
    {:noreply, new_state}
  end
end
```

### 3.2 Supervisor Pattern

Supervisors for fault tolerance:

```elixir
defmodule Ledger.TransactionSupervisor do
  # Supervisor manages child processes and restarts them if they crash
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Define child processes to supervise
    children = [
      # Simple child spec - will use default restart strategy (:permanent)
      # This process will always be restarted if it crashes
      {Ledger.TransactionProcessor, []},

      # Detailed child spec with custom settings
      %{
        id: Ledger.TransactionValidator,  # Unique ID for this child
        start: {Ledger.TransactionValidator, :start_link, []},  # How to start it
        restart: :temporary  # Never restart (vs :permanent or :transient)
      }
    ]

    # Strategy determines what happens when a child crashes:
    # :one_for_one - only restart the crashed child (most common)
    # :one_for_all - restart all children if one crashes
    # :rest_for_one - restart crashed child and all started after it
    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

### 3.3 Task Pattern

For concurrent operations:

```elixir
defmodule Ledger.Reports do
  def generate_balance_sheet(date) do
    # Run account balance calculations concurrently
    tasks =
      Accounts.list_accounts()
      |> Enum.map(fn account ->
        # Task.async spawns a new process to run the function
        # Returns a Task struct that we can await later
        Task.async(fn ->
          # This runs in a separate process concurrently
          {account, calculate_balance(account, date)}
        end)
      end)
      # 'tasks' is now a list of Task structs, not results

    # Collect results - this is where we wait for all tasks
    balances =
      tasks
      |> Enum.map(&Task.await/1)  # Wait for each task to complete (default 5s timeout)
      |> Map.new()  # Convert list of {account, balance} tuples to map

    # All balances calculated in parallel, now build report
    build_balance_sheet(balances)
  end
end
```

## 4. Ecto Patterns

### 4.1 Changeset Pattern

Validate and transform data:

```elixir
defmodule Ledger.Transactions.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  # Define database table structure
  schema "transactions" do
    # Field types map to database columns
    field :date, :date
    field :description, :string
    field :reference, :string
    field :posted, :boolean, default: false

    # Associations - Ecto handles foreign keys
    has_many :positions, Position  # One transaction has many positions
    belongs_to :created_by, User   # References users table via created_by_id

    # Adds inserted_at and updated_at fields automatically
    timestamps()
  end

  # Changeset function validates and transforms data before DB operations
  def changeset(transaction, attrs) do
    transaction
    # Cast external data to schema types, only allowing specified fields
    |> cast(attrs, [:date, :description, :reference])
    # These fields must be present
    |> validate_required([:date, :description])
    # String length validation
    |> validate_length(:description, min: 3, max: 200)
    # Handle nested positions - required: true means at least one position
    |> cast_assoc(:positions, required: true)
    # Custom validation function
    |> validate_positions_balance()
  end

  # Private function for custom validation
  defp validate_positions_balance(changeset) do
    # validate_change runs custom validation on a field
    validate_change(changeset, :positions, fn _, positions ->
      sum =
        positions
        # Each position is either a changeset (new) or schema struct (existing)
        # Get amount from changes if new, or from data if existing
        |> Enum.map(& &1.changes[:amount] || &1.data.amount)
        |> Amount.sum()

      # Return empty list if valid (no errors)
      if Amount.is_zero?(sum) do
        []
      else
        # Return keyword list of errors
        [positions: "must sum to zero"]
      end
    end)
  end
end
```

### 4.2 Query Composition Pattern

Build complex queries step by step:

```elixir
defmodule Ledger.Transactions do
  import Ecto.Query

  # Public function with optional filters map
  def list_transactions(filters \\ %{}) do
    Transaction  # Start with base query (just the schema module name)
    |> filter_by_date_range(filters)  # Each function adds conditions
    |> filter_by_account(filters)      # Filters are composable
    |> filter_by_amount(filters)       # Order matters for some operations
    |> order_by([t], desc: t.date, desc: t.inserted_at)  # Sort newest first
    |> preload([:positions, :created_by])  # Avoid N+1 queries
    |> Repo.all()  # Execute query and return results
  end

  # Pattern match on map with specific keys
  defp filter_by_date_range(query, %{from_date: from_date, to_date: to_date}) do
    query
    # [t] binds the transaction table for use in expressions
    # ^ (pin operator) uses the variable value, prevents SQL injection
    |> where([t], t.date >= ^from_date)
    |> where([t], t.date <= ^to_date)  # Multiple wheres are AND'd together
  end
  # Fallback clause when date filters not provided - return query unchanged
  defp filter_by_date_range(query, _), do: query

  defp filter_by_account(query, %{account_path: account_path}) do
    query
    # Join with positions table through association
    |> join(:inner, [t], p in assoc(t, :positions))
    # Now we can reference both [t] and [p] in where clause
    |> where([t, p], p.account_path == ^account_path)
    # Remove duplicate transactions (since one transaction has many positions)
    |> distinct(true)
  end
  defp filter_by_account(query, _), do: query
end
```

### 4.3 Multi Pattern

For bulk operations:

```elixir
defmodule Ledger.Transactions do
  alias Ecto.Multi

  def post_transaction(transaction_id) do
    # Multi allows multiple database operations in a single transaction
    # If any step fails, everything is rolled back
    Multi.new()
    # Each step has a name (:transaction) and operation
    |> Multi.run(:transaction, fn repo, _changes_so_far ->
      # First step: find the transaction
      case repo.get(Transaction, transaction_id) do
        nil -> {:error, :not_found}  # This will abort the Multi
        transaction -> {:ok, transaction}  # Pass to next steps
      end
    end)
    |> Multi.run(:validate, fn _repo, %{transaction: transaction} ->
      # Second step: validate (can access previous results)
      # %{transaction: transaction} destructures results from previous steps
      validate_for_posting(transaction)
    end)
    |> Multi.update(:post, fn %{transaction: transaction} ->
      # Third step: update the transaction
      # Must return a changeset for Multi.update
      Transaction.posting_changeset(transaction, %{posted: true})
    end)
    |> Multi.run(:update_balances, fn repo, %{transaction: transaction} ->
      # Fourth step: custom operation with repo access
      update_account_balances(repo, transaction)
    end)
    # Execute all operations in a database transaction
    |> Repo.transaction()
    # Returns {:ok, %{transaction: ..., validate: ..., post: ..., update_balances: ...}}
    # or {:error, failed_step_name, failed_value, changes_so_far}
  end
end
```

## 5. Context Patterns

### 5.1 Context as API Boundary

Contexts provide the public API:

```elixir
defmodule Ledger.Accounts do
  @moduledoc """
  Public API for account management.
  """

  # Alias allows shorter names in this module
  alias Ledger.Repo
  alias Ledger.Accounts.{Account, AccountQueries}

  # Public API - what other parts of the app can call
  # These are the ONLY functions other modules should use

  # Default argument with \\
  def list_accounts(opts \\ []) do
    AccountQueries.list_query(opts)  # Delegate query building to separate module
    |> Repo.all()  # Execute query
  end

  # Repo.get_by returns nil if not found (vs get_by! which raises)
  def get_account_by_path(path) do
    Repo.get_by(Account, path: path)  # Find by non-primary-key field
  end

  # Standard create pattern
  def create_account(attrs) do
    %Account{}  # Start with empty struct
    |> Account.changeset(attrs)  # Validate and prepare changes
    |> Repo.insert()  # Returns {:ok, account} or {:error, changeset}
  end

  # Don't expose internal functions
  # Keep queries, complex logic, etc. private
  # This creates a clean API boundary
end
```

### 5.2 Context Delegation Pattern

For complex contexts, delegate to specialized modules:

```elixir
defmodule Ledger.Transactions do
  # Delegate complex operations to specialized modules
  # This keeps the context module focused on coordination

  # defdelegate creates a function that calls another module's function
  defdelegate balance_for_account(account, date),
    to: Ledger.Transactions.BalanceCalculator,  # Target module
    as: :calculate  # Function name in target module (optional rename)
  # This creates balance_for_account/2 that calls BalanceCalculator.calculate/2

  defdelegate validate_transaction(transaction),
    to: Ledger.Transactions.Validator,
    as: :validate

  # Keep simple CRUD in the context
  # The ! means it raises an exception if not found (Ecto convention)
  def get_transaction!(id), do: Repo.get!(Transaction, id)
end
```

## 6. Phoenix Patterns

### 6.1 Controller Pattern

Keep controllers thin:

```elixir
defmodule LedgerWeb.TransactionController do
  use LedgerWeb, :controller  # Imports helpers like render, redirect, etc.
  alias Ledger.Transactions  # Reference context, not schemas directly

  # Action functions receive conn (connection) and params
  def index(conn, params) do
    # Controller just coordinates - business logic in context
    transactions = Transactions.list_transactions(params)
    # Render template with assigns (available as @transactions in template)
    render(conn, :index, transactions: transactions)
  end

  # Pattern match params to extract nested transaction data
  def create(conn, %{"transaction" => transaction_params}) do
    # Context function returns tagged tuple
    case Transactions.create_transaction(transaction_params) do
      {:ok, transaction} ->
        conn
        |> put_flash(:info, "Transaction created successfully.")  # Flash message
        |> redirect(to: ~p"/transactions/#{transaction}")  # ~p is path helper

      {:error, %Ecto.Changeset{} = changeset} ->
        # Re-render form with errors (changeset contains validation errors)
        render(conn, :new, changeset: changeset)
    end
  end
end
```

### 5.3 Transaction Context Implementation

The Transactions context demonstrates advanced patterns:

```elixir
defmodule Ledger.Transactions do
  # Uses Ecto.Multi for complex multi-step operations
  def post_entry(%Entry{} = entry, user_id) do
    Multi.new()
    |> Multi.run(:validate_can_post, fn _, _ ->
      if Entry.can_post?(entry) do
        {:ok, true}
      else
        {:error, :already_posted}
      end
    end)
    |> Multi.run(:validate_period, fn _, _ ->
      validate_period_open(entry.date)
    end)
    |> Multi.run(:validate_accounts_active, fn _, _ ->
      validate_all_accounts_active(entry)
    end)
    |> Multi.update(:entry, Entry.post_changeset(entry, user_id))
    |> Multi.run(:create_audit_log, fn _, %{entry: posted_entry} ->
      create_audit_log(posted_entry, :posted, user_id)
    end)
    |> Repo.transaction()
  end

  # Voiding creates automatic reversal entries
  def void_entry(%Entry{} = entry, user_id, reason) do
    Multi.new()
    |> Multi.update(:void_entry, Entry.void_changeset(entry, user_id, reason))
    |> Multi.run(:create_reversal, fn _, %{void_entry: voided_entry} ->
      create_reversal_entry(voided_entry, user_id)
    end)
    |> Repo.transaction()
  end

  # Complex queries with flexible filtering
  def list_entries(opts \\ []) do
    Entry
    |> filter_by_status(opts[:status])
    |> filter_by_date_range(opts[:from_date], opts[:to_date])
    |> filter_by_account(opts[:account_id])
    |> filter_by_search(opts[:search])
    |> order_by([e], desc: e.date, desc: e.id)
    |> limit_offset(opts[:limit], opts[:offset])
    |> maybe_preload(opts[:preload] || [:positions])
    |> Repo.all()
  end
end
```

Key patterns used:

- Ecto.Multi for transactional operations with multiple steps
- Automatic reversal generation for voiding
- Composable query functions for flexible filtering
- Structured error handling with atoms
- Preloading control to avoid N+1 queries

### 6.2 LiveView Pattern

Stateful UI without JavaScript:

```elixir
defmodule LedgerWeb.TransactionLive.Form do
  use LedgerWeb, :live_view  # LiveView for interactive UI without JavaScript
  alias Ledger.Transactions

  # Called when LiveView component is first loaded
  def mount(params, _session, socket) do
    {:ok,
     socket
     # Socket holds state for this LiveView connection
     |> assign(:transaction, %Transaction{positions: []})
     # to_form converts changeset to form data structure
     |> assign(:form, to_form(Transactions.change_transaction()))}
  end

  # Handle client events (like button clicks)
  def handle_event("add_position", _params, socket) do
    # Add new empty position to list
    positions = socket.assigns.transaction.positions ++ [%Position{}]

    {:noreply,  # Don't send reply to client
     socket
     # Update struct with new positions list
     |> assign(:transaction, %{socket.assigns.transaction | positions: positions})
     # Regenerate form to include new position
     |> assign(:form, to_form(Transactions.change_transaction(socket.assigns.transaction)))}
  end

  # Handle form submission
  def handle_event("save", %{"transaction" => params}, socket) do
    case Transactions.create_transaction(params) do
      {:ok, transaction} ->
        {:noreply,
         socket
         |> put_flash(:info, "Transaction created!")
         # Navigate to new page (full page load)
         |> push_navigate(to: ~p"/transactions/#{transaction}")}

      {:error, changeset} ->
        # Re-render with errors (no page reload)
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
```

### 6.3 Component Pattern

Reusable UI components:

```elixir
defmodule LedgerWeb.Components.AmountInput do
  use Phoenix.Component  # Makes this a function component

  # Declare expected attributes with types and options
  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, default: "Amount"

  # Function name becomes component name
  def amount_input(assigns) do
    # ~H sigil for HEEx templates (HTML+Elixir)
    ~H"""
    <div class="amount-input">
      <!-- .label is a function component from CoreComponents -->
      <.label for={@field.id}><%= @label %></.label>
      <!-- .input component with custom attributes -->
      <.input
        type="text"
        field={@field}
        pattern="[0-9]+\.?[0-9]{0,2}"  <!-- Regex: digits with optional 2 decimals -->
        placeholder="0.00"
      />
      <!-- :for creates iterator, shows each error message -->
      <.error :for={msg <- @field.errors}><%= msg %></.error>
    </div>
    """
  end
end
```

## 7. Error Handling Patterns

### 7.1 Tagged Tuples

Always use tagged tuples for results:

```elixir
# Good - explicit success/failure
def divide(a, b) when b != 0 do
  {:ok, a / b}
end

def divide(_, 0) do
  {:error, :division_by_zero}
end

# Usage - always handle both success and failure cases
case divide(10, 2) do
  {:ok, result} -> IO.puts("Result: #{result}")
  {:error, reason} -> IO.puts("Error: #{reason}")
end
```

### 7.2 Let It Crash

Don't defensive program - let processes crash and restart:

```elixir
# Bad - defensive programming (trying to handle every possible error)
def process_data(data) do
  if is_nil(data) do
    {:error, "Data is nil"}
  else
    try do
      # process data
    rescue
      e -> {:error, e}  # Catching all exceptions is usually wrong
    end
  end
end

# Good - let it crash philosophy
def process_data(data) do
  # Just process the data - assume it's valid
  # If data is nil or transform fails, process crashes
  result = transform_data(data)
  {:ok, result}
  # Supervisor will restart this process if it crashes
  # Other processes continue running unaffected
end
```

### 7.3 Error Context

Provide context in errors:

```elixir
def create_transaction(attrs) do
  # Each step in 'with' can transform and pass along data
  with {:ok, transaction} <- build_transaction(attrs),
       # Notice: we're returning 3-element tuples for more context
       {:ok, transaction} <- validate_accounts(transaction),
       {:ok, transaction} <- validate_zero_sum(transaction),
       {:ok, saved} <- Repo.insert(transaction) do
    {:ok, saved}
  else
    # Pattern match on 3-element error tuples for specific handling
    {:error, :invalid_accounts, invalid} ->
      # Provide helpful error message with account names
      {:error, "Invalid accounts: #{Enum.join(invalid, ", ")}"}

    {:error, :non_zero_sum, sum} ->
      # Show the actual imbalance amount
      {:error, "Transaction doesn't balance. Off by: #{sum}"}

    # Changeset errors are already well-structured
    {:error, %Ecto.Changeset{} = changeset} ->
      {:error, changeset}
  end
end
```

## 8. Testing Patterns

### 8.1 Property-Based Testing

Test properties, not just examples:

```elixir
defmodule Ledger.Core.AmountTest do
  use ExUnit.Case
  use ExUnitProperties  # Enables property-based testing

  # 'property' defines a test that runs with many random inputs
  property "distribution always sums to original" do
    # 'check all' generates random test cases
    check all amount <- positive_integer(),  # Generate random positive integers
              parts <- integer(2..10) do     # Generate integers between 2 and 10
      # This block runs 100 times with different random values
      distributed = Amount.distribute(Amount.new(amount), parts)
      sum = Amount.sum(distributed)

      # Property: no matter the inputs, sum must equal original
      assert Amount.equal?(sum, Amount.new(amount))
      # If this ever fails, ExUnit shows the exact inputs that caused failure
    end
  end
end
```

### 8.2 Factory Pattern

Create test data consistently:

```elixir
defmodule Ledger.Factory do
  alias Ledger.{Repo, Accounts, Transactions}

  # Factory pattern creates consistent test data
  def build(:account) do
    %Accounts.Account{
      # System.unique_integer() ensures unique names in tests
      path: "Assets : Test : Account #{System.unique_integer()}",
      name: "Test Account",
      type: :asset,
      active: true
    }
  end

  def build(:transaction) do
    %Transactions.Transaction{
      date: Date.utc_today(),
      description: "Test transaction",
      positions: [
        # Build balanced transaction (sum = 0)
        build(:position, amount: Amount.new(100)),
        build(:position, amount: Amount.new(-100))
      ]
    }
  end

  # Helper to build and insert in one step
  def insert!(factory, attrs \\ %{}) do
    factory
    |> build()  # Create base struct
    |> Map.merge(attrs)  # Override with custom attributes
    |> Repo.insert!()  # Save to test database (raises on error)
  end
end
```

### 8.3 Context Testing

Test through the public API:

```elixir
defmodule Ledger.TransactionsTest do
  use Ledger.DataCase  # Provides database sandbox for tests
  alias Ledger.Transactions

  # 'describe' groups related tests
  describe "create_transaction/1" do
    test "creates transaction with valid data" do
      # Arrange - create test data
      account1 = insert!(:account)
      account2 = insert!(:account)

      attrs = %{
        date: ~D[2024-01-15],  # Date sigil for date literals
        description: "Test transaction",
        positions: [
          # Note: amounts as strings to simulate form input
          %{account_id: account1.id, amount: "100.00"},
          %{account_id: account2.id, amount: "-100.00"}
        ]
      }

      # Act - call the function we're testing
      assert {:ok, transaction} = Transactions.create_transaction(attrs)

      # Assert - verify the results
      assert transaction.description == "Test transaction"
      assert length(transaction.positions) == 2
      # Each test runs in a database transaction that's rolled back
    end

    test "fails with non-zero sum" do
      # Test the business rule - transactions must balance
      account1 = insert!(:account)
      account2 = insert!(:account)

      attrs = %{
        date: ~D[2024-01-15],
        description: "Unbalanced transaction",
        positions: [
          %{account_id: account1.id, amount: "100.00"},
          %{account_id: account2.id, amount: "-90.00"}  # Off by 10
        ]
      }

      # Expecting failure
      assert {:error, changeset} = Transactions.create_transaction(attrs)
      assert "must sum to zero" in errors_on(changeset).positions
    end
  end
end
```

## 9. Configuration Patterns

### 9.1 Application Configuration

Use application configuration properly:

```elixir
# config/config.exs
config :ledger,
  ecto_repos: [Ledger.Repo],
  default_currency: "EUR",
  amount_precision: 2

# Runtime access in modules
defmodule Ledger.Core.Amount do
  # @precision is set at compile time - can't change after compilation
  @precision Application.compile_env(:ledger, :amount_precision, 2)

  # For runtime configuration (can change without recompiling)
  def precision do
    # First arg: app name, second: key, third: default if not found
    Application.get_env(:ledger, :amount_precision, @precision)
  end

  # Use module attribute for performance-critical code
  # Use get_env for configuration that might change
end
```

### 9.2 Module Attributes as Configuration

For compile-time configuration:

```elixir
defmodule Ledger.Accounts do
  # Module attributes are compile-time constants
  @account_types [:asset, :liability, :equity, :revenue, :expense]
  @max_path_depth 6

  # Using 'in' operator with module attribute for fast membership check
  def valid_account_type?(type) do
    type in @account_types  # Compiled to efficient pattern match
  end

  # Module attributes are faster than runtime config
  # Use them for values that won't change
end
```

## 10. Performance Patterns

### 10.1 Lazy Evaluation

Use streams for large datasets:

```elixir
def export_transactions(year) do
  Transaction
  # fragment allows raw SQL when Ecto doesn't have the function
  |> where([t], fragment("YEAR(?)", t.date) == ^year)
  # Repo.stream returns a Stream, not loading all records at once
  |> Repo.stream()
  # Stream.map is lazy - only processes when consumed
  |> Stream.map(&format_for_export/1)
  # Process in batches to manage memory usage
  |> Stream.chunk_every(1000)
  # Enum.each forces evaluation of the stream
  |> Enum.each(&write_to_file/1)
  # This processes millions of records without loading all into memory
end
```

### 10.2 ETS for Caching

Use ETS for fast in-memory storage:

```elixir
defmodule Ledger.AccountCache do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    # ETS (Erlang Term Storage) is in-memory key-value store
    :ets.new(:account_cache, [
      :set,  # One value per key (vs :bag for multiple)
      :named_table,  # Can reference by atom name
      :public,  # Any process can read/write (fast!)
      read_concurrency: true  # Optimized for concurrent reads
    ])
    {:ok, %{}}  # GenServer state (not used here)
  end

  # Direct ETS access - no GenServer call needed (very fast)
  def get(path) do
    case :ets.lookup(:account_cache, path) do
      [{^path, account}] -> account  # Pin operator ensures key matches
      [] -> nil  # Not found
    end
  end

  def put(path, account) do
    # Returns true, no error handling needed
    :ets.insert(:account_cache, {path, account})
  end
  # ETS survives process crashes if owned by supervisor
end
```

### 10.3 Preloading Associations

Avoid N+1 queries:

```elixir
# Bad - N+1 query problem
transactions = Repo.all(Transaction)  # 1 query
Enum.each(transactions, fn t ->
  # This runs a query for EACH transaction (N queries)
  positions = Repo.all(assoc(t, :positions))  # Query per transaction!
end)
# Total: 1 + N queries (very slow for many transactions)

# Good - preload associations
transactions =
  Transaction
  |> preload(:positions)  # Tells Ecto to load positions efficiently
  |> Repo.all()
# Total: 2 queries regardless of transaction count
# 1st query: SELECT * FROM transactions
# 2nd query: SELECT * FROM positions WHERE transaction_id IN (...)
```

## 11. Code Organization Patterns

### 11.1 Function Naming

Be consistent and clear:

```elixir
# Commands - perform actions (may have side effects)
def create_account(attrs)      # Returns {:ok, account} or {:error, changeset}
def update_account(account, attrs)  # Modifies existing data
def delete_account(account)    # Removes from database

# Queries - return data (no side effects)
def get_account!(id)           # Raises if not found (bang = exception)
def get_account(id)            # Returns nil if not found
def list_accounts()            # Returns list, empty if none

# Predicates - return boolean (end with ?)
def account_exists?(path)      # true/false
def can_delete?(account)       # Business rule check
def valid_amount?(amount)      # Validation check

# Transformations - convert between representations
def to_string(amount)          # Amount -> String
def from_csv(row)             # CSV row -> Account struct
```

### 11.2 Module Organization

Group related functionality:

```elixir
defmodule Ledger.Transactions do
  # Module structure convention:

  # 1. Public API at top - what other modules use
  def create_transaction(attrs), do: ...
  def list_transactions(opts), do: ...

  # 2. Delegations - explicit dependencies
  defdelegate calculate_balance(account, date), to: BalanceCalculator

  # 3. Private helpers at bottom - implementation details
  defp validate_something(data), do: ...
  defp transform_data(input), do: ...

  # This organization makes the module's interface clear
end
```

### 11.3 Documentation Pattern

Document intention, not implementation:

```elixir
@doc """
Distributes an amount into n equal parts, with any remainder
added to the last part to ensure the sum equals the original.

## Examples

    iex> Amount.distribute(Amount.new(100), 3)
    [#Amount<33.33>, #Amount<33.33>, #Amount<33.34>]

## Arguments

  * `amount` - The amount to distribute
  * `n` - Number of parts (must be positive)

## Returns

A list of n Amount structs that sum to the original amount.
"""
@spec distribute(t(), pos_integer()) :: [t()]  # Type specification
def distribute(amount, n) when n > 0 do
  # Guard clause ensures n is positive at compile time
  # Implementation details hidden from docs
end

# Documentation best practices:
# - Start with one-line summary
# - Provide concrete examples
# - Document all parameters
# - Explain return value
# - Add @spec for type checking
```

These patterns form the foundation of well-structured, maintainable Elixir code that follows community best practices and leverages the strengths of the language and runtime.
