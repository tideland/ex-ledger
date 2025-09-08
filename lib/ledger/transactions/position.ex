defmodule TidelandLedger.Transactions.Position do
  @moduledoc """
  Represents a single line item (position) within a bookkeeping entry.

  Each Position records how a specific account is affected by a transaction.
  A positive amount represents money flowing into the account (debit in traditional
  bookkeeping), while a negative amount represents money flowing out (credit).

  Positions must reference valid, active accounts and contain amounts that,
  when summed with all other positions in the entry, equal zero.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias TidelandLedger.Transactions.{Entry, Position}
  alias TidelandLedger.Accounts.Account
  alias TidelandLedger.Amount

  @type t :: %__MODULE__{
          id: integer() | nil,
          entry_id: integer(),
          account_id: integer(),
          amount: Amount.t(),
          description: String.t() | nil,
          tax_relevant: boolean(),
          position: integer(),
          entry: Entry.t() | Ecto.Association.NotLoaded.t(),
          account: Account.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "positions" do
    # The monetary amount for this position
    # Stored as an embedded schema to maintain precision
    field(:amount, TidelandLedger.EctoTypes.Amount)

    # Optional description specific to this position
    # Can provide more detail than the entry description
    field(:description, :string)

    # Flag for tax relevance
    # Used to mark positions that should be included in tax reports
    field(:tax_relevant, :boolean, default: false)

    # Order within the entry (1, 2, 3, ...)
    # Ensures consistent display order
    field(:position, :integer)

    # Relationships
    belongs_to(:entry, Entry)
    belongs_to(:account, Account)

    timestamps(type: :utc_datetime)
  end

  # Changeset functions
  # These ensure positions are valid and maintain data integrity

  @doc """
  Creates a changeset for a position.

  Validates all fields and ensures the position follows business rules,
  including account existence and activity status.
  """
  def changeset(position, attrs) do
    position
    |> cast(attrs, [:account_id, :amount, :description, :tax_relevant, :position])
    |> validate_required([:account_id, :amount])
    |> validate_length(:description, max: 200)
    |> validate_number(:position, greater_than: 0, less_than_or_equal_to: 999)
    |> validate_amount()
    |> foreign_key_constraint(:account_id)
    |> foreign_key_constraint(:entry_id)
  end

  # Validation functions
  # These implement business rules specific to positions

  defp validate_amount(changeset) do
    case get_field(changeset, :amount) do
      nil ->
        changeset

      %Amount{cents: 0} ->
        add_error(changeset, :amount, :zero_amount_not_allowed)

      %Amount{} ->
        changeset

      _ ->
        add_error(changeset, :amount, :invalid_amount)
    end
  end

  # Query functions
  # These provide reusable queries for positions

  @doc """
  Returns a query for positions belonging to a specific account.
  """
  def by_account_query(account_id) do
    from(p in Position,
      where: p.account_id == ^account_id,
      join: e in assoc(p, :entry),
      where: e.status == :posted,
      order_by: [desc: e.date, asc: p.position],
      preload: [:entry]
    )
  end

  @doc """
  Returns a query for positions within a date range.
  """
  def by_date_range_query(account_id, from_date, to_date) do
    from(p in by_account_query(account_id),
      join: e in assoc(p, :entry),
      where: e.date >= ^from_date and e.date <= ^to_date
    )
  end

  @doc """
  Returns a query for tax-relevant positions.
  """
  def tax_relevant_query(from_date, to_date) do
    from(p in Position,
      join: e in assoc(p, :entry),
      where: p.tax_relevant == true,
      where: e.status == :posted,
      where: e.date >= ^from_date and e.date <= ^to_date,
      order_by: [e.date, p.position],
      preload: [:entry, :account]
    )
  end

  # Helper functions
  # These provide convenient access to position properties

  @doc """
  Checks if a position has a positive amount (money flowing in).
  """
  def positive?(%Position{amount: amount}) do
    Amount.positive?(amount)
  end

  @doc """
  Checks if a position has a negative amount (money flowing out).
  """
  def negative?(%Position{amount: amount}) do
    Amount.negative?(amount)
  end

  @doc """
  Returns the absolute amount of the position.
  """
  def absolute_amount(%Position{amount: amount}) do
    Amount.abs(amount)
  end

  @doc """
  Formats a position for display.
  """
  def display(position, format \\ :full)

  def display(%Position{account: %Account{} = account, amount: amount}, :full) do
    "#{Account.display(account)} #{Amount.to_string(amount)}"
  end

  def display(%Position{account: %Ecto.Association.NotLoaded{}, amount: amount}, :full) do
    "#{amount}"
  end

  def display(%Position{amount: amount}, :amount_only) do
    Amount.to_string(amount)
  end

  def display(%Position{account: %Account{} = account}, :account_only) do
    Account.display(account)
  end

  @doc """
  Creates a reversal position for voiding.

  When an entry is voided, each position needs to be reversed
  to cancel out the original effect.
  """
  def reversal(%Position{} = position) do
    %Position{
      account_id: position.account_id,
      amount: Amount.negate(position.amount),
      description: position.description,
      tax_relevant: position.tax_relevant,
      position: position.position
    }
  end

  @doc """
  Groups positions by account for summary displays.

  Returns a map with account_id as key and sum of amounts as value.
  """
  def group_by_account(positions) when is_list(positions) do
    positions
    |> Enum.group_by(& &1.account_id)
    |> Enum.map(fn {account_id, account_positions} ->
      sum =
        account_positions
        |> Enum.map(& &1.amount)
        |> Amount.sum()

      {account_id, sum}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Checks if a list of positions is balanced (sums to zero).
  """
  def balanced?(positions) when is_list(positions) do
    sum =
      positions
      |> Enum.map(& &1.amount)
      |> Amount.sum()

    Amount.zero?(sum)
  end

  @doc """
  Validates that all positions have unique accounts.
  """
  def unique_accounts?(positions) when is_list(positions) do
    account_ids = Enum.map(positions, & &1.account_id)
    length(account_ids) == length(Enum.uniq(account_ids))
  end

  @doc """
  Sorts positions by their position field.
  """
  def sort_by_position(positions) when is_list(positions) do
    Enum.sort_by(positions, & &1.position)
  end

  @doc """
  Assigns sequential position numbers to a list of positions.
  """
  def assign_position_numbers(positions) when is_list(positions) do
    positions
    |> Enum.with_index(1)
    |> Enum.map(fn {position, index} ->
      %{position | position: index}
    end)
  end
end
