defmodule TidelandLedger.Transactions do
  @moduledoc """
  The Transactions context manages all bookkeeping entries and positions.

  This module provides the public API for creating, posting, and managing
  transactions in the ledger. It enforces business rules such as balance
  validation, period closing checks, and ensures data integrity across
  all transaction operations.

  All monetary transactions in the system should go through this context
  to maintain consistency and enforce accounting rules.
  """

  import Ecto.Query
  alias Ecto.Multi

  alias TidelandLedger.Repo
  alias TidelandLedger.Transactions.{Entry, Position}
  alias TidelandLedger.Accounts
  alias TidelandLedger.Accounts.Account
  alias TidelandLedger.Amount

  # Entry Management
  # These functions handle the creation and modification of entries

  @doc """
  Creates a new draft entry with the given attributes.

  The entry is created in draft status and can be edited until posted.
  All positions must balance to zero before the entry can be saved.

  ## Examples

      iex> create_entry(%{
      ...>   date: ~D[2024-01-15],
      ...>   description: "Office supplies",
      ...>   positions: [
      ...>     %{account_id: 1, amount: Amount.new(50)},
      ...>     %{account_id: 2, amount: Amount.new(-50)}
      ...>   ],
      ...>   created_by_id: 1
      ...> })
      {:ok, %Entry{}}

      iex> create_entry(%{date: nil})
      {:error, %Ecto.Changeset{}}
  """
  def create_entry(attrs \\ %{}) do
    # Start a transaction to ensure all validations pass
    Multi.new()
    |> Multi.run(:validate_accounts, fn _repo, _changes ->
      validate_position_accounts(attrs[:positions] || [])
    end)
    |> Multi.run(:validate_period, fn _repo, _changes ->
      validate_period_open(attrs[:date])
    end)
    |> Multi.insert(:entry, fn _changes ->
      Entry.changeset(%Entry{}, attrs)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{entry: entry}} ->
        {:ok, preload_entry(entry)}

      {:error, :validate_accounts, reason, _} ->
        {:error, :accounts, reason}

      {:error, :validate_period, reason, _} ->
        {:error, :period, reason}

      {:error, :entry, changeset, _} ->
        {:error, changeset}
    end
  end

  @doc """
  Updates a draft entry with the given attributes.

  Only draft entries can be updated. Posted and voided entries are immutable.

  ## Examples

      iex> update_entry(draft_entry, %{description: "Updated description"})
      {:ok, %Entry{}}

      iex> update_entry(posted_entry, %{description: "New description"})
      {:error, :entry_not_editable}
  """
  def update_entry(%Entry{} = entry, attrs) do
    if Entry.editable?(entry) do
      Multi.new()
      |> Multi.run(:validate_accounts, fn _repo, _changes ->
        validate_position_accounts(attrs[:positions] || [])
      end)
      |> Multi.run(:validate_period, fn _repo, _changes ->
        validate_period_open(attrs[:date] || entry.date)
      end)
      |> Multi.update(:entry, Entry.changeset(entry, attrs))
      |> Repo.transaction()
      |> case do
        {:ok, %{entry: entry}} ->
          {:ok, preload_entry(entry)}

        {:error, :validate_accounts, reason, _} ->
          {:error, :accounts, reason}

        {:error, :validate_period, reason, _} ->
          {:error, :period, reason}

        {:error, :entry, changeset, _} ->
          {:error, changeset}
      end
    else
      {:error, :entry_not_editable}
    end
  end

  @doc """
  Deletes a draft entry.

  Only draft entries can be deleted. Posted entries must be voided instead.

  ## Examples

      iex> delete_entry(draft_entry)
      {:ok, %Entry{}}

      iex> delete_entry(posted_entry)
      {:error, :entry_not_deletable}
  """
  def delete_entry(%Entry{} = entry) do
    if Entry.editable?(entry) do
      Repo.delete(entry)
    else
      {:error, :entry_not_deletable}
    end
  end

  # Entry Posting and Voiding
  # These functions handle state transitions for entries

  @doc """
  Posts a draft entry, making it permanent in the ledger.

  Posting an entry:
  - Validates the entry is balanced
  - Checks all referenced accounts are active
  - Verifies the period is not closed
  - Updates account balances (in reporting views)
  - Creates an audit trail

  ## Examples

      iex> post_entry(draft_entry, user_id)
      {:ok, %Entry{status: :posted}}

      iex> post_entry(posted_entry, user_id)
      {:error, :already_posted}
  """
  def post_entry(%Entry{} = entry, user_id) do
    Multi.new()
    |> Multi.run(:validate_can_post, fn _repo, _changes ->
      if Entry.can_post?(entry) do
        {:ok, true}
      else
        {:error, :already_posted}
      end
    end)
    |> Multi.run(:validate_period, fn _repo, _changes ->
      validate_period_open(entry.date)
    end)
    |> Multi.run(:validate_accounts_active, fn _repo, _changes ->
      validate_all_accounts_active(entry)
    end)
    |> Multi.update(:entry, Entry.post_changeset(entry, user_id))
    |> Multi.run(:create_audit_log, fn _repo, %{entry: posted_entry} ->
      create_audit_log(posted_entry, :posted, user_id)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{entry: entry}} ->
        {:ok, preload_entry(entry)}

      {:error, :validate_can_post, reason, _} ->
        {:error, reason}

      {:error, :validate_period, reason, _} ->
        {:error, :period, reason}

      {:error, :validate_accounts_active, reason, _} ->
        {:error, :accounts, reason}

      {:error, :entry, changeset, _} ->
        {:error, changeset}
    end
  end

  @doc """
  Voids a posted entry by creating a reversal.

  Voiding an entry:
  - Requires a reason for audit purposes
  - Creates reversal entries to cancel the effect
  - Maintains the original entry for historical record
  - Updates the status and audit fields

  ## Examples

      iex> void_entry(posted_entry, user_id, "Duplicate entry")
      {:ok, %Entry{status: :void}}

      iex> void_entry(draft_entry, user_id, "Reason")
      {:error, :not_posted}
  """
  def void_entry(%Entry{} = entry, user_id, reason) do
    Multi.new()
    |> Multi.run(:validate_can_void, fn _repo, _changes ->
      if Entry.can_void?(entry) do
        {:ok, true}
      else
        {:error, :not_posted}
      end
    end)
    |> Multi.update(:void_entry, Entry.void_changeset(entry, user_id, reason))
    |> Multi.run(:create_reversal, fn _repo, %{void_entry: voided_entry} ->
      create_reversal_entry(voided_entry, user_id)
    end)
    |> Multi.run(:create_audit_log, fn _repo, %{void_entry: voided_entry} ->
      create_audit_log(voided_entry, :voided, user_id)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{void_entry: entry, create_reversal: reversal}} ->
        {:ok, {preload_entry(entry), preload_entry(reversal)}}

      {:error, :validate_can_void, reason, _} ->
        {:error, reason}

      {:error, :void_entry, changeset, _} ->
        {:error, changeset}

      {:error, :create_reversal, reason, _} ->
        {:error, :reversal, reason}
    end
  end

  # Query Functions
  # These provide access to entries with various filters

  @doc """
  Lists entries with optional filters.

  ## Options

    * `:status` - Filter by entry status (:draft, :posted, :void)
    * `:from_date` - Start date for date range filter
    * `:to_date` - End date for date range filter
    * `:account_id` - Filter by entries containing this account
    * `:search` - Search in description and reference fields
    * `:limit` - Maximum number of entries to return
    * `:offset` - Number of entries to skip (for pagination)
    * `:preload` - List of associations to preload

  ## Examples

      iex> list_entries(status: :posted, from_date: ~D[2024-01-01])
      [%Entry{}, ...]
  """
  def list_entries(opts \\ []) do
    base_query = from(e in Entry)

    base_query
    |> filter_by_status(opts[:status])
    |> filter_by_date_range(opts[:from_date], opts[:to_date])
    |> filter_by_account(opts[:account_id])
    |> filter_by_search(opts[:search])
    |> order_by([e], desc: e.date, desc: e.id)
    |> limit_offset(opts[:limit], opts[:offset])
    |> maybe_preload(opts[:preload] || [:positions])
    |> Repo.all()
  end

  @doc """
  Gets a single entry by ID.

  Returns nil if the entry does not exist.

  ## Examples

      iex> get_entry(123)
      %Entry{}

      iex> get_entry(999)
      nil
  """
  def get_entry(id, opts \\ []) do
    Entry
    |> where(id: ^id)
    |> maybe_preload(opts[:preload] || [:positions])
    |> Repo.one()
  end

  @doc """
  Gets a single entry by ID, raises if not found.

  ## Examples

      iex> get_entry!(123)
      %Entry{}

      iex> get_entry!(999)
      ** (Ecto.NoResultsError)
  """
  def get_entry!(id, opts \\ []) do
    Entry
    |> where(id: ^id)
    |> maybe_preload(opts[:preload] || [:positions])
    |> Repo.one!()
  end

  # Position Management
  # These functions work with individual positions

  @doc """
  Lists positions for a specific account with optional filters.

  ## Options

    * `:from_date` - Start date for date range filter
    * `:to_date` - End date for date range filter
    * `:posted_only` - Only include positions from posted entries
    * `:limit` - Maximum number of positions to return
    * `:offset` - Number of positions to skip
    * `:preload` - List of associations to preload

  ## Examples

      iex> list_positions_for_account(account_id, from_date: ~D[2024-01-01])
      [%Position{}, ...]
  """
  def list_positions_for_account(account_id, opts \\ []) do
    Position
    |> where(account_id: ^account_id)
    |> join(:inner, [p], e in assoc(p, :entry))
    |> filter_positions_by_date(opts[:from_date], opts[:to_date])
    |> filter_positions_by_status(opts[:posted_only])
    |> order_by([p, e], desc: e.date, asc: p.position)
    |> limit_offset(opts[:limit], opts[:offset])
    |> maybe_preload(opts[:preload] || [:entry])
    |> Repo.all()
  end

  @doc """
  Calculates the balance for an account up to a specific date.

  Only includes positions from posted entries.

  ## Examples

      iex> get_account_balance(account_id, ~D[2024-01-31])
      %Amount{cents: 150000, currency: "EUR"}
  """
  def get_account_balance(account_id, as_of_date \\ Date.utc_today()) do
    query =
      from(p in Position,
        join: e in assoc(p, :entry),
        where: p.account_id == ^account_id,
        where: e.status == :posted,
        where: e.date <= ^as_of_date,
        select: p.amount
      )

    amounts = Repo.all(query)

    case amounts do
      [] -> Amount.zero()
      amounts -> Amount.sum(amounts)
    end
  end

  # Validation Functions
  # These ensure business rules are followed

  defp validate_position_accounts([]), do: {:ok, []}

  defp validate_position_accounts(positions) do
    account_ids =
      positions
      |> Enum.map(& &1[:account_id])
      |> Enum.filter(& &1)
      |> Enum.uniq()

    case validate_accounts_exist_and_active(account_ids) do
      {:ok, _accounts} -> {:ok, positions}
      error -> error
    end
  end

  defp validate_accounts_exist_and_active([]), do: {:ok, []}

  defp validate_accounts_exist_and_active(account_ids) do
    accounts =
      Account
      |> where([a], a.id in ^account_ids)
      |> where(active: true)
      |> Repo.all()

    found_ids = Enum.map(accounts, & &1.id)
    missing_ids = account_ids -- found_ids

    if missing_ids == [] do
      {:ok, accounts}
    else
      {:error, {:accounts_not_found_or_inactive, missing_ids}}
    end
  end

  defp validate_all_accounts_active(%Entry{} = entry) do
    entry = Repo.preload(entry, positions: :account)

    inactive_accounts =
      entry.positions
      |> Enum.map(& &1.account)
      |> Enum.reject(& &1.active)

    if inactive_accounts == [] do
      {:ok, entry}
    else
      {:error, {:inactive_accounts, Enum.map(inactive_accounts, & &1.path)}}
    end
  end

  defp validate_period_open(nil), do: {:error, :date_required}

  defp validate_period_open(date) do
    # This is a placeholder for period closing functionality
    # Will be implemented when period management is added
    # For now, always return ok
    {:ok, date}
  end

  # Helper Functions
  # These support the main functionality

  defp create_reversal_entry(%Entry{} = original_entry, user_id) do
    original_entry = Repo.preload(original_entry, :positions)

    reversal_attrs = %{
      date: Date.utc_today(),
      description: "Storno: #{original_entry.description}",
      reference: original_entry.reference,
      created_by_id: user_id,
      positions:
        Enum.map(original_entry.positions, fn pos ->
          %{
            account_id: pos.account_id,
            amount: Amount.negate(pos.amount),
            description: pos.description,
            tax_relevant: pos.tax_relevant,
            position: pos.position
          }
        end)
    }

    case create_entry(reversal_attrs) do
      {:ok, reversal} ->
        # Auto-post the reversal
        post_entry(reversal, user_id)

      error ->
        error
    end
  end

  defp create_audit_log(%Entry{} = entry, action, user_id) do
    # Placeholder for audit log functionality
    # Will be implemented with the audit system
    {:ok, entry}
  end

  defp preload_entry(entry) do
    Repo.preload(entry, [:positions])
  end

  # Query Filter Functions
  # These build query conditions

  defp filter_by_status(query, nil), do: query
  defp filter_by_status(query, status), do: where(query, [e], e.status == ^status)

  defp filter_by_date_range(query, nil, nil), do: query
  defp filter_by_date_range(query, from_date, nil), do: where(query, [e], e.date >= ^from_date)
  defp filter_by_date_range(query, nil, to_date), do: where(query, [e], e.date <= ^to_date)

  defp filter_by_date_range(query, from_date, to_date) do
    where(query, [e], e.date >= ^from_date and e.date <= ^to_date)
  end

  defp filter_by_account(query, nil), do: query

  defp filter_by_account(query, account_id) do
    from(e in query,
      join: p in assoc(e, :positions),
      where: p.account_id == ^account_id,
      distinct: true
    )
  end

  defp filter_by_search(query, nil), do: query
  defp filter_by_search(query, ""), do: query

  defp filter_by_search(query, search_term) do
    search_pattern = "%#{search_term}%"

    where(
      query,
      [e],
      ilike(e.description, ^search_pattern) or ilike(e.reference, ^search_pattern)
    )
  end

  defp filter_positions_by_date(query, nil, nil), do: query

  defp filter_positions_by_date(query, from_date, nil) do
    where(query, [p, e], e.date >= ^from_date)
  end

  defp filter_positions_by_date(query, nil, to_date) do
    where(query, [p, e], e.date <= ^to_date)
  end

  defp filter_positions_by_date(query, from_date, to_date) do
    where(query, [p, e], e.date >= ^from_date and e.date <= ^to_date)
  end

  defp filter_positions_by_status(query, true) do
    where(query, [p, e], e.status == :posted)
  end

  defp filter_positions_by_status(query, _), do: query

  defp limit_offset(query, nil, nil), do: query
  defp limit_offset(query, limit, nil), do: limit(query, ^limit)
  defp limit_offset(query, nil, offset), do: offset(query, ^offset)

  defp limit_offset(query, limit, offset) do
    query
    |> limit(^limit)
    |> offset(^offset)
  end

  defp maybe_preload(query, nil), do: query
  defp maybe_preload(query, []), do: query
  defp maybe_preload(query, preloads), do: preload(query, ^preloads)

  # Summary and Reporting Functions
  # These provide aggregated data for reports

  @doc """
  Generates a trial balance for a specific date.

  Returns a list of accounts with their debit and credit totals.

  ## Examples

      iex> trial_balance(~D[2024-01-31])
      [
        %{account: %Account{}, debit: %Amount{}, credit: %Amount{}, balance: %Amount{}},
        ...
      ]
  """
  def trial_balance(as_of_date \\ Date.utc_today()) do
    query =
      from(a in Account,
        left_join: p in Position,
        on: p.account_id == a.id,
        left_join: e in Entry,
        on: e.id == p.entry_id and e.status == :posted and e.date <= ^as_of_date,
        group_by: a.id,
        select: %{
          account: a,
          positions:
            fragment(
              "COALESCE(json_agg(json_build_object('amount', ?)::jsonb) FILTER (WHERE ? IS NOT NULL), '[]'::json)",
              p.amount,
              p.id
            )
        }
      )

    query
    |> Repo.all()
    |> Enum.map(fn %{account: account, positions: positions} ->
      amounts = Enum.map(positions, & &1["amount"])

      {debit_amounts, credit_amounts} =
        Enum.split_with(amounts, fn amount ->
          amount && amount["cents"] > 0
        end)

      debit_total = calculate_total(debit_amounts)
      credit_total = calculate_total(credit_amounts)
      balance = Amount.subtract(debit_total, credit_total)

      %{
        account: account,
        debit: debit_total,
        credit: Amount.abs(credit_total),
        balance: balance
      }
    end)
    |> Enum.reject(fn %{balance: balance} -> Amount.zero?(balance) end)
    |> Enum.sort_by(& &1.account.path)
  end

  defp calculate_total([]), do: Amount.zero()

  defp calculate_total(amounts) do
    amounts
    |> Enum.map(fn amount_map ->
      Amount.from_cents(
        amount_map["cents"] || 0,
        amount_map["currency"] || "EUR"
      )
    end)
    |> Amount.sum()
  end
end
