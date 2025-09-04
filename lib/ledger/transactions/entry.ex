defmodule Ledger.Transactions.Entry do
  @moduledoc """
  Represents a bookkeeping entry (transaction) in the ledger.

  An Entry is the core unit of recording financial events. Each entry contains
  a date, description, and a collection of positions that must balance to zero.
  Entries go through a lifecycle: draft → posted → (optionally) voided.

  The Entry enforces the fundamental rule of our simplified ledger: all positions
  must sum to zero, ensuring that money always has a source and destination.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Ledger.Transactions.{Entry, Position}
  alias Ledger.Amount

  @type status :: :draft | :posted | :void
  @type t :: %__MODULE__{
          id: integer() | nil,
          date: Date.t(),
          description: String.t(),
          reference: String.t() | nil,
          status: status(),
          posted_at: DateTime.t() | nil,
          posted_by_id: integer() | nil,
          voided_at: DateTime.t() | nil,
          voided_by_id: integer() | nil,
          void_reason: String.t() | nil,
          positions: [Position.t()],
          created_by_id: integer(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @valid_statuses [:draft, :posted, :void]

  schema "entries" do
    # The date when this transaction occurred
    # This is the business date, not when it was recorded
    field(:date, :date)

    # Human-readable description of what this entry represents
    field(:description, :string)

    # Optional reference number for external tracking
    # Could be invoice numbers, check numbers, etc.
    field(:reference, :string)

    # Entry lifecycle status
    field(:status, Ecto.Enum, values: @valid_statuses, default: :draft)

    # Posting information - when and by whom
    field(:posted_at, :utc_datetime)
    field(:posted_by_id, :integer)

    # Void information - entries are never deleted, only voided
    field(:voided_at, :utc_datetime)
    field(:voided_by_id, :integer)
    field(:void_reason, :string)

    # The individual account movements
    has_many(:positions, Position, on_replace: :delete)

    # Audit field
    field(:created_by_id, :integer)

    timestamps(type: :utc_datetime)
  end

  # Changeset functions
  # These ensure data integrity and enforce business rules

  @doc """
  Creates a changeset for a new entry.

  Validates all required fields and ensures the entry follows business rules.
  Positions are validated through nested changesets.
  """
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:date, :description, :reference, :created_by_id])
    |> validate_required([:date, :description, :created_by_id])
    |> validate_length(:description, min: 3, max: 500)
    |> validate_length(:reference, max: 50)
    |> validate_date()
    |> cast_assoc(:positions, required: true, with: &Position.changeset/2)
    |> validate_positions()
  end

  @doc """
  Creates a changeset for posting an entry.

  Posting locks the entry and makes it permanent in the ledger.
  Additional validations ensure the entry is ready to be posted.
  """
  def post_changeset(entry, user_id) do
    entry
    |> change(%{
      status: :posted,
      posted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      posted_by_id: user_id
    })
    |> validate_can_post()
  end

  @doc """
  Creates a changeset for voiding an entry.

  Voiding creates a reversal of the original entry while maintaining
  the audit trail. A reason must be provided for compliance.
  """
  def void_changeset(entry, user_id, reason) do
    entry
    |> change(%{
      status: :void,
      voided_at: DateTime.utc_now() |> DateTime.truncate(:second),
      voided_by_id: user_id,
      void_reason: reason
    })
    |> validate_required([:void_reason])
    |> validate_length(:void_reason, min: 5, max: 500)
    |> validate_can_void()
  end

  # Validation functions
  # These implement business rules and ensure data consistency

  defp validate_date(changeset) do
    case get_field(changeset, :date) do
      nil ->
        changeset

      date ->
        today = Date.utc_today()

        cond do
          Date.compare(date, today) == :gt ->
            add_error(changeset, :date, :future_date_not_allowed)

          Date.diff(today, date) > Ledger.Config.max_backdate_days() ->
            add_error(
              changeset,
              :date,
              {:exceeds_backdate_limit, Ledger.Config.max_backdate_days()}
            )

          true ->
            changeset
        end
    end
  end

  defp validate_positions(changeset) do
    positions = get_field(changeset, :positions, [])

    changeset
    |> validate_minimum_positions(positions)
    |> validate_maximum_positions(positions)
    |> validate_positions_balance(positions)
    |> validate_unique_accounts(positions)
  end

  defp validate_minimum_positions(changeset, positions) do
    if length(positions) < 2 do
      add_error(changeset, :positions, :insufficient_positions)
    else
      changeset
    end
  end

  defp validate_maximum_positions(changeset, positions) do
    max = Ledger.Config.max_transaction_positions()

    if length(positions) > max do
      add_error(changeset, :positions, {:exceeds_max_positions, max})
    else
      changeset
    end
  end

  defp validate_positions_balance(changeset, positions) do
    # Skip validation if any position has errors
    if Enum.any?(positions, &(!&1.valid?)) do
      changeset
    else
      # Calculate the sum of all positions
      sum =
        positions
        |> Enum.map(&(&1.changes[:amount] || &1.data.amount))
        |> Enum.filter(& &1)
        |> Amount.sum()

      if Amount.zero?(sum) do
        changeset
      else
        add_error(changeset, :positions, :transaction_not_balanced)
      end
    end
  end

  defp validate_unique_accounts(changeset, positions) do
    # Extract account IDs from valid positions
    account_ids =
      positions
      |> Enum.filter(& &1.valid?)
      |> Enum.map(&get_field(&1, :account_id))
      |> Enum.filter(& &1)

    if length(account_ids) != length(Enum.uniq(account_ids)) do
      add_error(changeset, :positions, :duplicate_accounts)
    else
      changeset
    end
  end

  defp validate_can_post(changeset) do
    entry = changeset.data

    cond do
      entry.status != :draft ->
        add_error(changeset, :status, :already_posted)

      # Add more validation here when period closing is implemented
      true ->
        changeset
    end
  end

  defp validate_can_void(changeset) do
    entry = changeset.data

    cond do
      entry.status != :posted ->
        add_error(changeset, :status, :not_posted)

      # Add more validation here for void restrictions
      true ->
        changeset
    end
  end

  # Query functions
  # These provide reusable queries for common operations

  @doc """
  Returns a query for entries within a date range.
  """
  def by_date_range_query(from_date, to_date) do
    from(e in Entry,
      where: e.date >= ^from_date and e.date <= ^to_date,
      order_by: [desc: e.date, desc: e.id]
    )
  end

  @doc """
  Returns a query for entries by status.
  """
  def by_status_query(status) when status in @valid_statuses do
    from(e in Entry,
      where: e.status == ^status,
      order_by: [desc: e.date, desc: e.id]
    )
  end

  @doc """
  Returns a query for entries with their positions preloaded.
  """
  def with_positions_query do
    from(e in Entry,
      preload: [positions: :account]
    )
  end

  @doc """
  Returns a query to search entries by description or reference.
  """
  def search_query(search_term) do
    search_pattern = "%#{search_term}%"

    from(e in Entry,
      where: ilike(e.description, ^search_pattern) or ilike(e.reference, ^search_pattern),
      order_by: [desc: e.date, desc: e.id]
    )
  end

  # Helper functions
  # These provide convenient access to entry properties

  @doc """
  Checks if an entry can be edited.

  Only draft entries can be edited. Posted and voided entries are immutable.
  """
  def editable?(%Entry{status: :draft}), do: true
  def editable?(%Entry{}), do: false

  @doc """
  Checks if an entry can be posted.
  """
  def can_post?(%Entry{status: :draft}), do: true
  def can_post?(%Entry{}), do: false

  @doc """
  Checks if an entry can be voided.
  """
  def can_void?(%Entry{status: :posted}), do: true
  def can_void?(%Entry{}), do: false

  @doc """
  Returns the total amount of the entry (sum of positive positions).
  """
  def total_amount(%Entry{positions: positions}) when is_list(positions) do
    positions
    |> Enum.filter(&Position.positive?/1)
    |> Enum.map(& &1.amount)
    |> Amount.sum()
  end

  def total_amount(%Entry{}), do: Amount.zero()

  @doc """
  Formats an entry for display.
  """
  def display(%Entry{} = entry, format \\ :full)

  def display(%Entry{date: date, description: desc, reference: ref}, :full) do
    ref_part = if ref, do: " (#{ref})", else: ""
    "#{Date.to_string(date)} - #{desc}#{ref_part}"
  end

  def display(%Entry{description: desc}, :description) do
    desc
  end

  def display(%Entry{date: date, reference: ref}, :summary) do
    ref_part = if ref, do: " (#{ref})", else: ""
    "#{Date.to_string(date)}#{ref_part}"
  end
end
