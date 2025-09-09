defmodule TidelandLedger.Accounts do
  @moduledoc """
  The Accounts context manages the hierarchical chart of accounts.

  This module provides the public API for managing accounts in the ledger system.
  It handles account creation, updates, activation/deactivation, and hierarchical
  queries. All account operations enforce the business rules defined in the
  account schema and ensure data consistency.

  The hierarchical nature of accounts is fundamental to the ledger system,
  enabling organized financial reporting and easy navigation of the chart
  of accounts.
  """

  import Ecto.Query
  alias Ecto.Multi

  alias TidelandLedger.Repo
  alias TidelandLedger.Accounts.Account
  alias TidelandLedger.AccountPath
  alias TidelandLedger.Auth.User

  # Account Management
  # These functions handle the creation, updates, and lifecycle of accounts

  @doc """
  Creates a new account with the given attributes.

  The account path is validated and normalized before creation. If the account
  has a parent, the parent must exist and be active. The account hierarchy is
  automatically maintained.

  ## Examples

      iex> create_account(%{
      ...>   path: "Ausgaben : Büro : Material",
      ...>   description: "Office supplies and materials",
      ...>   created_by_id: 1
      ...> })
      {:ok, %Account{}}

      iex> create_account(%{path: "Invalid::Path"})
      {:error, %Ecto.Changeset{}}
  """
  def create_account(attrs \\ %{}) do
    Multi.new()
    |> Multi.run(:validate_parent, fn _repo, _changes ->
      validate_parent_exists_and_active(attrs[:path])
    end)
    |> Multi.insert(:account, Account.changeset(%Account{}, attrs))
    |> Repo.transaction()
    |> case do
      {:ok, %{account: account}} ->
        {:ok, account}

      {:error, :validate_parent, reason, _} ->
        {:error, :parent, reason}

      {:error, :account, changeset, _} ->
        {:error, changeset}
    end
  end

  @doc """
  Updates an account with the given attributes.

  Path changes are not allowed as they would break the hierarchy and affect
  historical transactions. Only description and active status can be changed
  through normal updates.

  ## Examples

      iex> update_account(account, %{description: "Updated description"})
      {:ok, %Account{}}

      iex> update_account(account, %{path: "NewPath"})
      {:error, %Ecto.Changeset{}}  # Path changes not allowed
  """
  def update_account(%Account{} = account, attrs) do
    # Remove path from attrs to prevent accidental changes
    safe_attrs = Map.drop(attrs, [:path, "path"])

    account
    |> Account.changeset(safe_attrs)
    |> Repo.update()
  end

  @doc """
  Deactivates an account.

  This marks the account as inactive, preventing its use in new transactions
  while preserving historical data. Accounts with active children or recent
  transactions cannot be deactivated.

  ## Examples

      iex> deactivate_account(account)
      {:ok, %Account{active: false}}

      iex> deactivate_account(account_with_children)
      {:error, %Ecto.Changeset{}}  # Has active children
  """
  def deactivate_account(%Account{} = account) do
    account
    |> Account.deactivate_changeset()
    |> Repo.update()
  end

  @doc """
  Reactivates a previously deactivated account.

  All parent accounts must be active for the reactivation to succeed.

  ## Examples

      iex> reactivate_account(inactive_account)
      {:ok, %Account{active: true}}

      iex> reactivate_account(account_with_inactive_parent)
      {:error, :inactive_parent}
  """
  def reactivate_account(%Account{} = account) do
    Multi.new()
    |> Multi.run(:validate_parents_active, fn _repo, _changes ->
      validate_all_parents_active(account.path)
    end)
    |> Multi.update(:account, Account.changeset(account, %{active: true}))
    |> Repo.transaction()
    |> case do
      {:ok, %{account: account}} ->
        {:ok, account}

      {:error, :validate_parents_active, reason, _} ->
        {:error, reason}

      {:error, :account, changeset, _} ->
        {:error, changeset}
    end
  end

  @doc """
  Deletes an account.

  This is only allowed for accounts with no transactions and no children.
  In most cases, accounts should be deactivated rather than deleted to
  maintain audit trails.

  ## Examples

      iex> delete_account(unused_account)
      {:ok, %Account{}}

      iex> delete_account(account_with_transactions)
      {:error, :has_transactions}
  """
  def delete_account(%Account{} = account) do
    Multi.new()
    |> Multi.run(:validate_no_children, fn _repo, _changes ->
      if has_children?(account) do
        {:error, :has_children}
      else
        {:ok, account}
      end
    end)
    |> Multi.run(:validate_no_transactions, fn _repo, _changes ->
      if has_transactions?(account) do
        {:error, :has_transactions}
      else
        {:ok, account}
      end
    end)
    |> Multi.delete(:account, account)
    |> Repo.transaction()
    |> case do
      {:ok, %{account: account}} ->
        {:ok, account}

      {:error, step, reason, _} when step in [:validate_no_children, :validate_no_transactions] ->
        {:error, reason}

      {:error, :account, changeset, _} ->
        {:error, changeset}
    end
  end

  # Query Functions
  # These provide access to accounts with various filters and orderings

  @doc """
  Lists all accounts with optional filters.

  ## Options

    * `:active` - Filter by active status (true/false)
    * `:parent_path` - Filter by parent path
    * `:search` - Search in path, name, or description
    * `:max_depth` - Limit to accounts with depth <= max_depth
    * `:order_by` - Sort field (:path, :name, :depth, :created_at)
    * `:limit` - Maximum number of accounts to return
    * `:offset` - Number of accounts to skip

  ## Examples

      iex> list_accounts(active: true, max_depth: 2)
      [%Account{}, ...]

      iex> list_accounts(search: "Büro", order_by: :path)
      [%Account{}, ...]
  """
  def list_accounts(opts \\ []) do
    base_query = from(a in Account)

    base_query
    |> filter_by_active(opts[:active])
    |> filter_by_parent(opts[:parent_path])
    |> filter_by_search(opts[:search])
    |> filter_by_max_depth(opts[:max_depth])
    |> order_accounts(opts[:order_by] || :path)
    |> limit_offset(opts[:limit], opts[:offset])
    |> Repo.all()
  end

  @doc """
  Gets a single account by ID.

  Returns nil if the account does not exist.

  ## Examples

      iex> get_account(123)
      %Account{}

      iex> get_account(999)
      nil
  """
  def get_account(id) when is_integer(id) do
    Repo.get(Account, id)
  end

  @doc """
  Gets a single account by ID, raises if not found.

  ## Examples

      iex> get_account!(123)
      %Account{}

      iex> get_account!(999)
      ** (Ecto.NoResultsError)
  """
  def get_account!(id) when is_integer(id) do
    Repo.get!(Account, id)
  end

  @doc """
  Gets a single account by path.

  Returns nil if the account does not exist.

  ## Examples

      iex> get_account_by_path("Ausgaben : Büro")
      %Account{}

      iex> get_account_by_path("Nonexistent")
      nil
  """
  def get_account_by_path(path) when is_binary(path) do
    normalized_path = AccountPath.normalize(path)

    Account
    |> where(path: ^normalized_path)
    |> Repo.one()
  end

  @doc """
  Gets a single account by path, raises if not found.
  """
  def get_account_by_path!(path) when is_binary(path) do
    case get_account_by_path(path) do
      nil -> raise Ecto.NoResultsError, queryable: Account
      account -> account
    end
  end

  # Hierarchical Query Functions
  # These work with the hierarchical nature of accounts

  @doc """
  Lists all root accounts (accounts with no parent).

  ## Examples

      iex> list_root_accounts()
      [%Account{path: "Ausgaben"}, %Account{path: "Einnahmen"}, ...]
  """
  def list_root_accounts(opts \\ []) do
    Account.roots_query()
    |> filter_by_active(opts[:active])
    |> Repo.all()
  end

  @doc """
  Lists all children of the given account.

  ## Examples

      iex> list_children(parent_account)
      [%Account{}, ...]

      iex> list_children_by_path("Ausgaben")
      [%Account{}, ...]
  """
  def list_children(%Account{path: path}, opts \\ []) do
    list_children_by_path(path, opts)
  end

  def list_children_by_path(path, opts \\ []) when is_binary(path) do
    Account.children_query(path)
    |> filter_by_active(opts[:active])
    |> Repo.all()
  end

  @doc """
  Lists all descendants of the given account.

  This includes children, grandchildren, etc., but not the account itself.

  ## Examples

      iex> list_descendants(ancestor_account)
      [%Account{}, ...]
  """
  def list_descendants(%Account{path: path}, opts \\ []) do
    list_descendants_by_path(path, opts)
  end

  def list_descendants_by_path(path, opts \\ []) when is_binary(path) do
    Account.descendants_query(path)
    |> filter_by_active(opts[:active])
    |> Repo.all()
  end

  @doc """
  Lists all ancestors of the given account.

  This includes parent, grandparent, etc., but not the account itself.

  ## Examples

      iex> list_ancestors(account)
      [%Account{path: "Ausgaben"}, %Account{path: "Ausgaben : Büro"}]
  """
  def list_ancestors(%Account{} = account) do
    Account.ancestors_query(account)
    |> Repo.all()
  end

  @doc """
  Lists all siblings of the given account.

  These are accounts that share the same parent.

  ## Examples

      iex> list_siblings(account)
      [%Account{}, ...]
  """
  def list_siblings(%Account{path: path, parent_path: parent_path}) do
    case parent_path do
      nil ->
        # Root account - siblings are other root accounts
        list_root_accounts()
        |> Enum.reject(&(&1.path == path))

      parent_path ->
        list_children_by_path(parent_path)
        |> Enum.reject(&(&1.path == path))
    end
  end

  # Tree and Hierarchy Functions
  # These provide structured representations of the account hierarchy

  @doc """
  Builds a complete account tree from all accounts.

  Returns a nested structure suitable for display in hierarchical interfaces.

  ## Examples

      iex> build_account_tree()
      [
        %{account: %Account{path: "Ausgaben"}, children: [
          %{account: %Account{path: "Ausgaben : Büro"}, children: [...]},
          ...
        ]},
        ...
      ]
  """
  def build_account_tree(opts \\ []) do
    accounts = list_accounts(opts)
    Account.build_tree(accounts)
  end

  @doc """
  Builds an account tree starting from a specific root account.

  ## Examples

      iex> build_account_subtree("Ausgaben")
      %{account: %Account{path: "Ausgaben"}, children: [...]}
  """
  def build_account_subtree(root_path, opts \\ []) do
    root_account = get_account_by_path(root_path)

    if root_account do
      descendants = list_descendants(root_account, opts)
      all_accounts = [root_account | descendants]

      case Account.build_tree(all_accounts) do
        [subtree] -> subtree
        [] -> nil
        # Return first if multiple roots somehow
        multiple -> hd(multiple)
      end
    else
      nil
    end
  end

  @doc """
  Returns the account hierarchy as a flat list with indentation levels.

  This is useful for dropdown lists and other UI components that need
  to display hierarchy in a flat structure.

  ## Examples

      iex> flatten_account_hierarchy()
      [
        {%Account{path: "Ausgaben"}, 0},
        {%Account{path: "Ausgaben : Büro"}, 1},
        {%Account{path: "Ausgaben : Büro : Material"}, 2},
        ...
      ]
  """
  def flatten_account_hierarchy(opts \\ []) do
    tree = build_account_tree(opts)
    flatten_tree_nodes(tree, 0)
  end

  defp flatten_tree_nodes(nodes, level) do
    Enum.flat_map(nodes, fn %{account: account, children: children} ->
      [{account, level} | flatten_tree_nodes(children, level + 1)]
    end)
  end

  # Validation and Business Logic
  # These functions ensure business rules are followed

  @doc """
  Checks if an account path is available for creation.

  This validates the path format and ensures it doesn't conflict with
  existing accounts.

  ## Examples

      iex> path_available?("Ausgaben : Neues Konto")
      true

      iex> path_available?("Ausgaben")  # Already exists
      false
  """
  def path_available?(path) when is_binary(path) do
    case AccountPath.validate(path) do
      :ok ->
        get_account_by_path(path) == nil

      {:error, _reason} ->
        false
    end
  end

  @doc """
  Suggests available account paths based on a base path.

  If the base path is taken, returns variations with suffixes.

  ## Examples

      iex> suggest_available_path("Ausgaben : Büro")
      "Ausgaben : Büro 2"  # if original is taken
  """
  def suggest_available_path(base_path) when is_binary(base_path) do
    if path_available?(base_path) do
      base_path
    else
      find_available_variation(base_path, 2)
    end
  end

  defp find_available_variation(base_path, suffix) do
    candidate = "#{base_path} #{suffix}"

    if path_available?(candidate) do
      candidate
    else
      find_available_variation(base_path, suffix + 1)
    end
  end

  @doc """
  Validates that all accounts in a list of paths exist and are active.

  This is useful for transaction validation.

  ## Examples

      iex> validate_accounts_exist_and_active(["Ausgaben : Büro", "Kasse"])
      {:ok, [%Account{}, %Account{}]}

      iex> validate_accounts_exist_and_active(["Nonexistent"])
      {:error, {:accounts_not_found, ["Nonexistent"]}}
  """
  def validate_accounts_exist_and_active(paths) when is_list(paths) do
    normalized_paths = Enum.map(paths, &AccountPath.normalize/1)

    query =
      from(a in Account,
        where: a.path in ^normalized_paths and a.active == true,
        select: a
      )

    found_accounts = Repo.all(query)
    found_paths = Enum.map(found_accounts, & &1.path)
    missing_paths = normalized_paths -- found_paths

    if missing_paths == [] do
      {:ok, found_accounts}
    else
      {:error, {:accounts_not_found, missing_paths}}
    end
  end

  # Statistics and Reporting
  # These provide aggregate information about accounts

  @doc """
  Returns statistics about the account structure.

  ## Examples

      iex> account_statistics()
      %{
        total_accounts: 150,
        active_accounts: 142,
        inactive_accounts: 8,
        root_accounts: 5,
        max_depth: 4,
        average_depth: 2.3
      }
  """
  def account_statistics do
    stats_query =
      from(a in Account,
        select: %{
          total: count(a.id),
          active: count(a.id) |> filter(a.active == true),
          inactive: count(a.id) |> filter(a.active == false),
          root_accounts: count(a.id) |> filter(is_nil(a.parent_path)),
          max_depth: max(a.depth),
          avg_depth: avg(a.depth)
        }
      )

    case Repo.one(stats_query) do
      nil ->
        %{
          total_accounts: 0,
          active_accounts: 0,
          inactive_accounts: 0,
          root_accounts: 0,
          max_depth: 0,
          average_depth: 0.0
        }

      stats ->
        %{
          total_accounts: stats.total || 0,
          active_accounts: stats.active || 0,
          inactive_accounts: stats.inactive || 0,
          root_accounts: stats.root_accounts || 0,
          max_depth: stats.max_depth || 0,
          average_depth: stats.avg_depth || 0.0
        }
    end
  end

  # Private Helper Functions
  # These support the main functionality with validation and utilities

  defp validate_parent_exists_and_active(nil), do: {:ok, nil}
  defp validate_parent_exists_and_active(""), do: {:ok, nil}

  defp validate_parent_exists_and_active(path) do
    case AccountPath.parent(path) do
      nil ->
        # Root account, no parent needed
        {:ok, nil}

      parent_path ->
        case get_account_by_path(parent_path) do
          nil ->
            {:error, {:parent_not_found, parent_path}}

          %Account{active: false} ->
            {:error, {:parent_inactive, parent_path}}

          %Account{active: true} ->
            {:ok, parent_path}
        end
    end
  end

  defp validate_all_parents_active(path) do
    ancestor_paths = AccountPath.ancestors_without_self(path)

    case ancestor_paths do
      [] ->
        # Root account, no parents to check
        {:ok, []}

      paths ->
        inactive_parents =
          from(a in Account,
            where: a.path in ^paths and a.active == false,
            select: a.path
          )
          |> Repo.all()

        if inactive_parents == [] do
          {:ok, paths}
        else
          {:error, {:inactive_parents, inactive_parents}}
        end
    end
  end

  defp has_children?(%Account{path: path}) do
    query =
      from(a in Account,
        where: a.parent_path == ^path,
        select: count(a.id)
      )

    Repo.one(query) > 0
  end

  defp has_transactions?(%Account{id: _account_id}) do
    # This will be implemented when we have the Position schema
    # For now, return false
    # query = from(p in TidelandLedger.Transactions.Position,
    #   where: p.account_id == ^account_id,
    #   select: count(p.id)
    # )
    # Repo.one(query) > 0
    false
  end

  # Query Filter Functions
  # These build composable query conditions

  defp filter_by_active(query, nil), do: query
  defp filter_by_active(query, active), do: where(query, [a], a.active == ^active)

  defp filter_by_parent(query, nil), do: query
  defp filter_by_parent(query, parent_path), do: where(query, [a], a.parent_path == ^parent_path)

  defp filter_by_search(query, nil), do: query
  defp filter_by_search(query, ""), do: query

  defp filter_by_search(query, search_term) do
    search_pattern = "%#{search_term}%"

    where(
      query,
      [a],
      ilike(a.path, ^search_pattern) or
        ilike(a.name, ^search_pattern) or
        ilike(a.description, ^search_pattern)
    )
  end

  defp filter_by_max_depth(query, nil), do: query
  defp filter_by_max_depth(query, max_depth), do: where(query, [a], a.depth <= ^max_depth)

  defp order_accounts(query, :path), do: order_by(query, [a], asc: a.path)
  defp order_accounts(query, :name), do: order_by(query, [a], asc: a.name)
  defp order_accounts(query, :depth), do: order_by(query, [a], asc: a.depth, asc: a.path)
  defp order_accounts(query, :created_at), do: order_by(query, [a], desc: a.inserted_at)
  defp order_accounts(query, _), do: order_accounts(query, :path)

  defp limit_offset(query, nil, nil), do: query
  defp limit_offset(query, limit, nil), do: limit(query, ^limit)
  defp limit_offset(query, nil, offset), do: offset(query, ^offset)

  defp limit_offset(query, limit, offset) do
    query
    |> limit(^limit)
    |> offset(^offset)
  end
end
