defmodule Ledger.Accounts.Account do
  @moduledoc """
  Represents an account in the hierarchical chart of accounts.

  Accounts are the fundamental organizational structure of the ledger system.
  Each account has a unique path that represents its position in the hierarchy
  (e.g., "Ausgaben : Büro : Material"). The schema ensures data integrity through
  validations and maintains relationships with parent accounts and transactions.

  The account balance is not stored directly but calculated from the sum of all
  transaction positions that reference this account. This ensures the balance
  is always accurate and reflects the current state of the ledger.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Ledger.AccountPath
  alias Ledger.Accounts.Account
  alias Ledger.Config

  @type t :: %__MODULE__{
          id: integer() | nil,
          path: String.t(),
          name: String.t(),
          description: String.t() | nil,
          parent_path: String.t() | nil,
          depth: integer(),
          active: boolean(),
          created_by_id: integer(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "accounts" do
    # The full hierarchical path (e.g., "Ausgaben : Büro : Material")
    # This is the primary way to identify accounts
    field(:path, :string)

    # The account name (just the leaf, e.g., "Material")
    # Extracted from the path for easier display and searching
    field(:name, :string)

    # Optional description for documentation purposes
    field(:description, :string)

    # Parent account path for hierarchy queries
    # NULL for root accounts
    field(:parent_path, :string)

    # Depth in the hierarchy (1 for root accounts)
    # Cached for efficient querying
    field(:depth, :integer)

    # Whether this account can be used in new transactions
    # Inactive accounts remain for historical data but can't be used
    field(:active, :boolean, default: true)

    # Audit fields
    field(:created_by_id, :integer)

    timestamps(type: :utc_datetime)
  end

  # Changeset functions
  # These ensure data integrity and proper hierarchy maintenance

  @doc """
  Creates a changeset for creating or updating an account.

  Validates:
  - Path format and uniqueness
  - Parent account existence (if not root)
  - Maximum depth constraints
  - Name extraction from path

  ## Examples

      iex> Account.changeset(%Account{}, %{path: "Ausgaben : Büro", active: true})
      %Ecto.Changeset{valid?: true}
  """
  def changeset(account, attrs) do
    account
    |> cast(attrs, [:path, :description, :active, :created_by_id])
    |> validate_required([:path, :created_by_id])
    |> normalize_and_validate_path()
    |> extract_name_from_path()
    |> set_parent_path()
    |> set_depth()
    |> validate_length(:description, max: 500)
    |> unique_constraint(:path)
    |> foreign_key_constraint(:created_by_id)
  end

  @doc """
  Creates a changeset for deactivating an account.

  This is a separate changeset because deactivation has special rules:
  - Cannot deactivate if account has active child accounts
  - Cannot deactivate if account has recent transactions (configurable period)
  """
  def deactivate_changeset(account) do
    account
    |> change(active: false)
    |> validate_no_active_children()
    |> validate_no_recent_transactions()
  end

  # Validation functions
  # These ensure business rules are enforced at the database level

  defp normalize_and_validate_path(changeset) do
    case get_change(changeset, :path) do
      nil ->
        changeset

      path ->
        normalized = AccountPath.normalize(path)

        case AccountPath.validate(normalized) do
          :ok ->
            put_change(changeset, :path, normalized)

          {:error, :empty_path} ->
            add_error(changeset, :path, :empty_path)

          {:error, {:exceeds_max_depth, max}} ->
            add_error(changeset, :path, {:exceeds_max_depth, max})

          {:error, {:invalid_segment, segment}} ->
            add_error(changeset, :path, {:invalid_segment, segment})
        end
    end
  end

  defp extract_name_from_path(changeset) do
    case get_field(changeset, :path) do
      nil ->
        changeset

      path ->
        name = AccountPath.leaf(path)
        put_change(changeset, :name, name)
    end
  end

  defp set_parent_path(changeset) do
    case get_field(changeset, :path) do
      nil ->
        changeset

      path ->
        parent = AccountPath.parent(path)
        put_change(changeset, :parent_path, parent)
    end
  end

  defp set_depth(changeset) do
    case get_field(changeset, :path) do
      nil ->
        changeset

      path ->
        depth = AccountPath.depth(path)
        put_change(changeset, :depth, depth)
    end
  end

  defp validate_no_active_children(changeset) do
    account = changeset.data

    if account.id && has_active_children?(account) do
      add_error(
        changeset,
        :active,
        :has_active_children
      )
    else
      changeset
    end
  end

  defp validate_no_recent_transactions(changeset) do
    account = changeset.data
    days_to_check = Config.recent_transaction_days()

    if account.id && has_recent_transactions?(account, days_to_check) do
      add_error(
        changeset,
        :active,
        {:has_recent_transactions, days_to_check}
      )
    else
      changeset
    end
  end

  # Query functions
  # These provide reusable queries for common operations

  @doc """
  Returns a query for all root accounts (depth = 1).
  """
  def roots_query do
    from(a in __MODULE__,
      where: is_nil(a.parent_path),
      order_by: a.path
    )
  end

  @doc """
  Returns a query for all children of a given account path.
  """
  def children_query(parent_path) do
    from(a in __MODULE__,
      where: a.parent_path == ^parent_path,
      order_by: a.path
    )
  end

  @doc """
  Returns a query for all descendants of a given account path.
  """
  def descendants_query(ancestor_path) do
    # This uses a LIKE query which works well for our path structure
    like_pattern = "#{ancestor_path} : %"

    from(a in __MODULE__,
      where: like(a.path, ^like_pattern),
      order_by: a.path
    )
  end

  @doc """
  Returns a query for all ancestors of a given account.
  """
  def ancestors_query(account) do
    ancestor_paths = AccountPath.ancestors_without_self(account.path)

    from(a in __MODULE__,
      where: a.path in ^ancestor_paths,
      order_by: a.depth
    )
  end

  @doc """
  Returns a query for active accounts only.
  """
  def active_query do
    from(a in __MODULE__,
      where: a.active == true
    )
  end

  @doc """
  Returns a query to search accounts by path or name.
  """
  def search_query(search_term) do
    search_pattern = "%#{search_term}%"

    from(a in __MODULE__,
      where: ilike(a.path, ^search_pattern) or ilike(a.name, ^search_pattern),
      order_by: [a.depth, a.path]
    )
  end

  # Helper functions
  # These encapsulate common business logic

  @doc """
  Checks if an account has any active child accounts.
  """
  def has_active_children?(%__MODULE__{path: path}) do
    query =
      from(a in children_query(path),
        where: a.active == true,
        select: count(a.id)
      )

    case Ledger.Repo.one(query) do
      0 -> false
      _ -> true
    end
  end

  @doc """
  Checks if an account has transactions within the specified number of days.
  """
  def has_recent_transactions?(%__MODULE__{id: account_id}, days) do
    # This assumes we have a positions table that links to accounts
    # We'll implement this properly when we create the Position schema
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)

    # Placeholder for now - will be implemented with Position schema
    # query =
    #   from p in Ledger.Transactions.Position,
    #   join: e in assoc(p, :entry),
    #   where: p.account_id == ^account_id and e.posted_at >= ^cutoff_date,
    #   select: count(p.id)
    #
    # Ledger.Repo.one(query) > 0

    # Temporary return value
    false
  end

  @doc """
  Builds a tree structure from a list of accounts.

  Returns a nested structure suitable for displaying hierarchical account lists.
  """
  def build_tree(accounts) when is_list(accounts) do
    # Group accounts by parent_path
    by_parent = Enum.group_by(accounts, & &1.parent_path)

    # Start with root accounts
    roots = Map.get(by_parent, nil, [])

    # Recursively build tree
    Enum.map(roots, &build_tree_node(&1, by_parent))
  end

  defp build_tree_node(account, by_parent) do
    children = Map.get(by_parent, account.path, [])

    %{
      account: account,
      children: Enum.map(children, &build_tree_node(&1, by_parent))
    }
  end

  @doc """
  Formats an account for display, with various format options.
  """
  def display(account, format \\ :full_path)

  def display(%__MODULE__{path: path, name: name}, :full_path) do
    path
  end

  def display(%__MODULE__{path: path, name: name}, :name_with_parents) do
    AccountPath.display(path, :compact)
  end

  def display(%__MODULE__{path: path, name: name}, :name_only) do
    name
  end

  def display(%__MODULE__{path: path, name: name, active: active}, :with_status) do
    status = if active, do: "", else: " (inaktiv)"
    "#{path}#{status}"
  end
end
